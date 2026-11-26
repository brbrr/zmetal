//! The v3 panel scanner's pins (spec values, verbatim from the plan's
//! Global Constraints) and the `Io` that `panel_scanner.Scanner` scans them
//! through.
//!
//! The C031's GPIO ports have the same register layout as the STM32H7's
//! (generated definitions, gpio_v2: MODER 2 bits per pin at 0x00, OTYPER 1
//! bit at 0x04, OSPEEDR 2 bits at 0x08, PUPDR 2 bits at 0x0C, IDR 0x10,
//! ODR 0x14, BSRR 0x18 with set in 15:0 and reset in 31:16, AFR[2] 4 bits
//! per pin at 0x20), so the field arithmetic is the Daisy HAL's `gpio_bits`.
//! Every MODER, OTYPER, OSPEEDR, PUPDR and AFR write here is a
//! read-modify-write whose masks are built at compile time from the table
//! below; the BSRR writes are plain stores whose set and reset bits name
//! table pins only. Either way the mode bits of a pin outside the table are
//! never written.

const std = @import("std");
const microzig = @import("microzig");
const bits = @import("gpio_bits");
const clock = @import("clock.zig");

const chip = microzig.chip;
const RCC = chip.peripherals.RCC;
const GPIO = chip.types.peripherals.gpio_v2.GPIO;

/// A GPIO port; its value is its bit in RCC_IOPENR (generated: GPIOENR:
/// GPIOAEN 0, GPIOBEN 1, GPIOCEN 2).
pub const Port = enum(u3) {
    a = 0,
    b = 1,
    c = 2,

    pub fn regs(port: Port) *volatile GPIO {
        return switch (port) {
            .a => chip.peripherals.GPIOA,
            .b => chip.peripherals.GPIOB,
            .c => chip.peripherals.GPIOC,
        };
    }

    /// The port's clock-enable bit in RCC_IOPENR.
    pub fn clockBit(port: Port) u32 {
        return @as(u32, 1) << @backingInt(port);
    }
};

pub const Pin = struct {
    port: Port,
    num: u4,

    fn is(p: Pin, port: Port, num: u4) bool {
        return p.port == port and p.num == num;
    }
};

fn pa(n: u4) Pin {
    return .{ .port = .a, .num = n };
}
fn pb(n: u4) Pin {
    return .{ .port = .b, .num = n };
}
fn pc(n: u4) Pin {
    return .{ .port = .c, .num = n };
}

/// COL_1..7: driven low one at a time, bits 0..6 of `Io.drive`.
pub const columns = [7]Pin{ pa(0), pa(1), pa(2), pa(3), pa(4), pa(5), pa(6) };
/// ROW_1..7: inputs with pull-ups, bits 0..6 of `Io.sense`.
pub const rows = [7]Pin{ pb(0), pb(1), pb(2), pa(8), pc(6), pa(11), pa(12) };
/// ENC1..4, A and B. The board has external pull-ups and RC filters.
pub const encoders = [4][2]Pin{
    .{ pa(7), pa(15) },
    .{ pb(3), pb(4) },
    .{ pb(5), pb(9) },
    .{ pc(14), pc(15) },
};
/// I2C1 to the Daisy, alternate function 6 on both (stm32-data, STM32C031K6).
pub const i2c_scl = pb(6);
pub const i2c_sda = pb(7);
pub const i2c_af = 6;
/// INT to the Daisy, open-drain, active low; the Daisy pulls it up.
pub const int = pb(8);
/// The status LED, high = on.
pub const led = pa(9);

/// Every pin this firmware configures.
const all = columns ++ rows ++ encoders[0] ++ encoders[1] ++ encoders[2] ++ encoders[3] ++
    [_]Pin{ i2c_scl, i2c_sda, int, led };

