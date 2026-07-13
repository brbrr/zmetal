//! GPIO (General Purpose I/O) driver for STM32H750
//! Follows microzig common gpio_v2 patterns for STM32 GPIO peripherals

const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

// STM32H7 uses GPIO v2 peripheral types
const gpio_types = microzig.chip.types.peripherals.gpio_v2;

const stm32_common = @import("stm32_common");
const stm32_gpio = stm32_common.gpio_v2;

pub const Port = stm32_gpio.Port;

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

    pub fn default() PinConfig {
        return .{};
    }
};

/// GPIO Pin representation
/// Provides a compile-time interface for GPIO operations
pub const Pin = struct {
    port_id: []const u8,
    number_str: []const u8,
    config: PinConfig,
    pin_num: u8,

    /// Initialize a GPIO pin with the given configuration
    pub fn init(
        port_id: []const u8,
        number_str: []const u8,
        config: PinConfig,
    ) Pin {
        const pin_num = std.fmt.parseInt(u8, number_str, 10) catch unreachable;
        return Pin{
            .port_id = port_id,
            .number_str = number_str,
            .pin_num = pin_num,
            .config = config,
        };
    }

    /// Configure the GPIO pin with its stored configuration
    /// Enables the GPIO port clock and applies all settings
    pub fn configure(comptime self: @This()) void {
        // Enable GPIO clock on AHB4 bus
        peripherals.RCC.AHB4ENR.modify_one("GPIO" ++ self.port_id ++ "EN", 1);
        // STM32H7: after setting a peripheral's RCC clock-enable bit there is a
        // ~2 clock-cycle delay before its registers are accessible. ST's
        // __HAL_RCC_GPIOx_CLK_ENABLE() inserts a dummy readback of the ENR to
        // cover this. Without it, touching the GPIO too soon raises an AHB
        // bus fault (DECERR) — a timing race that only bites when code runs
        // fast enough (e.g. with D-cache enabled). Read back to force the delay.
        _ = peripherals.RCC.AHB4ENR.read();
        const port = @field(peripherals, "GPIO" ++ self.port_id);

        // Set mode (input/output/alternate/analog)
        port.MODER.modify_one("MODER[" ++ self.number_str ++ "]", self.config.mode.to_moder());

        // Configure alternate function if in alternate mode.
        // microzig groups AFRL/AFRH into an AFR[2] array; each holds fields
        // AFR[0..7], so the pin's field index is pin_num % 8.
        if (self.config.mode == .alternate) {
            const afr_field = std.fmt.comptimePrint("AFR[{d}]", .{self.pin_num % 8});
            port.AFR[self.pin_num / 8].modify_one(afr_field, self.config.mode.alternate.get());
        }

        // Set output type (push-pull or open-drain)
        port.OTYPER.modify_one("OT[" ++ self.number_str ++ "]", self.config.otype);

        // Set pull-up/pull-down resistor configuration
        port.PUPDR.modify_one("PUPDR[" ++ self.number_str ++ "]", self.config.pull);

        // Set output speed
        port.OSPEEDR.modify_one("OSPEEDR[" ++ self.number_str ++ "]", self.config.speed);
    }

    /// Write a value to the GPIO output data register
    pub fn write(comptime self: @This(), value: gpio_types.ODR) void {
        @field(peripherals, "GPIO" ++ self.port_id).ODR.modify_one("ODR[" ++ self.number_str ++ "]", value);
    }

    /// Toggle the GPIO output state
    pub fn toggle(comptime self: @This()) void {
        @field(peripherals, "GPIO" ++ self.port_id).ODR.toggle_one("ODR[" ++ self.number_str ++ "]", .High);
    }

    /// Read the GPIO input data register
    pub fn read(comptime self: @This()) gpio_types.IDR {
        const reg = @field(peripherals, "GPIO" ++ self.port_id).IDR.read();
        return @field(reg, "IDR[" ++ self.number_str ++ "]");
    }
};

/// One pin's alternate-function assignment, for bulk configuration.
pub const AltPin = struct {
    port: []const u8,
    num: []const u8,
    af: AlternateFunction,
};

/// Configure a set of pins as alternate function, push-pull, no pull, very high
/// speed — the common bus-peripheral pin setup (FMC, QUADSPI, SAI, ...). The
/// pin list is comptime so each `configure()` gets comptime-known port/number.
pub fn configureAlternates(comptime pins: []const AltPin) void {
    @setEvalBranchQuota(10_000); // comptime Pin.init parses each pin number
    inline for (pins) |p| {
        const pin = comptime Pin.init(p.port, p.num, .{
            .mode = .{ .alternate = p.af },
            .speed = .VeryHighSpeed,
        });
        pin.configure();
    }
}

/// Output GPIO wrapper for easy pin manipulation
pub fn OutputGPIO(comptime pin: Pin) type {
    return struct {
        pub fn configure() void {
            pin.configure();
        }

        pub fn toggle() void {
            pin.toggle();
        }

        pub fn set() void {
            pin.write(.High);
        }

        pub fn clear() void {
            pin.write(.Low);
        }
    };
}
