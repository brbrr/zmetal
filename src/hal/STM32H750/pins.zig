//! Pin configuration system for STM32H750
//!
//! This module provides a compile-time pin configuration system that generates
//! type-safe pin structs based on a configuration structure.
//!
//! Example usage:
//! ```zig
//! const pins_config = pins.GlobalConfiguration{
//!     .GPIOC = .{
//!         .PC7 = .{ .name = "led", .mode = .{ .output = {} } },
//!     },
//! };
//! const my_pins = pins_config.apply();
//! my_pins.led.put(1); // Turn on LED
//! ```

const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;
const StructField = std.builtin.Type.StructField;

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

const gpio = @import("gpio.zig");

/// Pin configuration options
const PinConfiguration = struct {
    name: ?[:0]const u8 = null,
    mode: ?gpio.Mode = null,
};

/// Creates a GPIO pin type based on port, pin number, and mode
fn GPIO(comptime port: []const u8, comptime num: []const u8, comptime mode: gpio.Mode) type {
    if (mode == .input) @compileError("TODO: implement GPIO input mode");
    return switch (mode) {
        .input => struct {
            const pin = gpio.Pin.init(port, num, .{ .mode = mode });

            pub inline fn read(_: @This()) u1 {
                return pin.read();
            }
        },
        .output => struct {
            const pin = gpio.Pin.init(port, num, .{ .mode = mode });

            pub inline fn put(_: @This(), value: u1) void {
                const gpio_port = @field(peripherals, "GPIO" ++ port);
                if (value == 1) {
                    gpio_port.BSRR.write_raw(@as(u32, 1) << std.fmt.parseInt(u5, num, 10) catch unreachable);
                } else {
                    gpio_port.BSRR.write_raw(@as(u32, 1) << (16 + std.fmt.parseInt(u5, num, 10) catch unreachable));
                }
            }

            pub inline fn toggle(_: @This()) void {
                pin.toggle();
            }

            fn configure(_: @This(), pin_config: PinConfiguration) void {
                _ = pin_config;
                pin.configure();
            }
        },
        .alternate, .analog => @compileError("Alternate and analog modes not supported in pin abstraction yet"),
    };
}

/// Helper type for parsing STM32 pin names
/// Example: PinDescription("PE9").gpio_port_id = "E"
/// Example: PinDescription("PA12").gpio_pin_number_str = "12"
fn PinDescription(comptime spec: []const u8) type {
    const invalid_format_msg = "The given pin '" ++ spec ++ "' has an invalid format. Pins must follow the format \"P{Port}{Pin}\" scheme.";

    if (spec[0] != 'P')
        @compileError(invalid_format_msg);
    if (spec[1] < 'A' or spec[1] > 'K') // STM32H7 has ports A-K
        @compileError(invalid_format_msg);

    const gpio_pin_number_int: comptime_int = std.fmt.parseInt(u4, spec[2..], 10) catch @compileError(invalid_format_msg);
    return struct {
        const gpio_port_id = spec[1..2];
        const gpio_pin_number_str = std.fmt.comptimePrint("{d}", .{gpio_pin_number_int});
    };
}

/// Generates a struct type with fields for each configured pin
/// Based on the fields in `config`, returns a struct like:
/// ```zig
/// struct {
///     led: GPIO(...),
///     button: GPIO(...),
/// }
/// ```
pub fn Pins(comptime config: GlobalConfiguration) type {
    comptime {
        var fields: []const StructField = &.{};
        for (@typeInfo(GlobalConfiguration).@"struct".fields) |port_field| {
            if (@field(config, port_field.name)) |port_config| {
                for (@typeInfo(PortConfiguration()).@"struct".fields) |field| {
                    if (@field(port_config, field.name)) |pin_config| {
                        const D = PinDescription(field.name);
                        fields = fields ++ &[_]StructField{.{
                            .is_comptime = false,
                            .name = pin_config.name orelse field.name,
                            .type = GPIO(D.gpio_port_id, D.gpio_pin_number_str, pin_config.mode orelse .{ .input = .floating }),
                            .default_value_ptr = null,
                            .alignment = @alignOf(field.type),
                        }};
                    }
                }
            }
        }

        return @Type(.{
            .@"struct" = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &.{},
            },
        });
    }
}

/// Port configuration type generator
/// Returns a struct with optional pin configurations for a GPIO port:
/// ```zig
/// struct {
///     PA0: ?PinConfiguration = null,
///     PA1: ?PinConfiguration = null,
///     ...
///     PK15: ?PinConfiguration = null,
/// }
/// ```
fn PortConfiguration() type {
    @setEvalBranchQuota(200000);
    var fields: []const StructField = &.{};
    // STM32H7 has GPIO ports A through K
    for ("ABCDEFGHIJK") |gpio_port_id| {
        for (0..16) |gpio_pin_number_int| {
            fields = fields ++ &[_]StructField{.{
                .is_comptime = false,
                .name = std.fmt.comptimePrint("P{c}{d}", .{ gpio_port_id, gpio_pin_number_int }),
                .type = ?PinConfiguration,
                .default_value_ptr = &@as(?PinConfiguration, null),
                .alignment = @alignOf(?PinConfiguration),
            }};
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .is_tuple = false,
            .fields = fields,
            .decls = &.{},
        },
    });
}
/// Global pin configuration structure
/// Allows compile-time configuration of all GPIO ports
pub const GlobalConfiguration = struct {
    GPIOA: ?PortConfiguration() = null,
    GPIOB: ?PortConfiguration() = null,
    GPIOC: ?PortConfiguration() = null,
    GPIOD: ?PortConfiguration() = null,
    GPIOE: ?PortConfiguration() = null,
    GPIOF: ?PortConfiguration() = null,
    GPIOG: ?PortConfiguration() = null,
    GPIOH: ?PortConfiguration() = null,
    GPIOI: ?PortConfiguration() = null,
    GPIOJ: ?PortConfiguration() = null,
    GPIOK: ?PortConfiguration() = null,

    /// Apply the pin configuration and return a Pins struct
    /// Enables clocks and configures all specified pins
    pub fn apply(comptime config: @This()) Pins(config) {
        const pins: Pins(config) = undefined;

        inline for (@typeInfo(@This()).@"struct".fields) |port_field| {
            const gpio_port_name = port_field.name;
            if (@field(config, gpio_port_name)) |port_config| {
                peripherals.RCC.AHB4ENR.modify_one(gpio_port_name ++ "EN", 1);

                inline for (@typeInfo(PortConfiguration()).@"struct".fields) |pin_field| {
                    if (@field(port_config, pin_field.name)) |pin_config| {
                        @field(pins, pin_config.name.?).configure(pin_config);
                    }
                }
            }
        }

        return pins;
    }
};
