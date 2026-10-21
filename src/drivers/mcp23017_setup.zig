//! The MCP23017's configuration as data, std only so the host tests it:
//! the register writes that set a chip up from any state it can be in,
//! and the check of a read-back against them.
//!
//! The chip keeps its registers through a reset of the MCU; only a power
//! cycle or its RESET pin clears them. So the set-up cannot assume the
//! power-on defaults. IOCON.BANK is the dangerous bit: with BANK=1 every
//! register has another address, and IOCON sits at 0x05 instead of 0x0A.
//! The first write, 0x00 at 0x05, clears BANK in that map, and in the
//! BANK=0 map it is a harmless write of GPINTENB = 0. Every register the
//! driver relies on is then written in the BANK=0 map.

const std = @import("std");

/// Register addresses with IOCON.BANK = 0.
pub const reg = struct {
    pub const IODIRA: u8 = 0x00;
    pub const IPOLA: u8 = 0x02;
    pub const GPINTENA: u8 = 0x04;
    pub const DEFVALA: u8 = 0x06;
    pub const INTCONA: u8 = 0x08;
    pub const IOCON: u8 = 0x0A;
    pub const GPPUA: u8 = 0x0C;
    pub const GPIOA: u8 = 0x12;
    pub const OLATA: u8 = 0x14;
    /// IOCON's address with IOCON.BANK = 1.
    pub const IOCON_BANK1: u8 = 0x05;
};

/// IOCON: SEQOP = 1, so a two-byte access toggles between the A and B
/// registers of a pair; BANK = 0; the INT pins push-pull, active low.
pub const iocon: u8 = 0x20;

/// What a user of the chip sets: per port A and B, the direction (1 is
/// an input), the pull-ups (1 is on) and the output latch.
pub const Setup = struct {
    iodir: [2]u8 = .{ 0xFF, 0xFF },
    gppu: [2]u8 = .{ 0xFF, 0xFF },
    olat: [2]u8 = .{ 0x00, 0x00 },
};

/// One register write: the address, then the value.
pub const Write = struct { addr: u8, value: u8 };

pub const write_count = 2 + 2 * 6;

/// The writes, in order, that put a chip in `setup` from any state: IOCON
/// in both maps first, then each register pair, with no polarity
/// inversion and no interrupt-on-change.
pub fn writes(setup: Setup) [write_count]Write {
    var w: [write_count]Write = undefined;
    w[0] = .{ .addr = reg.IOCON_BANK1, .value = 0x00 };
    w[1] = .{ .addr = reg.IOCON, .value = iocon };
    const pairs = [_]struct { addr: u8, v: [2]u8 }{
        .{ .addr = reg.IODIRA, .v = setup.iodir },
        .{ .addr = reg.IPOLA, .v = .{ 0, 0 } },
        .{ .addr = reg.GPINTENA, .v = .{ 0, 0 } },
        .{ .addr = reg.DEFVALA, .v = .{ 0, 0 } },
        .{ .addr = reg.INTCONA, .v = .{ 0, 0 } },
        .{ .addr = reg.GPPUA, .v = setup.gppu },
    };
    for (pairs, 0..) |p, i| {
        w[2 + 2 * i] = .{ .addr = p.addr, .value = p.v[0] };
        w[3 + 2 * i] = .{ .addr = p.addr + 1, .value = p.v[1] };
    }
    return w;
}

/// The registers read back to check a chip, in the BANK=0 map. With
/// BANK=1 set, these addresses hold other registers and the check fails.
pub const Readback = struct {
    iocon: u8,
    iodir: [2]u8,
    ipol: [2]u8,
    gpinten: [2]u8,
    gppu: [2]u8,

    /// True when the chip holds `setup`.
    pub fn matches(self: Readback, setup: Setup) bool {
        return self.iocon == iocon and
            std.mem.eql(u8, &self.iodir, &setup.iodir) and
            std.mem.eql(u8, &self.ipol, &.{ 0, 0 }) and
            std.mem.eql(u8, &self.gpinten, &.{ 0, 0 }) and
            std.mem.eql(u8, &self.gppu, &setup.gppu);
    }
};

// ============================================================================

const testing = std.testing;

