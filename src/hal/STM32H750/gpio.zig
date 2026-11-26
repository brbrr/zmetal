//! GPIO (General Purpose I/O) driver for STM32H750: the comptime pins the
//! drivers use. The registers are written by the run-time handle `Gpio`.

const microzig = @import("microzig");
const pin_name = @import("pin_name.zig");
const Gpio = @import("gpio_rt.zig").Gpio;

// STM32H7 uses GPIO v2 peripheral types
const gpio_types = microzig.chip.types.peripherals.gpio_v2;

pub const AlternateFunction = enum(u4) {
    af0 = 0,
    af1 = 1,
    af2 = 2,
    af3 = 3,
    af4 = 4,
    af5 = 5,
    af6 = 6,
    af7 = 7,
    af8 = 8,
    af9 = 9,
    af10 = 10,
    af11 = 11,
    af12 = 12,
    af13 = 13,
    af14 = 14,
    af15 = 15,

    pub fn get(self: @This()) u4 {
        return @intFromEnum(self);
    }
};

pub const Mode = union(enum) {
    /// Input mode (reset state)
    input,
    /// General purpose output mode
    output,
    /// Alternate function mode
    alternate: AlternateFunction,
    /// Analog mode
    analog,

    pub fn to_moder(self: Mode) gpio_types.MODER {
        return switch (self) {
            .input => @enumFromInt(0),
            .output => @enumFromInt(1),
            .alternate => @enumFromInt(2),
            .analog => @enumFromInt(3),
        };
    }
};

pub const PinConfig = struct {
    mode: Mode = .output,
    otype: gpio_types.OT = .PushPull,
    pull: gpio_types.PUPDR = .Floating,
    speed: gpio_types.OSPEEDR = .LowSpeed,
};

/// The run-time handle's config for a `PinConfig`. The chip enums and
/// `Gpio.Config` name the same field values (RM0433): OT PushPull=0
/// OpenDrain=1; PUPDR Floating=0 PullUp=1 PullDown=2; OSPEEDR LowSpeed..
/// VeryHighSpeed = 0..3. `initial` stays `.unchanged`: the output latch keeps
/// its level, as before.
fn gpioConfig(comptime c: PinConfig) Gpio.Config {
    return .{
        .mode = switch (c.mode) {
            .input => .input,
            .output => .output,
            .alternate => |af| .{ .alternate = af },
            .analog => .analog,
        },
        .open_drain = switch (c.otype) {
            .PushPull => false,
            .OpenDrain => true,
        },
        .pull = switch (c.pull) {
            .Floating => .none,
            .PullUp => .up,
            .PullDown => .down,
            _ => @compileError("gpio: reserved PUPDR value"),
        },
        .speed = switch (c.speed) {
            .LowSpeed => .low,
            .MediumSpeed => .medium,
            .HighSpeed => .high,
            .VeryHighSpeed => .very_high,
        },
    };
}

/// GPIO Pin representation
/// Provides a compile-time interface for GPIO operations
pub const Pin = struct {
    pin: pin_name.Pin,
    config: PinConfig,

    /// Build the comptime pin used by the drivers from a `hal.Pin` value.
    pub fn from(comptime p: pin_name.Pin, comptime config: PinConfig) Pin {
        return .{ .pin = p, .config = config };
    }

    /// Configure the GPIO pin with its stored configuration
    /// Enables the GPIO port clock and applies all settings (`Gpio.init`:
    /// mode last, so e.g. an open-drain pin is never briefly push-pull).
    pub inline fn configure(comptime self: @This()) void {
        _ = Gpio.init(self.pin, comptime gpioConfig(self.config));
    }

    /// Write a value to the GPIO output data register
    /// Atomic via BSRR: no read-modify-write of ODR, so an ISR touching another
    /// pin of the same port can't be lost.
    pub inline fn write(comptime self: @This(), value: gpio_types.ODR) void {
        Gpio.handle(self.pin).write(value == .High);
    }

    /// Toggle the GPIO output state
    pub inline fn toggle(comptime self: @This()) void {
        Gpio.handle(self.pin).toggle();
    }

    /// Read the GPIO input data register
    pub inline fn read(comptime self: @This()) gpio_types.IDR {
        return if (Gpio.handle(self.pin).read()) .High else .Low;
    }
};

/// A pin plus its alternate function — the pin type every driver config uses.
pub const AfPin = struct {
    pin: pin_name.Pin,
    af: AlternateFunction,
};

/// Configure a set of pins as alternate function, push-pull, no pull, very high
/// speed — the common bus-peripheral pin setup (FMC, QUADSPI, SAI, ...). The
/// pin list is comptime so each `configure()` gets comptime-known port/number.
pub fn configureAlternates(comptime pins: []const AfPin) void {
    inline for (pins) |p| {
        const pin = comptime Pin.from(p.pin, .{
            .mode = .{ .alternate = p.af },
            .speed = .VeryHighSpeed,
        });
        pin.configure();
    }
}
