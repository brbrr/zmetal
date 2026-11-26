//! MAX17048 battery fuel gauge driver, std only so the host tests it.
//!
//! Every register is 16 bits, sent high byte first, and the chip ignores any
//! 8-bit write, so every access here is one 16-bit transfer. The driver has
//! no way to turn sleep on: with the system off the bus idles low, which is
//! the gauge's sleep trigger once MODE.EnSleep is set, so `configure` makes
//! sure it is off. The power-on-reset command is never sent (it restarts the
//! gauge's estimate), and neither is quick-start.

const std = @import("std");

pub const default_address: u7 = 0x36;

pub const Error = error{WrongPart};

const regs = struct {
    const vcell: u8 = 0x02;
    const soc: u8 = 0x04;
    const mode: u8 = 0x06;
    const version: u8 = 0x08;
    const config: u8 = 0x0C;
    const vreset: u8 = 0x18;
    const status: u8 = 0x1A;
};

/// CONFIG.SLEEP.
const config_sleep: u16 = 0x0080;
/// STATUS.RI, set at power-up until cleared.
const status_ri: u16 = 0x0100;
/// VRESET.Dis, the fast reset comparator off in hibernate.
const vreset_dis: u16 = 0x0100;

const vreset_min_mv: u16 = 2280;
const vreset_max_mv: u16 = 3480;
const vreset_step_mv: u16 = 40;

/// True when a VERSION register value is that of the MAX17048 (0x001_).
pub fn isMax17048(version: u16) bool {
    return (version & 0xFFF0) == 0x0010;
}

/// VCELL in millivolts: 78.125 uV per LSB is raw * 5 / 64 mV.
pub fn cellMillivolts(vcell: u16) u16 {
    const mv: u32 = @as(u32, vcell) * 5 / 64;
    return @intCast(mv);
}

/// SOC in whole percent: the upper byte, at most 100.
pub fn socPercent(soc: u16) u8 {
    return @intCast(@min(soc >> 8, 100));
}

/// The VRESET register word for a threshold: 40 mV steps rounded down,
/// clamped to 2280..3480 mV, in the upper byte with Dis in bit 8; the low
/// byte (the read-only ID) is 0.
pub fn vresetWord(mv: u16, comparator_off: bool) u16 {
    const clamped = std.math.clamp(mv, vreset_min_mv, vreset_max_mv);
    const code: u16 = clamped / vreset_step_mv;
    return (code << 9) | (if (comparator_off) vreset_dis else 0);
}

pub const Config = struct {
    /// Below this the gauge takes the cell as removed and restarts its estimate when it returns.
    reset_voltage_mv: u16 = 3000,
    /// Turns the fast reset comparator off while the gauge hibernates (about 1 uA less, by the
    /// datasheet's current figures); a cell swap is then only seen at the next voltage sample.
    reset_comparator_off: bool = false,
};

pub const Reading = struct { cell_mv: u16, soc_percent: u8, soc_raw: u16 };

/// The driver, generic over `Bus`: a type, or a pointer to one, that has
///
/// - `pub const Error`, an error set;
/// - `write(self, address: u7, bytes: []const u8) Error!void`: one write
///   transfer of `bytes`, START to STOP;
/// - `writeThenRead(self, address: u7, tx: []const u8, rx: []u8) Error!void`:
///   a write of `tx`, a repeated START, and a read that fills `rx`.
///
/// The gauge itself needs only standard I2C timing ([POWER] §2.1), but on
/// the v3 board it shares a bus with the BQ25628, whose timing rule covers
/// every START on the bus, the gauge's included ([POWER] §1.1). So run
/// that bus at 100 kHz with at least 90 µs between STARTs, as the
/// `Bq25628` doc says (with zmetal's HAL: `.speed = .I2C_100KHZ,
/// .min_start_gap_us = 90`): every read here uses a repeated START too.
/// This driver adds no delays.
pub fn Max17048(comptime Bus: type) type {
    const BusType = switch (@typeInfo(Bus)) {
        .pointer => |p| p.child,
        else => Bus,
    };
    if (!@hasDecl(BusType, "Error") or @typeInfo(BusType.Error) != .error_set)
        @compileError(@typeName(Bus) ++ " has no `pub const Error` error set");

    return struct {
        const Self = @This();

        /// The errors of a transfer on `Bus`.
        pub const BusError = BusType.Error;

        bus: Bus,
        address: u7,

        /// Reads VERSION and checks it; writes nothing.
        pub fn init(bus: Bus, address: u7) (BusError || Error)!Self {
            const self: Self = .{ .bus = bus, .address = address };
            if (!isMax17048(try self.readReg(regs.version))) return error.WrongPart;
            return self;
        }

        /// Makes sure sleep is off, sets the reset voltage and clears the reset
        /// indicator. Returns true when the gauge had lost its settings (STATUS.RI).
        pub fn configure(self: Self, cfg: Config) BusError!bool {
            // EnSleep off, no quick-start. MODE is write-only.
            try self.writeReg(regs.mode, 0x0000);

            const config = try self.readReg(regs.config);
            if (config & config_sleep != 0) try self.writeReg(regs.config, config & ~config_sleep);

            try self.writeReg(regs.vreset, vresetWord(cfg.reset_voltage_mv, cfg.reset_comparator_off));

            const status = try self.readReg(regs.status);
            if (status & status_ri == 0) return false;
            try self.writeReg(regs.status, status & ~status_ri);
            return true;
        }

        pub fn read(self: Self) BusError!Reading {
            const vcell = try self.readReg(regs.vcell);
            const soc = try self.readReg(regs.soc);
            return .{
                .cell_mv = cellMillivolts(vcell),
                .soc_percent = socPercent(soc),
                .soc_raw = soc,
            };
        }

        fn readReg(self: Self, r: u8) BusError!u16 {
            var bytes: [2]u8 = undefined;
            try self.bus.writeThenRead(self.address, &.{r}, &bytes);
            return std.mem.readInt(u16, &bytes, .big);
        }

        fn writeReg(self: Self, r: u8, value: u16) BusError!void {
            var bytes: [3]u8 = undefined;
            bytes[0] = r;
            std.mem.writeInt(u16, bytes[1..3], value, .big);
            try self.bus.write(self.address, &bytes);
        }
    };
}

