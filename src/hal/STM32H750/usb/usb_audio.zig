//! USB Audio (UAC2) I/O primitives: move PCM between the TinyUSB isochronous
//! EP FIFOs and interleaved f32 audio buffers. No DSP/synth knowledge — the
//! app-level audio engine composes these with the DSP pipeline.
//!
//! Called from the SAI DMA ISR; the USB stack is the opposite end of each
//! single-producer/single-consumer tu_fifo, so no locking is needed.
const std = @import("std");
const pcm = @import("pcm.zig");
const tinyusb = @import("tinyusb.zig");
const descriptors = @import("descriptors.zig");
const audio = @import("../audio.zig");
const Resampler = @import("resampler.zig").Resampler;

// Compile-time envelope: buffers are sized for the largest supported format so
// any runtime AudioConfig fits — stereo, blocksize <= 48, up to 4-byte subslot.
// (A larger blocksize would need MAX_SAMPLES/CARRY_FRAMES bumped.)
const MAX_CHANNELS = 2;
const MAX_SUBSLOT = 4;
pub const MAX_SAMPLES = 48 * MAX_CHANNELS; // 96 interleaved samples per block
const CARRY_FRAMES = 64; // source frames buffered (>= blocksize * max ratio + margin)
const MAX_READ_BYTES = CARRY_FRAMES * MAX_SUBSLOT * MAX_CHANNELS; // FIFO read staging
const MAX_WRITE_BYTES = MAX_SAMPLES * MAX_SUBSLOT; // capture write staging

// Runtime format, set by configure() from the AudioConfig at boot.
var fmt_subslot: u8 = 3; // USB wire bytes per sample
var fmt_frame_bytes: u16 = 6; // subslot * channels

/// Configure the USB audio format (before enumeration): patch the descriptor,
/// set the clock rate the device reports, and set the conversion stride.
/// Channels fixed at 2; resolution 24 or 32 (the SAI conversion path).
pub fn configure(cfg: audio.AudioConfig) void {
    std.debug.assert(cfg.channels == MAX_CHANNELS);
    std.debug.assert(cfg.bit_depth == .@"24bit" or cfg.bit_depth == .@"32bit"); // SAI conversion path
    std.debug.assert(cfg.samplesPerBlock() <= MAX_SAMPLES);
    std.debug.assert(cfg.epSize() <= 1023); // full-speed iso ceiling + compiled envelope
    fmt_subslot = cfg.subslot();
    fmt_frame_bytes = cfg.frameBytes();
    descriptors.configure(cfg.subslot(), cfg.bits(), cfg.epSize());
    tinyusb.zt_audio_set_sample_rate(cfg.rateHz());
}

// --- Playback drift correction (see resampler.zig for why) ---
// macOS won't drive UAC2 feedback on full-speed, so the host self-paces and its
// clock drifts against the SAI clock. We resample the OUT stream on the device
// side, steering the resample ratio from the OUT FIFO fill level to hold it
// near a target (a software PLL). On the HS port UAC2 feedback works and this
// whole mechanism can be removed.
var resampler: Resampler = .{};
var carry: [CARRY_FRAMES * MAX_CHANNELS]f32 = @splat(0);
var n_carry: usize = 0;
// Prime the buffer to the target level before consuming, so playback starts at
// the steady-state fill and never underruns during the initial ramp.
var primed: bool = false;

// Control-loop tuning (adjust on hardware). Target: hold the OUT FIFO at ~2/3
// of its ~196-frame software buffer. Proportional gain + per-block slew limit
// keep ratio changes gentle so there is no audible pitch wobble.
const FIFO_TARGET_FRAMES: f32 = 128; // 128/48000 ≈ 2.7ms cushion; high enough that USB jitter never empties the buffer
const CTRL_GAIN: f32 = 3.0e-5; // ratio delta per frame of fill error
const RATIO_MIN: f32 = 0.985;
const RATIO_MAX: f32 = 1.015;
const RATIO_SLEW: f32 = 2.0e-4; // max ratio change per block

