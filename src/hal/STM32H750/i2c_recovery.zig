//! The I2C bus recovery as data and steps, std only so the host tests it.
//!
//! A slave that stops in the middle of a byte keeps SDA low. The master
//! then cannot make a START, and every transfer fails. A reset of the
//! I2C peripheral does not help, because the slave holds the line. The
//! recovery drives the lines as GPIO: it gives up to 9 SCL clocks (one
//! byte and its ACK) until the slave releases SDA, then a STOP. The
//! slave's state machine is then idle again.
//!
//! `run` takes the lines as a value with these methods: `sclHigh`,
//! `sclLow`, `sdaHigh`, `sdaLow` (a high releases an open-drain line),
//! `sclIsLow`, `sdaIsLow` (read the line) and `wait` (half of a bit).

const std = @import("std");

/// The maximum number of SCL clocks: the 8 bits of a byte and its ACK.
pub const max_pulses = 9;

/// What one recovery found and did.
pub const Recovery = struct {
    /// SCL read low with both lines released: a slave holds the clock,
    /// and clocks from the master cannot help.
    scl_low_before: bool = false,
    /// SDA read low with both lines released: a slave holds the data line.
    sda_low_before: bool = false,
    /// The SCL clocks given before SDA read high, 0 to `max_pulses`.
    pulses: u8 = 0,
    /// SDA read low after the STOP: the slave did not release the line.
    sda_low_after: bool = false,
};

/// When the recovery gives a STOP at its end.
pub const Stop = enum {
    /// Only after the recovery gave clocks.
    if_clocked,
    /// After every recovery, so a slave that waits in a transfer goes
    /// idle too.
    always,
};

/// Releases both lines, clocks SCL until SDA reads high (at most
/// `max_pulses` times), gives a STOP as `stop` tells, and reads SDA again.
pub fn run(lines: anytype, stop: Stop) Recovery {
    lines.sclHigh();
    lines.sdaHigh();
    lines.wait();
    var r: Recovery = .{
        .scl_low_before = lines.sclIsLow(),
        .sda_low_before = lines.sdaIsLow(),
    };
    while (r.pulses < max_pulses and lines.sdaIsLow()) : (r.pulses += 1) {
        lines.sclLow();
        lines.wait();
        lines.sclHigh();
        lines.wait();
    }
    if (stop == .always or r.pulses > 0) {
        // SDA goes low while SCL is high, then high while SCL is high:
        // the rising edge of SDA with SCL high is the STOP.
        lines.sdaLow();
        lines.wait();
        lines.sclHigh();
        lines.wait();
        lines.sdaHigh();
        lines.wait();
    }
    r.sda_low_after = lines.sdaIsLow();
    return r;
}

// ============================================================================

const testing = std.testing;

/// Two open-drain lines with one slave on them. The slave holds SDA low
/// for `hold` more SCL clocks (a rising edge of SCL is a clock); a
/// `hold` of `forever` never ends. `scl_held` is a slave that holds SCL.
const FakeBus = struct {
    const forever = std.math.maxInt(u8);

    hold: u8 = 0,
    scl_held: bool = false,
    master_scl_low: bool = false,
    master_sda_low: bool = false,
    clocks: u8 = 0,
    /// Set at each rising edge of SDA while SCL reads high.
    stops: u8 = 0,

    fn sclIsLow(self: *FakeBus) bool {
        return self.master_scl_low or self.scl_held;
    }

    fn sdaIsLow(self: *FakeBus) bool {
        return self.master_sda_low or self.hold > 0;
    }

    fn sclLow(self: *FakeBus) void {
        self.master_scl_low = true;
    }

    fn sclHigh(self: *FakeBus) void {
        const was_low = self.sclIsLow();
        self.master_scl_low = false;
        if (!was_low or self.sclIsLow()) return;
        self.clocks += 1;
        if (self.hold > 0 and self.hold != forever) self.hold -= 1;
    }

    fn sdaLow(self: *FakeBus) void {
        self.master_sda_low = true;
    }

    fn sdaHigh(self: *FakeBus) void {
        const was_low = self.sdaIsLow();
        self.master_sda_low = false;
        if (was_low and !self.sdaIsLow() and !self.sclIsLow()) self.stops += 1;
    }

    fn wait(_: *FakeBus) void {}
};

test "a free bus gets no clocks and, at boot, no STOP" {
    var bus: FakeBus = .{};
    const r = run(&bus, .if_clocked);
    try testing.expectEqual(Recovery{}, r);
    try testing.expectEqual(@as(u8, 0), bus.clocks);
    try testing.expectEqual(@as(u8, 0), bus.stops);
}

test "a free bus gets a STOP when the caller asks for one always" {
    var bus: FakeBus = .{};
    const r = run(&bus, .always);
    try testing.expectEqual(Recovery{}, r);
    try testing.expectEqual(@as(u8, 0), bus.clocks);
    try testing.expectEqual(@as(u8, 1), bus.stops);
}

test "a slave that holds SDA for 3 clocks gets 3 clocks and a STOP" {
    var bus: FakeBus = .{ .hold = 3 };
    const r = run(&bus, .if_clocked);
    try testing.expectEqual(Recovery{ .sda_low_before = true, .pulses = 3 }, r);
    try testing.expectEqual(@as(u8, 3), bus.clocks);
    try testing.expectEqual(@as(u8, 1), bus.stops);
    try testing.expect(!bus.sdaIsLow() and !bus.sclIsLow());
}

test "a slave that holds SDA for a whole byte and its ACK gets 9 clocks" {
    var bus: FakeBus = .{ .hold = 9 };
    const r = run(&bus, .always);
    try testing.expectEqual(Recovery{ .sda_low_before = true, .pulses = 9 }, r);
    try testing.expectEqual(@as(u8, 1), bus.stops);
}

test "a slave that never releases SDA stops the clocks at 9 and reads low after" {
    var bus: FakeBus = .{ .hold = FakeBus.forever };
    const r = run(&bus, .always);
    try testing.expectEqual(Recovery{ .sda_low_before = true, .pulses = max_pulses, .sda_low_after = true }, r);
    try testing.expectEqual(@as(u8, max_pulses), bus.clocks);
    try testing.expectEqual(@as(u8, 0), bus.stops);
}

test "a slave that holds SCL shows in the result" {
    var bus: FakeBus = .{ .scl_held = true, .hold = 2 };
    const r = run(&bus, .always);
    try testing.expect(r.scl_low_before);
    try testing.expect(r.sda_low_before);
    // With SCL held there is no clock edge, so SDA stays low.
    try testing.expectEqual(@as(u8, 0), bus.clocks);
    try testing.expect(r.sda_low_after);
}