/// The gauge behind the `Bus` contract: its registers as the bytes of its
/// data memory, the high byte of each at the even address ([POWER] §2.1,
/// "Data Order"), sent and received in address order. Like the chip it
/// takes only whole 16-bit registers ([POWER] §2.1); here anything else is
/// an error.
const FakeGauge = struct {
    pub const Error = error{FakeProtocol};

    mem: [256]u8 = @splat(0),
    writes: usize = 0,
    /// Each write transfer as it went on the wire: pointer, then the two
    /// data bytes.
    wire: [16][3]u8 = undefined,

    const expected_address: u7 = 0x36;

    /// A register's value, high byte at `reg`, as the datasheet writes it.
    /// The wire-order test sets `mem` itself instead.
    fn get(self: *const FakeGauge, reg: u8) u16 {
        return (@as(u16, self.mem[reg]) << 8) | self.mem[reg + 1];
    }
    fn set(self: *FakeGauge, reg: u8, value: u16) void {
        self.mem[reg] = @truncate(value >> 8);
        self.mem[reg + 1] = @truncate(value);
    }
    fn written(self: *const FakeGauge) []const [3]u8 {
        return self.wire[0..self.writes];
    }

    pub fn write(self: *FakeGauge, address: u7, bytes: []const u8) FakeGauge.Error!void {
        if (address != expected_address) return error.FakeProtocol;
        // The real chip ignores any write that is not pointer + 16 bits.
        if (bytes.len != 3 or bytes[0] % 2 != 0) return error.FakeProtocol;
        if (self.writes >= self.wire.len) return error.FakeProtocol;
        self.wire[self.writes] = bytes[0..3].*;
        self.writes += 1;
        self.mem[bytes[0]] = bytes[1];
        self.mem[bytes[0] + 1] = bytes[2];
    }

    pub fn writeThenRead(self: *FakeGauge, address: u7, tx: []const u8, rx: []u8) FakeGauge.Error!void {
        if (address != expected_address) return error.FakeProtocol;
        if (tx.len != 1 or rx.len != 2 or tx[0] % 2 != 0) return error.FakeProtocol;
        rx[0] = self.mem[tx[0]];
        rx[1] = self.mem[tx[0] + 1];
    }
};

fn porGauge() FakeGauge {
    var g: FakeGauge = .{};
    g.set(0x08, 0x0012);
    g.set(0x18, 0x9600);
    g.set(0x1A, 0x0100);
    g.set(0x0C, 0x971C);
    g.set(0x06, 0x0000);
    return g;
}

