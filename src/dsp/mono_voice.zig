//! Monophonic, last-key-priority voice control for the matrix keyboard.
//!
//! Maps note-key indices from the keyboard to oscillator frequencies and tracks
//! which keys are held so the synth follows last-key priority: the most recently
//! pressed key that is still held determines the pitch, and releasing it falls
//! back to whichever held key was pressed before it. When no note key is held
//! the voice is inactive (the caller should gate the oscillator silent).
//!
//! This module is oscillator-agnostic and free of hardware dependencies so it
//! can be unit-tested on the host. Note layout follows the WoopyOne reference:
//! the low `NOTE_KEYS` key indices are a chromatic run, `note = BASE_MIDI + key`.

const std = @import("std");

/// Number of keys treated as chromatic notes (indices 0..NOTE_KEYS-1).
/// Higher key indices are non-note keys and are ignored.
pub const NOTE_KEYS: u8 = 24;

/// MIDI note number of key 0. 60 = C4, so keys 0..23 span C4..B5.
pub const BASE_MIDI: u8 = 60;

/// Lowest and highest octave shift, in whole octaves, that `shiftOctave` allows.
pub const OCTAVE_MIN: i8 = -4;
pub const OCTAVE_MAX: i8 = 4;

/// Equal-tempered frequency (Hz) for a MIDI note number, from A4(69)=440Hz.
pub fn midiToFreq(midi: i32) f32 {
    const m: f32 = @floatFromInt(midi);
    return 440.0 * std.math.pow(f32, 2.0, (m - 69.0) / 12.0);
}

/// Chromatic frequency (Hz) for a note-key index at octave 0, from A4=440Hz.
/// Only valid for `key < NOTE_KEYS`.
pub fn keyToFreq(key: u8) f32 {
    return midiToFreq(@as(i32, BASE_MIDI) + key);
}

pub const MonoVoice = struct {
    /// Stack of currently-held note-key indices, oldest at [0], newest on top.
    held: [NOTE_KEYS]u8 = undefined,
    count: usize = 0,
    /// Whole-octave transpose applied to every note, clamped to [OCTAVE_MIN, MAX].
    octave: i8 = 0,

    pub fn init() MonoVoice {
        return .{ .count = 0, .octave = 0 };
    }

    /// Transpose by `delta` octaves, clamped to the allowed range.
    pub fn shiftOctave(self: *MonoVoice, delta: i8) void {
        const next = std.math.clamp(
            @as(i32, self.octave) + delta,
            OCTAVE_MIN,
            OCTAVE_MAX,
        );
        self.octave = @intCast(next);
    }

    /// Register a key press. Non-note keys and already-held keys are ignored.
    pub fn press(self: *MonoVoice, key: u8) void {
        if (key >= NOTE_KEYS) return;
        for (self.held[0..self.count]) |k| {
            if (k == key) return; // already held, keep its position
        }
        self.held[self.count] = key;
        self.count += 1;
    }

    /// Register a key release. Removes the key from the held stack (if present),
    /// preserving the order of the remaining held keys.
    pub fn release(self: *MonoVoice, key: u8) void {
        if (key >= NOTE_KEYS) return;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.held[i] == key) {
                var j = i;
                while (j + 1 < self.count) : (j += 1) {
                    self.held[j] = self.held[j + 1];
                }
                self.count -= 1;
                return;
            }
        }
    }

    /// True when at least one note key is held (oscillator should sound).
    pub fn active(self: *const MonoVoice) bool {
        return self.count > 0;
    }

    /// Frequency (Hz) of the sounding note: the most recently pressed key that
    /// is still held, transposed by the current octave. Only call when
    /// `active()` is true.
    pub fn freq(self: *const MonoVoice) f32 {
        std.debug.assert(self.count > 0);
        const midi = @as(i32, BASE_MIDI) + self.held[self.count - 1] + @as(i32, self.octave) * 12;
        return midiToFreq(midi);
    }
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn approx(a: f32, b: f32) bool {
    return std.math.approxEqAbs(f32, a, b, 0.05);
}

test "starts inactive" {
    var v = MonoVoice.init();
    try expect(!v.active());
}

test "keyToFreq: C4, C5, octave doubling" {
    try expect(approx(keyToFreq(0), 261.6256)); // C4
    try expect(approx(keyToFreq(12), 523.2511)); // C5
    // one octave (12 semitones) up is exactly double the frequency
    try expect(approx(keyToFreq(12), keyToFreq(0) * 2.0));
    try expect(approx(keyToFreq(23), keyToFreq(11) * 2.0));
}

test "single note: press activates, release deactivates" {
    var v = MonoVoice.init();
    v.press(0);
    try expect(v.active());
    try expect(approx(v.freq(), 261.6256));
    v.release(0);
    try expect(!v.active());
}

test "last-key priority: newest held key sounds, release falls back" {
    var v = MonoVoice.init();
    v.press(0);
    v.press(4);
    v.press(7);
    try expect(approx(v.freq(), keyToFreq(7))); // newest wins
    v.release(7);
    try expect(approx(v.freq(), keyToFreq(4))); // fall back to previous
    v.release(4);
    try expect(approx(v.freq(), keyToFreq(0)));
    v.release(0);
    try expect(!v.active());
}

test "releasing a middle key preserves the rest and top" {
    var v = MonoVoice.init();
    v.press(0);
    v.press(4);
    v.press(7);
    v.release(4); // release a non-top held key
    try expect(v.active());
    try expect(approx(v.freq(), keyToFreq(7))); // top unchanged
    v.release(7);
    try expect(approx(v.freq(), keyToFreq(0)));
}

test "duplicate press is ignored (no double-count)" {
    var v = MonoVoice.init();
    v.press(5);
    v.press(5);
    try expectEqual(@as(usize, 1), v.count);
    v.release(5);
    try expect(!v.active());
}

test "non-note keys are ignored" {
    var v = MonoVoice.init();
    v.press(NOTE_KEYS); // first non-note key
    v.press(40);
    try expect(!v.active());
    v.release(40); // releasing something never held is a no-op
    try expect(!v.active());
}

test "release of an unheld note key is a no-op" {
    var v = MonoVoice.init();
    v.press(3);
    v.release(9); // not held
    try expect(v.active());
    try expect(approx(v.freq(), keyToFreq(3)));
}

test "octave shift transposes by ±1 octave = ×2 / ÷2" {
    var v = MonoVoice.init();
    v.press(0);
    const base = v.freq();
    v.shiftOctave(1);
    try expect(approx(v.freq(), base * 2.0));
    v.shiftOctave(-2); // now at -1
    try expect(approx(v.freq(), base / 2.0));
    v.shiftOctave(1); // back to 0
    try expect(approx(v.freq(), base));
}

test "octave shift is clamped" {
    var v = MonoVoice.init();
    v.shiftOctave(100);
    try expectEqual(OCTAVE_MAX, v.octave);
    v.shiftOctave(-100);
    try expectEqual(OCTAVE_MIN, v.octave);
}
