//! Audio CPU-load meter: the fraction of each audio block spent in the SAI
//! callback (`busy_cycles / cycles_per_block`), with a smoothed average and a
//! rolling peak. Mirrors libdaisy's CpuLoadMeter.
//!
//! Pure math — the cycle-counter reading is injected via `beginBlock`/
//! `endBlock` (the caller passes `dwt.cycles()`), so this stays free of any
//! hardware/microzig dependency and is host-testable. Owned by `daisy`, driven
//! from the SAI ISR, and read from the UI (main loop).
//!
//! Concurrency: `beginBlock`/`endBlock` run in the SAI ISR; `read` runs in the
//! main loop. `avg_load` is a single word (atomic read); the peak read-then-
//! reset in `read` can rarely drop one ISR update if the ISR fires mid-read —
//! acceptable for an approximate worst-case indicator.
const std = @import("std");

pub const Load = struct {
    avg: f32, // smoothed average, 0..1
    peak: f32, // worst block since the last read, 0..1
};

pub const CpuLoadMeter = struct {
    cyc_per_block: f32 = 1.0, // CPU cycles in one audio block (>0 to avoid /0)
    smoothing: f32 = 1.0, // 1-pole coefficient for the average
    avg_load: f32 = 0.0, // smoothed load, 0..1
    peak_cyc: u32 = 0, // max busy cycles since last read()
    block_start: u32 = 0, // cycle count at the current block's begin

    /// `cycles_per_block = coreclock * blocksize / sample_rate`;
    /// `block_rate_hz = sample_rate / blocksize` (for the ~1 Hz avg smoothing).
    pub fn init(cycles_per_block: u32, block_rate_hz: f32) CpuLoadMeter {
        // 1-pole low-pass at 1 Hz cutoff:  a = wc / (wc + 1),  wc = 2*pi*fc/fs_block
        const wc = 2.0 * std.math.pi * 1.0 / block_rate_hz;
        return .{
            .cyc_per_block = @floatFromInt(cycles_per_block),
            .smoothing = wc / (wc + 1.0),
        };
    }

    /// Mark the start of an audio block; `now` = current cycle count.
    pub fn beginBlock(self: *CpuLoadMeter, now: u32) void {
        self.block_start = now;
    }

    /// Mark the end of an audio block; `now` = current cycle count.
    pub fn endBlock(self: *CpuLoadMeter, now: u32) void {
        self.record(now -% self.block_start);
    }

    /// Fold one block's busy-cycle count into the average + peak.
    pub fn record(self: *CpuLoadMeter, busy_cycles: u32) void {
        const load = @as(f32, @floatFromInt(busy_cycles)) / self.cyc_per_block;
        self.avg_load = self.smoothing * load + (1.0 - self.smoothing) * self.avg_load;
        if (busy_cycles > self.peak_cyc) self.peak_cyc = busy_cycles;
    }

    /// Read avg + peak (both 0..1) and reset the peak hold.
    pub fn read(self: *CpuLoadMeter) Load {
        const p = self.peak_cyc;
        self.peak_cyc = 0;
        return .{ .avg = self.avg_load, .peak = @as(f32, @floatFromInt(p)) / self.cyc_per_block };
    }
};

test "constant load converges the average toward it" {
    var m = CpuLoadMeter.init(480_000, 1000.0); // 480k cycles/block, 1 kHz blocks
    for (0..20_000) |_| m.record(48_000); // 10% every block
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), m.read().avg, 0.005);
}

test "peak holds the worst block, then resets on read" {
    var m = CpuLoadMeter.init(480_000, 1000.0);
    m.record(48_000); // 10%
    m.record(240_000); // 50% <- the peak
    m.record(96_000); // 20%
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), m.read().peak, 1e-4);
    m.record(48_000); // after reset, a lighter block reads a lower peak
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), m.read().peak, 1e-4);
}

test "begin/end computes busy from injected cycle counts (wrapping)" {
    var m = CpuLoadMeter.init(480_000, 1000.0);
    m.beginBlock(0xFFFF_FF00); // near wrap
    m.endBlock(0x0000_0100); // wrapped: busy = 0x200 = 512 cycles
    try std.testing.expectApproxEqAbs(@as(f32, 512.0 / 480_000.0), m.read().peak, 1e-6);
}

test "load fraction scales with cycles_per_block" {
    var m = CpuLoadMeter.init(240_000, 500.0);
    m.record(120_000); // 50%
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), m.read().peak, 1e-4);
}
