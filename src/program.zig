//! Programs — the DSP brain behind the audio interface. A Program owns all
//! routing and DSP and exposes a single method: `process(io)`. The engine
//! knows nothing beyond that seam.
//!
//! Today: `SynthProgram` (the default). Future: a WoopyOne-style Program whose
//! internal graph (tracks = voices + effect chains, mixed to a master) hides
//! behind the same `process(io)` — dropped in with no engine changes.
const std = @import("std");
const synth = @import("synth.zig");
const AudioIO = @import("audio_io.zig").AudioIO;

/// Default Program: the synth, monitored to both outputs alongside USB
/// playback. `line_in` is available but unused by default — a future effect
/// Program would read it.
///
/// Gain staging: the host sends playback at ~0 dBFS, but the codec/monitoring
/// chain clips well below full scale, so the USB contribution to the *analog*
/// line-out is trimmed by `usb_line_gain`. The *host capture* (`usb_out`) gets
/// the untrimmed full-scale mix, so the DAW records at proper level.
pub const SynthProgram = struct {
    usb_line_gain: f32 = 0.15,

    pub fn process(self: *SynthProgram, io: AudioIO) void {
        synth.render(io.line_out); // io.line_out := synth voices

        // Host capture: full-scale mix (synth + host playback).
        for (io.usb_out, io.line_out, io.usb_in) |*host, voices, play| host.* = voices + play;

        // Analog line-out: synth at its own level + trimmed host playback.
        for (io.line_out, io.usb_in) |*out, play| out.* += play * self.usb_line_gain;
    }

    /// Ride the line-out USB trim by `steps` detents (ENC0), clamped to [0, 1].
    pub fn adjustUsbGain(self: *SynthProgram, steps: i8) void {
        const delta = @as(f32, @floatFromInt(steps)) * 0.02;
        self.usb_line_gain = std.math.clamp(self.usb_line_gain + delta, 0.0, 1.0);
    }
};

test "SynthProgram: host capture full-scale, line-out trimmed (synth gated off)" {
    var line_in: [4]f32 = @splat(0);
    var usb_in = [_]f32{ 0.1, 0.2, 0.3, 0.4 };
    var line_out: [4]f32 = @splat(0);
    var usb_out: [4]f32 = @splat(0);

    var p: SynthProgram = .{ .usb_line_gain = 0.15 };
    p.process(.{
        .line_in = &line_in,
        .usb_in = &usb_in,
        .line_out = &line_out,
        .usb_out = &usb_out,
    });

    // Synth gated off at init: host capture = untrimmed usb_in; line-out = usb_in * trim.
    try std.testing.expectEqualSlices(f32, &usb_in, &usb_out);
    for (line_out, usb_in) |lo, u| try std.testing.expectApproxEqAbs(u * 0.15, lo, 1e-6);
}
