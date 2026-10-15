//! Small DSP helpers (std-only).
const std = @import("std");

/// Equal-tempered frequency (Hz) for a MIDI note number, from A4(69)=440Hz.
pub fn midiToFreq(midi: i32) f32 {
    const m: f32 = @floatFromInt(midi);
    return 440.0 * std.math.pow(f32, 2.0, (m - 69.0) / 12.0);
}

test "A4 is 440 Hz, A5 is 880 Hz" {
    try std.testing.expectApproxEqAbs(@as(f32, 440.0), midiToFreq(69), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 880.0), midiToFreq(81), 0.01);
}
