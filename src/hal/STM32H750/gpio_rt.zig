//! Runtime GPIO handle (libdaisy `GPIO`): built from a `hal.Pin` value, so pins
//! can be stored and passed around. Writes go through BSRR (atomic per pin).
//! The one place that writes the pin registers: `gpio.Pin` (the comptime pins
//! the drivers use) configures and drives its pins through this handle.
const microzig = @import("microzig");
const pin_name = @import("pin_name.zig");
const bits = @import("gpio_bits.zig");
const gpio = @import("gpio.zig");
const GPIO = microzig.chip.types.peripherals.gpio_v2.GPIO;
const RCC = microzig.chip.peripherals.RCC;

pub const Gpio = struct {
    pub const Config = struct {
        mode: union(enum) { input, output, analog, alternate: gpio.AlternateFunction } = .output,
        pull: enum { none, up, down } = .none,
        speed: enum { low, medium, high, very_high } = .low,
        open_drain: bool = false,
        /// The output latch level, written before the mode, so the pin never
        /// drives the other level first. `.unchanged` writes nothing.
        initial: enum { unchanged, low, high } = .unchanged,
    };

    regs: *volatile GPIO,
    bit: u4,

    /// A handle that touches no register: to read or write a pin something
    /// else configured.
    pub fn handle(p: pin_name.Pin) Gpio {
        return .{ .regs = @ptrFromInt(pin_name.gpioBase(p.port)), .bit = p.num };
    }

    /// Enable the port clock and configure the pin. Mode is written last so the
    /// pin only starts driving once AF/type/speed/pull and its first level are
    /// in place.
    pub fn init(p: pin_name.Pin, cfg: Config) Gpio {
        RCC.AHB4ENR.raw |= @as(u32, 1) << @intFromEnum(p.port);
        // STM32H7: after setting a peripheral's RCC clock-enable bit there is
        // a ~2 clock-cycle delay before its registers are accessible (ST's
        // __HAL_RCC_GPIOx_CLK_ENABLE() reads the ENR back). Touching the GPIO
        // too soon raises an AHB bus fault, so read back to force the delay.
        _ = RCC.AHB4ENR.raw;

        const g = handle(p);
        const r = g.regs;
        const n: u5 = p.num;
        switch (cfg.mode) {
            // microzig groups AFRL/AFRH into AFR[2], 8 four-bit fields each.
            .alternate => |af| r.AFR[p.num / 8].raw = bits.setField(r.AFR[p.num / 8].raw, p.num % 8, 4, @intFromEnum(af)),
            else => {},
        }
        r.OTYPER.raw = bits.setField(r.OTYPER.raw, n, 1, @intFromBool(cfg.open_drain));
        r.OSPEEDR.raw = bits.setField(r.OSPEEDR.raw, n, 2, @intFromEnum(cfg.speed));
        const pupd: u32 = switch (cfg.pull) {
            .none => 0,
            .up => 1,
            .down => 2,
        };
        r.PUPDR.raw = bits.setField(r.PUPDR.raw, n, 2, pupd);
        switch (cfg.initial) {
            .unchanged => {},
            .low => g.write(false),
            .high => g.write(true),
        }
        // MODER values (RM0433): the union's tag order is not the field's.
        const moder: u32 = switch (cfg.mode) {
            .input => 0,
            .output => 1,
            .alternate => 2,
            .analog => 3,
        };
        r.MODER.raw = bits.setField(r.MODER.raw, n, 2, moder);
        return g;
    }

    pub fn write(self: Gpio, high: bool) void {
        self.regs.BSRR.raw = bits.bsrr(self.bit, high);
    }

    pub fn set(self: Gpio) void {
        self.write(true);
    }

    pub fn clear(self: Gpio) void {
        self.write(false);
    }

    pub fn toggle(self: Gpio) void {
        self.write(self.regs.ODR.raw & (@as(u32, 1) << self.bit) == 0);
    }

    pub fn read(self: Gpio) bool {
        return self.regs.IDR.raw & (@as(u32, 1) << self.bit) != 0;
    }
};