// S5: SWD (PA13, PA14) and NRST (PF2) stay as they come out of reset, so
// the TC2030 pads always work. No entry of the table may be one of them,
// and no two entries may be the same pin.
comptime {
    for (all, 0..) |p, i| {
        if (p.is(.a, 13) or p.is(.a, 14))
            @compileError("pins: PA13 and PA14 are SWD and must never be configured");
        // There is no port F in `Port`; PF2 (NRST) cannot even be named.
        for (all[i + 1 ..]) |q| {
            if (p.is(q.port, q.num)) @compileError("pins: a pin appears twice in the table");
        }
    }
}

const Mode = enum(u2) { input = 0, output = 1, alternate = 2 };
const Pull = enum(u2) { none = 0, up = 1 };

const Config = struct {
    mode: Mode,
    pull: Pull = .none,
    open_drain: bool = false,
    /// An output's level, written before its mode, so it never drives the
    /// other level first.
    initial_high: bool = false,
    af: u4 = 0,
};

/// One port's register masks for a set of pins, at compile time.
const PortMasks = struct {
    moder_clear: u32 = 0,
    moder_set: u32 = 0,
    otyper_clear: u32 = 0,
    otyper_set: u32 = 0,
    pupdr_clear: u32 = 0,
    pupdr_set: u32 = 0,
    ospeedr_clear: u32 = 0, // low speed (0) on every pin configured
    afr_clear: [2]u32 = .{ 0, 0 },
    afr_set: [2]u32 = .{ 0, 0 },
    bsrr: u32 = 0,

    fn add(m: *PortMasks, num: u4, cfg: Config) void {
        const n: u5 = num;
        m.moder_clear = bits.setField(m.moder_clear, n, 2, 0b11);
        m.moder_set = bits.setField(m.moder_set, n, 2, @backingInt(cfg.mode));
        m.otyper_clear = bits.setField(m.otyper_clear, n, 1, 1);
        m.otyper_set = bits.setField(m.otyper_set, n, 1, @intFromBool(cfg.open_drain));
        m.pupdr_clear = bits.setField(m.pupdr_clear, n, 2, 0b11);
        m.pupdr_set = bits.setField(m.pupdr_set, n, 2, @backingInt(cfg.pull));
        m.ospeedr_clear = bits.setField(m.ospeedr_clear, n, 2, 0b11);
        if (cfg.mode == .alternate) {
            m.afr_clear[num / 8] = bits.setField(m.afr_clear[num / 8], num % 8, 4, 0xF);
            m.afr_set[num / 8] = bits.setField(m.afr_set[num / 8], num % 8, 4, cfg.af);
        }
        if (cfg.mode == .output) m.bsrr |= bits.bsrr(num, cfg.initial_high);
    }
};

/// Configures `pins` with `cfg`, port by port: AF, type, speed, pull and the
/// first level first, the mode last.
fn configure(comptime pins: []const Pin, comptime cfg: Config) void {
    inline for (.{ Port.a, Port.b, Port.c }) |port| {
        const m = comptime blk: {
            var masks: PortMasks = .{};
            for (pins) |p| {
                if (p.port == port) masks.add(p.num, cfg);
            }
            break :blk masks;
        };
        if (m.moder_clear != 0) {
            const r = port.regs();
            inline for (0..2) |i| {
                if (m.afr_clear[i] != 0) r.AFR[i].raw = (r.AFR[i].raw & ~m.afr_clear[i]) | m.afr_set[i];
            }
            r.OTYPER.raw = (r.OTYPER.raw & ~m.otyper_clear) | m.otyper_set;
            r.OSPEEDR.raw = r.OSPEEDR.raw & ~m.ospeedr_clear;
            r.PUPDR.raw = (r.PUPDR.raw & ~m.pupdr_clear) | m.pupdr_set;
            if (m.bsrr != 0) r.BSRR.raw = m.bsrr;
            r.MODER.raw = (r.MODER.raw & ~m.moder_clear) | m.moder_set;
        }
    }
}

/// RCC_IOPENR (generated: GPIOENR): GPIOAEN 0, GPIOBEN 1, GPIOCEN 2.
const iopenr_abc: u32 = 0b111;

