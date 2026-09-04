//! Linear-interpolating stereo resampler for USB-playback drift correction.
//!
//! Why this exists: macOS will not drive a UAC2 feedback endpoint on full-speed
//! (the FS feedback value format, 3-byte 10.14, is a known cross-OS
//! incompatibility — see TinyUSB #3393, documented on this exact STM32H750/dwc2
//! combo). So the host self-paces at its nominal rate and the host clock drifts
//! against the SAI clock (~200 ppm → a one-block gap every ~5 s without
//! correction). This resampler reconciles the two clocks on the device side by
//! consuming source frames at a fractional `ratio` (~1.0) driven by the OUT
//! FIFO fill level, producing exactly one fixed output block.
//!
//! PRODUCTION NOTE: on the high-speed OTG port, UAC2 feedback (4-byte 16.16)
//! works with all hosts — switching to HS lets the host correct drift and this
//! resampler can be removed entirely.
//!
//! Leaf module (std only) so the interpolation math is host-testable.
const std = @import("std");

pub const Resampler = struct {
    /// Source frames consumed per output frame. Held near 1.0 by the caller's
    /// FIFO-level control loop. Clamped so the phase never advances >= 2.0 per
    /// output (the inner advance loop then runs at most once).
    ratio: f32 = 1.0,
    /// Last source frame consumed (the left interpolation point for the next
    /// output) and the fractional position toward the next source frame.
    prev_l: f32 = 0,
    prev_r: f32 = 0,
    phase: f32 = 0,

    /// Produce `out` (interleaved stereo) by resampling `src` (interleaved
    /// stereo) at `ratio`. Returns the number of source frames consumed (to be
    /// removed from the caller's carry buffer). If `src` is exhausted, the last
    /// frame is held (graceful underrun).
    pub fn process(self: *Resampler, src: []const f32, out: []f32) usize {
        std.debug.assert(self.ratio > 0);
        const frames_out = out.len / 2;
        var si: usize = 0; // source frames stepped past so far
        var cur_l = self.prev_l;
        var cur_r = self.prev_r;

        var o: usize = 0;
        while (o < frames_out) : (o += 1) {
            const nxt_l = if (si * 2 + 1 < src.len) src[si * 2] else cur_l;
            const nxt_r = if (si * 2 + 1 < src.len) src[si * 2 + 1] else cur_r;

            // phase is kept in [0,1) below, so this always interpolates.
            out[o * 2] = cur_l + (nxt_l - cur_l) * self.phase;
            out[o * 2 + 1] = cur_r + (nxt_r - cur_r) * self.phase;

            // Advance by `ratio` source frames, consuming as many WHOLE frames
            // as fit — a `while`, not an `if`: when ratio > 1 this steps more
            // than one frame per output, which is exactly how the FIFO is
            // drained faster to correct host-faster-than-SAI drift. Keeps
            // `self.phase` in [0,1) so it never runs away across calls.
            self.phase += self.ratio;
            while (self.phase >= 1.0) {
                self.phase -= 1.0;
                cur_l = if (si * 2 + 1 < src.len) src[si * 2] else cur_l;
                cur_r = if (si * 2 + 1 < src.len) src[si * 2 + 1] else cur_r;
                si += 1;
            }
        }

        self.prev_l = cur_l;
        self.prev_r = cur_r;
        return si;
    }
};

test "unity ratio passes a DC signal through unchanged" {
    var r: Resampler = .{ .ratio = 1.0, .prev_l = 0.5, .prev_r = -0.5 };
    var src: [16]f32 = undefined;
    for (0..8) |i| {
        src[i * 2] = 0.5;
        src[i * 2 + 1] = -0.5;
    }
    var out: [8]f32 = undefined; // 4 frames
    _ = r.process(&src, &out);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[i * 2], 1e-6);
        try std.testing.expectApproxEqAbs(@as(f32, -0.5), out[i * 2 + 1], 1e-6);
    }
}

test "unity ratio consumes ~one source frame per output frame" {
    var r: Resampler = .{ .ratio = 1.0 };
    var src: [64]f32 = @splat(0);
    var out: [16]f32 = undefined; // 8 frames
    const consumed = r.process(&src, &out);
    try std.testing.expectEqual(@as(usize, 8), consumed);
}

test "ratio < 1 (host slower) consumes fewer source frames" {
    var r: Resampler = .{ .ratio = 0.5 };
    var src: [64]f32 = @splat(0);
    var out: [16]f32 = undefined; // 8 frames
    const consumed = r.process(&src, &out);
    // ~4 source frames for 8 outputs at ratio 0.5.
    try std.testing.expect(consumed >= 3 and consumed <= 5);
}

test "ratio > 1 (host faster) consumes more than it outputs, phase bounded" {
    var r: Resampler = .{ .ratio = 1.02 };
    var src: [512]f32 = @splat(0); // 256 source frames available
    var out: [256]f32 = undefined; // 128 output frames
    const consumed = r.process(&src, &out);
    // 128 * 1.02 = 130.56 -> ~130 consumed. The buggy single-`if` capped at 128.
    try std.testing.expect(consumed >= 129 and consumed <= 132);
    try std.testing.expect(r.phase >= 0.0 and r.phase < 1.0);
}

test "sustained ratio > 1 does not let phase run away across calls" {
    var r: Resampler = .{ .ratio = 1.01 };
    var src: [512]f32 = @splat(0);
    var out: [256]f32 = undefined; // 128 frames
    // Many calls: with the old `if`, phase accumulated (ratio-1) per output and
    // climbed unbounded (extrapolation). It must stay in [0,1) every call.
    for (0..20) |_| {
        _ = r.process(&src, &out);
        try std.testing.expect(r.phase >= 0.0 and r.phase < 1.0);
    }
}

test "ratio > 1 on a ramp never extrapolates past the bracketing samples" {
    var r: Resampler = .{ .ratio = 1.015, .prev_l = 0, .prev_r = 0 };
    var src: [512]f32 = undefined; // 256 frames, ascending ramp 0..255
    for (0..256) |i| {
        src[i * 2] = @floatFromInt(i);
        src[i * 2 + 1] = @floatFromInt(i);
    }
    var out: [256]f32 = undefined;
    _ = r.process(&src, &out);
    // Monotone ramp in, monotone non-decreasing out, bounded by the input range
    // (extrapolation from the old bug would overshoot past 255).
    for (out) |s| try std.testing.expect(s >= 0 and s <= 255);
}

test "underrun holds the last sample instead of glitching to zero" {
    var r: Resampler = .{ .ratio = 1.0, .prev_l = 0.25, .prev_r = 0.25 };
    var src = [_]f32{}; // no source available
    var out: [8]f32 = undefined; // 4 frames
    _ = r.process(&src, &out);
    for (out) |s| try std.testing.expectApproxEqAbs(@as(f32, 0.25), s, 1e-6);
}
