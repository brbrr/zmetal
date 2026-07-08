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
            .phase_inc = freq / sample_rate,
        };
    }

    pub fn setFreq(self: *SineOsc, freq: f32) void {
        self.freq = freq;
        self.phase_inc = freq / self.sample_rate;
    }

    pub fn nextSample(self: *SineOsc) f32 {
        const out = self.amplitude * std.math.sin(self.phase * std.math.tau);

        self.phase += self.phase_inc;
        if (self.phase >= 1) {
            self.phase -= 1;
        }

        return out;
    }
};

pub const WavetableOsc = struct {
    const TableSize = 2048; // power of two preferred

    sample_rate: f32,
    freq: f32,
    phase: f32, // 0..TableSize
    amplitude: f32,
    phase_inc: f32,
    table: [TableSize]f32,

    pub fn init(freq: f32, sample_rate: f32, amplitude: f32) WavetableOsc {
        @setEvalBranchQuota(10000);
        var osc = WavetableOsc{
            .sample_rate = sample_rate,
            .freq = freq,
            .phase = 0.0,
            .amplitude = amplitude,
            .phase_inc = 0.0,
            .table = undefined,
        };

        // Generate one sine period
        for (osc.table, 0..) |sample, i| {
            _ = sample;
            const phase = @as(f32, @floatFromInt(i)) / TableSize;
            osc.table[i] = std.math.sin(phase * std.math.tau);
        }

        osc.setFreq(freq);
        return osc;
    }

    pub fn setFreq(self: *WavetableOsc, freq: f32) void {
        self.freq = freq;
        self.phase_inc = freq * TableSize / self.sample_rate;
    }

    pub fn nextSample(self: *WavetableOsc) f32 {
        const index = @as(usize, @intFromFloat(self.phase));
        const frac = self.phase - @as(f32, @floatFromInt(index));

        // Linear interpolation
        const a = self.table[index];
        const b = self.table[(index + 1) & (TableSize - 1)];

        const sample = a + (b - a) * frac;

        self.phase += self.phase_inc;
        if (self.phase >= TableSize) {
            self.phase -= TableSize;
        }

        return sample * self.amplitude;
    }
};