test "pure conversions" {
    try std.testing.expect(isMax17048(0x0011) and isMax17048(0x0012));
    try std.testing.expect(!isMax17048(0x0000) and !isMax17048(0xFFFF) and !isMax17048(0x0021));
    try std.testing.expectEqual(@as(u16, 4200), cellMillivolts(0xD200));
    try std.testing.expectEqual(@as(u16, 0), cellMillivolts(0));
    try std.testing.expectEqual(@as(u8, 50), socPercent(0x3200));
    try std.testing.expectEqual(@as(u8, 100), socPercent(0x6400));
    try std.testing.expectEqual(@as(u8, 100), socPercent(0x6500)); // 101 % clamps
    try std.testing.expectEqual(@as(u8, 100), socPercent(0xFFFF)); // a floating bus reads all ones
    try std.testing.expectEqual(@as(u16, 5119), cellMillivolts(0xFFFF)); // no overflow at full scale
    try std.testing.expectEqual(@as(u16, 0x9600), vresetWord(3000, false)); // power-on value
    try std.testing.expectEqual(@as(u16, 0x7C00), vresetWord(2480, false));
    try std.testing.expectEqual(@as(u16, 0x7C00), vresetWord(2500, false)); // rounds down
    try std.testing.expectEqual(@as(u16, 0x7F00), vresetWord(2520, true));
    try std.testing.expectEqual(vresetWord(2280, false), vresetWord(0, false));
    try std.testing.expectEqual(vresetWord(3480, false), vresetWord(9999, false));
}
test "init checks the version and writes nothing" {
    var chip = porGauge(); // VERSION 0x0012, VRESET 0x9600, STATUS 0x0100, CONFIG 0x971C, MODE 0x0000
    _ = try Max17048(*FakeGauge).init(&chip, 0x36);
    try std.testing.expectEqual(@as(usize, 0), chip.writes);
    chip.set(0x08, 0xFFFF);
    try std.testing.expectError(error.WrongPart, Max17048(*FakeGauge).init(&chip, 0x36));
}
test "configure sets the reset voltage and clears the reset indicator once" {
    var chip = porGauge();
    const g = try Max17048(*FakeGauge).init(&chip, 0x36);
    try std.testing.expect(try g.configure(.{ .reset_voltage_mv = 2480 }));
    try std.testing.expectEqual(@as(u16, 0x7C00), chip.get(0x18) & 0xFF00);
    try std.testing.expectEqual(@as(u16, 0), chip.get(0x1A) & 0x0100);
    try std.testing.expect(!try g.configure(.{ .reset_voltage_mv = 2480 }));
}
test "configure leaves sleep off and the rest of CONFIG alone" {
    var chip = porGauge();
    const g = try Max17048(*FakeGauge).init(&chip, 0x36);
    _ = try g.configure(.{ .reset_voltage_mv = 2480 });
    try std.testing.expectEqual(@as(u16, 0x0000), chip.get(0x06));
    try std.testing.expectEqual(@as(u16, 0x971C), chip.get(0x0C));
    for (chip.written()) |w| try std.testing.expect(w[0] != 0x0C); // SLEEP was clear: CONFIG is not written
    chip.set(0x06, 0x2000); // EnSleep left on by other firmware
    chip.set(0x0C, 0x979C); // SLEEP set
    _ = try g.configure(.{ .reset_voltage_mv = 2480 });
    try std.testing.expectEqual(@as(u16, 0x0000), chip.get(0x06));
    try std.testing.expectEqual(@as(u16, 0x971C), chip.get(0x0C));
}
test "the bytes on the wire: each register high byte first, written and read" {
    var chip = porGauge();
    const g = try Max17048(*FakeGauge).init(&chip, 0x36);
    _ = try g.configure(.{ .reset_voltage_mv = 2480 });
    // MODE 0x0000. VRESET: 2480 / 40 = 62 = 0x3E; 0x3E << 9 = 0x7C00, the
    // "2.48 V: code 62, MSB byte 0x7C" of [POWER] §2.3. STATUS: 0x0100
    // with RI (bit 8) cleared. CONFIG is not written: SLEEP was clear.
    try std.testing.expectEqualSlices([3]u8, &.{
        .{ 0x06, 0x00, 0x00 },
        .{ 0x18, 0x7C, 0x00 },
        .{ 0x1A, 0x00, 0x00 },
    }, chip.written());
    // Again with the comparator off: Dis is bit 8, so 0x7C00 | 0x0100. RI
    // is clear now, so STATUS is not written.
    _ = try g.configure(.{ .reset_voltage_mv = 2480, .reset_comparator_off = true });
    try std.testing.expectEqualSlices(u8, &.{ 0x18, 0x7D, 0x00 }, &chip.written()[4]);
    try std.testing.expectEqual(@as(usize, 5), chip.writes);
    // VCELL and SOC as the chip sends them, high byte first ([POWER]
    // §2.1): 0xD2 0x00 is 0xD200 = 53760, times 78.125 uV = 4.2 V; 0x32
    // 0x80 is 0x3280, 50 % in the high byte. Read low byte first they
    // would be 0x00D2 (16 mV) and 0x8032 (128 %).
    chip.mem[0x02..0x06].* = .{ 0xD2, 0x00, 0x32, 0x80 };
    const r = try g.read();
    try std.testing.expectEqual(@as(u16, 4200), r.cell_mv);
    try std.testing.expectEqual(@as(u8, 50), r.soc_percent);
    try std.testing.expectEqual(@as(u16, 0x3280), r.soc_raw);
}
test "the driver names its bus's errors" {
    try std.testing.expect(Max17048(*FakeGauge).BusError == FakeGauge.Error);
}
test "reading never writes" {
    var chip = porGauge();
    const g = try Max17048(*FakeGauge).init(&chip, 0x36);
    const before = chip.writes;
    _ = try g.read();
    try std.testing.expectEqual(before, chip.writes);
}
test "read" {
    var chip = porGauge();
    chip.set(0x02, 0xD200);
    chip.set(0x04, 0x3280);
    const r = try (try Max17048(*FakeGauge).init(&chip, 0x36)).read();
    try std.testing.expectEqual(@as(u16, 4200), r.cell_mv);
    try std.testing.expectEqual(@as(u8, 50), r.soc_percent);
    try std.testing.expectEqual(@as(u16, 0x3280), r.soc_raw);
}