/// Clocks GPIOA..C and configures the matrix, encoder, INT and LED pins.
/// The columns start released (high, open-drain): the first scan drives
/// them low, as `matrix_scan.Scanner` does from `idle_low = false`. INT
/// starts low (asserted until the Daisy's first acknowledge), the LED off.
/// The I2C pins are `i2c_target.init`'s.
pub fn init() void {
    RCC.GPIOENR.raw = RCC.GPIOENR.raw | iopenr_abc;
    _ = RCC.GPIOENR.raw; // two cycles before the ports answer (RM0490 6.2)

    // Open-drain columns: a released column floats instead of driving high,
    // so two keys in one row never short a high column to a low one,
    // whichever way the matrix diodes face.
    configure(&columns, .{ .mode = .output, .open_drain = true, .initial_high = true });
    configure(&rows, .{ .mode = .input, .pull = .up });
    configure(&(encoders[0] ++ encoders[1] ++ encoders[2] ++ encoders[3]), .{ .mode = .input });
    configure(&.{int}, .{ .mode = .output, .open_drain = true, .initial_high = false });
    configure(&.{led}, .{ .mode = .output, .initial_high = false });
}

/// I2C1's SCL and SDA: AF6, open-drain, no pull (the bus has its pull-ups),
/// low speed.
pub fn initI2c() void {
    configure(&.{ i2c_scl, i2c_sda }, .{ .mode = .alternate, .open_drain = true, .af = i2c_af });
}

/// INT low (`asserted`) or released.
pub fn setInt(asserted: bool) void {
    int.port.regs().BSRR.raw = bits.bsrr(int.num, !asserted);
}

pub fn setLed(on: bool) void {
    led.port.regs().BSRR.raw = bits.bsrr(led.num, on);
}

/// The wait between driving a column and reading the rows: 10 us, about
/// five time constants of a row's internal pull-up (25-55 kOhm) on 30 pF.
/// An estimate, not measured: the bring-up list has the check.
pub const settle_cycles = clock.hclk_hz / 1_000_000 * 10;

/// Reads the IDR of every port once.
fn inputs() [3]u32 {
    return .{
        Port.a.regs().IDR.raw,
        Port.b.regs().IDR.raw,
        Port.c.regs().IDR.raw,
    };
}

inline fn level(idr: [3]u32, comptime p: Pin) u1 {
    return @truncate(idr[@backingInt(p.port)] >> p.num);
}

/// The `Io` of `panel_scanner.Scanner`: the `matrix_scan` contract plus the
/// encoder pins. No transfer can fail, so the error sets are empty.
pub const Io = struct {
    /// A 0 bit drives that column (COL_1..7 = bits 0..6) low, a 1 releases it.
    pub fn drive(_: Io, cols: u8) error{}!void {
        inline for (.{ Port.a, Port.b, Port.c }) |port| {
            comptime var used = false;
            var word: u32 = 0;
            inline for (columns, 0..) |p, i| {
                if (p.port == port) {
                    used = true;
                    word |= bits.bsrr(p.num, cols & (1 << i) != 0);
                }
            }
            if (used) port.regs().BSRR.raw = word;
        }
    }

    /// The rows (ROW_1..7 = bits 0..6); a pressed key pulls its row low.
    /// Bit 7 reads 1.
    pub fn sense(_: Io) error{}!u8 {
        const idr = inputs();
        var v: u8 = 0x80;
        inline for (rows, 0..) |p, i| v |= @as(u8, level(idr, p)) << i;
        return v;
    }

    pub fn settle(_: Io) void {
        clock.waitCycles(settle_cycles);
    }

    /// A (`[i][0]`) and B (`[i][1]`) of ENC1..4, 1 = high.
    pub fn encoderPins(_: Io) [4][2]u1 {
        const idr = inputs();
        var out: [4][2]u1 = undefined;
        inline for (encoders, 0..) |ab, i| {
            out[i] = .{ level(idr, ab[0]), level(idr, ab[1]) };
        }
        return out;
    }
};

comptime {
    std.debug.assert(columns.len == 7 and rows.len == 7);
}