/// Fill `out` (interleaved f32) from the host playback (OUT) stream, resampled
/// to correct host/SAI clock drift. Returns false and writes silence when the
/// host isn't streaming.
pub fn readPlayback(out: []f32) bool {
    std.debug.assert(out.len <= MAX_SAMPLES);
    const frames_out = out.len / 2;

    if (!tinyusb.zt_audio_out_active()) {
        @memset(out, 0);
        n_carry = 0; // reset the drift state so a fresh stream starts clean
        resampler = .{};
        primed = false;
        return false;
    }

    // Software PLL: steer the resample ratio from the total buffered frames
    // (OUT FIFO + carry) toward the target fill level, slew-limited.
    const buffered_frames = tinyusb.zt_audio_out_available() / fmt_frame_bytes + n_carry;

    // Prefill: hold silence (without consuming) until the FIFO reaches the
    // target, so playback begins at steady-state fill and skips the startup
    // underrun ramp.
    if (!primed) {
        if (buffered_frames < FIFO_TARGET_FRAMES) {
            @memset(out, 0);
            return true;
        }
        primed = true;
    }
    const buffered: f32 = @floatFromInt(buffered_frames);
    const target_ratio = std.math.clamp(1.0 + CTRL_GAIN * (buffered - FIFO_TARGET_FRAMES), RATIO_MIN, RATIO_MAX);
    resampler.ratio += std.math.clamp(target_ratio - resampler.ratio, -RATIO_SLEW, RATIO_SLEW);

    // Top up the carry buffer from the FIFO to cover this block at the current
    // ratio. This variable read is what drains the FIFO at the corrected rate.
    const need = @as(usize, @intFromFloat(@ceil(@as(f32, @floatFromInt(frames_out)) * resampler.ratio))) + 2;
    if (n_carry < need) {
        const want_frames = @min(need - n_carry, CARRY_FRAMES - n_carry);
        var buf: [MAX_READ_BYTES]u8 = undefined;
        const got = tinyusb.zt_audio_read(&buf, @intCast(want_frames * fmt_frame_bytes));
        const got_frames = got / fmt_frame_bytes;
        pcm.pcmToFloat(fmt_subslot, buf[0..got], carry[n_carry * 2 .. (n_carry + got_frames) * 2]);
        n_carry += got_frames;
    }

    // Resample carry -> out, then drop the consumed frames from the carry.
    const consumed = @min(resampler.process(carry[0 .. n_carry * 2], out), n_carry);
    const keep = n_carry - consumed;
    if (keep > 0) std.mem.copyForwards(f32, carry[0 .. keep * 2], carry[consumed * 2 .. n_carry * 2]);
    n_carry = keep;
    return true;
}

/// Send `samples` (interleaved f32) to the host capture (IN) stream. No-op when
/// the host isn't recording.
pub fn writeCapture(samples: []const f32) void {
    std.debug.assert(samples.len <= MAX_SAMPLES);
    if (!tinyusb.zt_audio_in_active()) return;
    var buf: [MAX_WRITE_BYTES]u8 = undefined;
    const nbytes = samples.len * fmt_subslot;
    pcm.floatToPcm(fmt_subslot, samples, buf[0..nbytes]);
    _ = tinyusb.zt_audio_write(&buf, @intCast(nbytes));
}

/// Whether the host currently has each stream open (alt-setting 1).
pub const Status = struct {
    playback_active: bool, // host is streaming to us (OUT / speaker)
    capture_active: bool, // host is recording from us (IN / mic)
};

/// Query which USB audio streams the host has opened.
pub fn status() Status {
    return .{
        .playback_active = tinyusb.zt_audio_out_active(),
        .capture_active = tinyusb.zt_audio_in_active(),
    };
}
