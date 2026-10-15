//! Runtime GPIO handle (libdaisy `GPIO`): built from a `hal.Pin` value, so pins
//! can be stored and passed around. Writes go through BSRR (atomic per pin).
const microzig = @import("microzig");
const pin_name = @import("pin_name.zig");
const GPIO = microzig.chip.types.peripherals.gpio_v2.GPIO;
const RCC = microzig.chip.peripherals.RCC;

pub const Gpio = struct {
    pub const Config = struct {
        mode: enum { input, output, analog } = .output,
        pull: enum { none, up, down } = .none,
        speed: enum { low, medium, high, very_high } = .low,
        open_drain: bool = false,
    };

    regs: *volatile GPIO,
    bit: u4,

    /// Enable the port clock and configure the pin. Mode is written last so the
    /// pin only starts driving once type/pull/speed are in place.
    pub fn init(p: pin_name.Pin, cfg: Config) Gpio {
        RCC.AHB4ENR.raw |= @as(u32, 1) << @intFromEnum(p.port);
        _ = RCC.AHB4ENR.raw; // ~2-cycle clock-enable latency (see gpio.zig configure)

        const g = Gpio{ .regs = @ptrFromInt(pin_name.gpioBase(p.port)), .bit = p.num };
        const n: u5 = p.num;
        const two: u5 = n * 2;
        g.regs.OTYPER.raw = (g.regs.OTYPER.raw & ~(@as(u32, 1) << n)) | (@as(u32, @intFromBool(cfg.open_drain)) << n);
        g.regs.OSPEEDR.raw = (g.regs.OSPEEDR.raw & ~(@as(u32, 3) << two)) | (@as(u32, @intFromEnum(cfg.speed)) << two);
        const pupd: u32 = switch (cfg.pull) {
            .none => 0,
            .up => 1,
            .down => 2,
        };
        g.regs.PUPDR.raw = (g.regs.PUPDR.raw & ~(@as(u32, 3) << two)) | (pupd << two);
        const moder: u32 = switch (cfg.mode) {
            .input => 0,
            .output => 1,
            .analog => 3,
        };
        g.regs.MODER.raw = (g.regs.MODER.raw & ~(@as(u32, 3) << two)) | (moder << two);
        return g;
    }

    pub fn write(self: Gpio, high: bool) void {
        const m = @as(u32, 1) << self.bit;
        self.regs.BSRR.raw = if (high) m else m << 16;
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
