const std = @import("std");

const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;

const GPIO = microzig.chip.types.peripherals.GPIO;

pub const AlternateFunction = enum(u4) {
    af0,
    af1,
    af2,
    af3,
    af4,
    af5,
    af6,
    af7,
    af8,
    af9,
    af10,
    af11,
    af12,
    af13,
    af14,
    af15,

    pub fn get(self: @This()) u4 {
        return @intFromEnum(self);
    }
};

pub const Mode = union(enum) {
    /// Input mode (reset state)
    Input,
    /// General purpose output mode
    Output,
    /// Alternate function mode
    Alternate: AlternateFunction,
    /// Analog mode
    Analog,

    pub fn toModer(self: Mode) GPIO.MODER {
        return switch (self) {
            .Input => @enumFromInt(0),
            .Output => @enumFromInt(1),
            .Alternate => @enumFromInt(2),
            .Analog => @enumFromInt(3),
        };
    }
};

pub const PinConfig = struct {
    mode: Mode = .Output,
    otype: GPIO.OT = .PushPull,
    pull: GPIO.PUPDR = .Floating,
    speed: GPIO.OSPEEDR = .LowSpeed,

    pub fn default() PinConfig {
        return PinConfig{};
    }
};

pub const Pin = struct {
    port_id: []const u8,
    number_str: []const u8,
    config: PinConfig,
    pin_num: u8,

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

    pub fn configure(comptime self: @This()) void {
        // Enable GPIO clock
        peripherals.RCC.AHB4ENR.modify_one("GPIO" ++ self.port_id ++ "EN", 1);
        const port = @field(peripherals, "GPIO" ++ self.port_id);

        // Apply config
        port.MODER.modify_one("MODE" ++ self.number_str, self.config.mode.toModer());
        if (self.config.mode == .Alternate) {
            if (self.pin_num < 8) {
                port.AFRL.modify_one("AFSEL" ++ self.number_str, self.config.mode.Alternate.get());
            } else {
                port.AFRH.modify_one("AFSEL" ++ self.number_str, self.config.mode.Alternate.get());
            }
        }
        port.OTYPER.modify_one("OT" ++ self.number_str, self.config.otype);
        port.PUPDR.modify_one("PUPD" ++ self.number_str, self.config.pull);
        port.OSPEEDR.modify_one("OSPEED" ++ self.number_str, self.config.speed);
    }

    pub fn write(comptime self: @This(), value: GPIO.ODR) void {
        @field(peripherals, "GPIO" ++ self.port_id).ODR.modify_one("OD" ++ self.number_str, value);
    }

    pub fn toggle(comptime self: @This()) void {
        @field(peripherals, "GPIO" ++ self.port_id).ODR.toggle_one("OD" ++ self.number_str, .High);
    }

    pub fn read(comptime self: @This()) GPIO.IDR {
        const reg = @field(peripherals, "GPIO" ++ self.port_id).IDR.read();

        return @field(reg, "ID" ++ self.number_str);
    }
};