/// A chip's 22 registers in both maps, enough to run `writes` against.
/// With BANK=1 the A registers are 0x00-0x0A and the B registers
/// 0x10-0x1A, in the order of the BANK=0 pairs.
const FakeChip = struct {
    // Indexed by the BANK=0 address.
    r: [0x16]u8 = @splat(0),

    fn bank1(self: *const FakeChip) bool {
        return self.r[reg.IOCON] & 0x80 != 0;
    }

    /// The BANK=0 address of a register at `addr` in the current map, or
    /// null for an address with no register.
    fn index(self: *const FakeChip, addr: u8) ?u8 {
        if (!self.bank1()) return if (addr < 0x16) addr else null;
        const port: u8 = if (addr >= 0x10) 1 else 0;
        const off = addr - port * 0x10;
        if (off > 0x0A) return null;
        return off * 2 + port;
    }

    fn write(self: *FakeChip, addr: u8, value: u8) void {
        const i = self.index(addr) orelse return;
        // IOCON is one register at both of its BANK=0 addresses.
        if (i == reg.IOCON or i == reg.IOCON + 1) {
            self.r[reg.IOCON] = value;
            self.r[reg.IOCON + 1] = value;
        } else self.r[i] = value;
    }

    fn read(self: *const FakeChip, addr: u8) u8 {
        const i = self.index(addr) orelse return 0;
        return self.r[i];
    }

    fn apply(self: *FakeChip, setup: Setup) void {
        for (writes(setup)) |w| self.write(w.addr, w.value);
    }

    fn readback(self: *const FakeChip) Readback {
        return .{
            .iocon = self.read(reg.IOCON),
            .iodir = .{ self.read(reg.IODIRA), self.read(reg.IODIRA + 1) },
            .ipol = .{ self.read(reg.IPOLA), self.read(reg.IPOLA + 1) },
            .gpinten = .{ self.read(reg.GPINTENA), self.read(reg.GPINTENA + 1) },
            .gppu = .{ self.read(reg.GPPUA), self.read(reg.GPPUA + 1) },
        };
    }
};

const keys: Setup = .{ .iodir = .{ 0x00, 0xFF }, .gppu = .{ 0xFF, 0xFF }, .olat = .{ 0xFF, 0x00 } };

fn powerOn() FakeChip {
    var c: FakeChip = .{};
    c.r[reg.IODIRA] = 0xFF;
    c.r[reg.IODIRA + 1] = 0xFF;
    return c;
}

test "the set-up from power-on gives a chip that matches" {
    var c = powerOn();
    try testing.expect(!c.readback().matches(keys));
    c.apply(keys);
    try testing.expect(c.readback().matches(keys));
}

test "a chip left with BANK=1 fails the check, and the set-up brings it back" {
    var c = powerOn();
    c.apply(keys);
    c.write(reg.IOCON, 0xA0); // BANK=1, as one bad write can leave it
    try testing.expect(c.bank1());
    try testing.expect(!c.readback().matches(keys));
    c.apply(keys);
    try testing.expect(!c.bank1());
    try testing.expect(c.readback().matches(keys));
}

test "a stale polarity or interrupt-on-change fails the check, and the set-up clears it" {
    var c = powerOn();
    c.apply(keys);
    c.write(reg.IPOLA + 1, 0x80);
    try testing.expect(!c.readback().matches(keys));
    c.apply(keys);
    try testing.expect(c.readback().matches(keys));
    c.write(reg.GPINTENA, 0x01);
    try testing.expect(!c.readback().matches(keys));
}

test "the first write is IOCON = 0 in the BANK=1 map, a GPINTENB write in the BANK=0 map" {
    const w = writes(keys);
    try testing.expectEqual(Write{ .addr = 0x05, .value = 0 }, w[0]);
    try testing.expectEqual(Write{ .addr = 0x0A, .value = iocon }, w[1]);
    // With BANK=0, 0x05 is GPINTENB, and the set-up writes 0 there anyway.
    var found = false;
    for (w[2..]) |x| if (x.addr == reg.GPINTENA + 1) {
        found = true;
        try testing.expectEqual(@as(u8, 0), x.value);
    };
    try testing.expect(found);
}
