//! Audio engine: the monophonic synth voice driven by the keyboard (and, later,
//! the encoders). Composes the oscillator (`dsp/osc`) with the note-priority
//! logic (`dsp/mono_voice`) and owns the audio-callback render loop.
//!
//! State lives in a single module-level `engine` instance rather than a struct
//! the caller holds, because the SAI driver needs a plain function pointer for
//! its callback (`audioCallback`) — that free function and the state it renders
//! from must live together. Callers drive the engine through the `pub fn`s here.
//!
//! Threading: `audioCallback` runs in the SAI DMA ISR; the `handleKey`/`adjust*`
//! functions run in the main loop. `gate` (bool) and `amplitude` (f32) are single
//! aligned words, so those reads/writes are atomic on Cortex-M7. `setFreq` writes
//! two f32 fields, so a pitch change can glitch at most one rendered sample.

const std = @import("std");
const osc = @import("dsp/osc.zig");
const mono_voice = @import("dsp/mono_voice.zig");

const SAMPLE_RATE = 48000;

/// Volume step per encoder detent, and the clamp range for `amplitude`.
const VOLUME_STEP: f32 = 0.02;
const VOLUME_MAX: f32 = 1.0;

const Engine = struct {
    sine: osc.WavetableOsc,
    voice: mono_voice.MonoVoice,
    /// When false the oscillator is muted (no note held).
    gate: bool,
};

var engine: Engine = .{
    .sine = osc.WavetableOsc.init(440, SAMPLE_RATE, 0.02),
    .voice = mono_voice.MonoVoice.init(),
    .gate = false,
};

/// SAI audio callback. Renders the (mono) oscillator to both channels, or
/// silence when gated off. Matches `hal.sai.AudioCallback`'s signature.
pub fn audioCallback(input: []const f32, output: []f32, size: u16) void {
    _ = input;
    render(output[0..size]);
}

/// Render the mono voice into `output` (interleaved stereo), or silence when
/// gated off. A generator — ignores any input. Shared by the legacy SAI
/// callback and the audio-interface Program.
pub fn render(output: []f32) void {
    var i: usize = 0;
    while (i < output.len) : (i += 2) {
        // Gate: silence (and freeze phase) when no note key is held.
        const samp = if (engine.gate) engine.sine.nextSample() else 0.0;
        output[i] = samp;
        output[i + 1] = samp;
    }
}

/// Feed a note key event (logical key index) to the voice and update pitch/gate
/// following last-key priority.
pub fn handleKey(logical_key: u8, pressed: bool) void {
    if (pressed) {
        engine.voice.press(logical_key);
    } else {
        engine.voice.release(logical_key);
    }
    applyVoice();
}

/// Adjust master volume by `steps` detents (positive = louder), clamped.
pub fn adjustVolume(steps: i8) void {
    const delta = @as(f32, @floatFromInt(steps)) * VOLUME_STEP;
    engine.sine.amplitude = std.math.clamp(engine.sine.amplitude + delta, 0.0, VOLUME_MAX);
}

/// Transpose the keyboard by `steps` octaves (positive = up), clamped. Re-applies
/// the pitch immediately if a note is currently held.
pub fn shiftOctave(steps: i8) void {
    engine.voice.shiftOctave(steps);
    if (engine.voice.active()) {
        engine.sine.setFreq(engine.voice.freq());
    }
}

// === MIDI note input =============================================
//
// Shares the single mono oscillator with the matrix keyboard — whichever played
// most recently wins (a proper voice mixer is future work). MIDI notes are
// tracked in their own last-note-priority stack, pitched via midiToFreq.

const MAX_MIDI_NOTES = 8;
var midi_notes: [MAX_MIDI_NOTES]u8 = undefined;
var midi_count: usize = 0;

/// MIDI Note On. Velocity 0 is treated as Note Off (the running-status idiom).
pub fn midiNoteOn(note: u8, velocity: u8) void {
    if (velocity == 0) return midiNoteOff(note);
    for (midi_notes[0..midi_count]) |n| {
        if (n == note) return retuneMidi(); // already held
    }
    if (midi_count < MAX_MIDI_NOTES) {
        midi_notes[midi_count] = note;
        midi_count += 1;
    }
    retuneMidi();
}

/// MIDI Note Off. Falls back to the most-recently-pressed still-held note, or
/// gates the oscillator off when none remain.
pub fn midiNoteOff(note: u8) void {
    var i: usize = 0;
    while (i < midi_count) : (i += 1) {
        if (midi_notes[i] == note) {
            var j = i;
            while (j + 1 < midi_count) : (j += 1) midi_notes[j] = midi_notes[j + 1];
            midi_count -= 1;
            break;
        }
    }
    retuneMidi();
}

fn retuneMidi() void {
    if (midi_count > 0) {
        engine.sine.setFreq(mono_voice.midiToFreq(@as(i32, midi_notes[midi_count - 1])));
        engine.gate = true;
    } else {
        engine.gate = false;
    }
}

/// Push the current voice state (pitch + gate) into the oscillator.
fn applyVoice() void {
    if (engine.voice.active()) {
        engine.sine.setFreq(engine.voice.freq());
        engine.gate = true;
    } else {
        engine.gate = false;
    }
}
