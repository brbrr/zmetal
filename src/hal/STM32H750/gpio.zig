const std = @import("std");

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

pub const Mode = union(enum) {
    input: InputMode,
    output: OutputMode,
};

pub const InputMode = enum(u2) {
    analog,
    floating,
    pull_up,
    pull_down,
};

pub const OutputMode = enum(u2) {
    push_pull,
    open_drain,
};

// TODO: Add the following
// pub const Speed = enum(u2) {
//     low,
//     medium,
//     high,
// };

pub const Pin = struct {
    port_id: []const u8,
    number_str: []const u8,

    pub fn init(port_id: []const u8, number_str: []const u8) Pin {
        return Pin{
            .port_id = port_id,
            .number_str = number_str,
        };
    }

    pub fn configure(comptime self: @This()) void {
        // Enable GPIO clock first
        peripherals.RCC.AHB4ENR.modify_one("GPIO" ++ self.port_id ++ "EN", 1);
        const port_peripheral = @field(peripherals, "GPIO" ++ self.port_id);
        // TODO: Support input
        port_peripheral.GPIO_MODER.modify_one("MODE" ++ self.number_str, .Output);
        // TODO: Support different modes, for input and for output
        port_peripheral.GPIO_OTYPER.modify_one("OT" ++ self.number_str, .PushPull);
        // TODO: Support different speeds
        port_peripheral.GPIO_OSPEEDR.modify_one("OSPEED" ++ self.number_str, .LowSpeed);
        // TODO: Support pull-up / pull-down
        port_peripheral.GPIO_PUPDR.modify_one("PUPD" ++ self.number_str, .Floating);
    }

    pub fn toggle(comptime self: @This()) void {
        @field(peripherals, "GPIO" ++ self.port_id).GPIO_ODR.toggle_one("OD" ++ self.number_str, .High);
    }
};
