const std = @import("std");

pub const SquareOsc = struct {
    freq: f32, // Oscillator frequency (Hz)
    sample_rate: f32, // Sample rate (Hz)
    phase: f32, // 0..1 fractional phase
    amplitude: f32, // Output amplitude (e.g. 1.0 for full scale)
    phsdr_inc: f32, // Phase increment per sample

    pub fn init(freq: f32, sample_rate: f32, amplitude: f32) SquareOsc {
        return SquareOsc{
            .freq = freq,
            .sample_rate = sample_rate,
            .phase = 0.0,
            .amplitude = amplitude,
            .phsdr_inc = freq / sample_rate,
        };
    }

    pub fn nextSample(self: *SquareOsc) f32 {
        self.phase += self.phsdr_inc;
        if (self.phase >= 1.0) {
            self.phase -= 1.0;
        }
        if (self.phase < 0.5) {
            return self.amplitude;
        } else {
            return -self.amplitude;
        }
    }
};

pub const SineOsc = struct {
    sample_rate: f32,
    freq: f32,
    phase: f32,
    amplitude: f32,
    phase_inc: f32,

    pub fn init(freq: f32, sample_rate: f32, amplitude: f32) SineOsc {
        return .{
            .sample_rate = sample_rate,
            .freq = freq,
            .phase = 0.0,
            .amplitude = amplitude,
            .phase_inc = 2.0 * std.math.pi * freq / sample_rate,
        };
    }

    pub fn setFreq(self: *SineOsc, freq: f32) void {
        self.freq = freq;
        self.phase_inc = 2.0 * std.math.pi * freq / self.sample_rate;
    }

    pub fn nextSample(self: *SineOsc) f32 {
        const out = self.amplitude * std.math.sin(self.phase);

        self.phase += self.phase_inc;
        if (self.phase >= 2.0 * std.math.pi) {
            self.phase -= 2.0 * std.math.pi;
        }

        return out;
    }
};
