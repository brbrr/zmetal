//! MCP23017 I2C 16-bit I/O Expander Driver
//!
//! This driver provides a Zig interface for the MCP23017 I2C GPIO expander chip.
//! The MCP23017 provides 16 GPIO pins organized as two 8-bit ports (A and B).
//!
//! Features:
//! - Port-level operations (read/write 8 bits at once)
//! - Pin-level operations (read/write individual pins)
//! - Configurable pull-up resistors
//! - Polarity inversion
//! - State caching for efficient output operations
//!
//! Example usage:
//! ```zig
//! var i2c1 = try hal.i2c.I2C_Device.init(.I2C1, .{ .speed = .I2C_400KHZ });
//! i2c1.apply();
//!
//! var mcp = try MCP23017.init(i2c1.i2c_device(), 0x20);
//! try mcp.setPortMode(.A, 0x00); // All outputs
//! try mcp.writePort(.A, 0xFF);   // All high
//! ```

const std = @import("std");
const microzig = @import("microzig");
const hal = microzig.hal;
const drivers = microzig.drivers;

/// I2C Device interface type from microzig
pub const I2C_Device = drivers.base.I2C_Device;

/// MCP23017 register addresses (IOCON.BANK=0 mode)
pub const Register = enum(u8) {
    IODIRA = 0x00, // I/O direction A (1=input, 0=output)
    IODIRB = 0x01, // I/O direction B
    IPOLA = 0x02, // Input polarity A (1=inverted)
    IPOLB = 0x03, // Input polarity B
    GPINTENA = 0x04, // Interrupt-on-change A
    GPINTENB = 0x05, // Interrupt-on-change B
    DEFVALA = 0x06, // Default compare for interrupt A
    DEFVALB = 0x07, // Default compare for interrupt B
    INTCONA = 0x08, // Interrupt control A
    INTCONB = 0x09, // Interrupt control B
    IOCON = 0x0A, // I/O expander configuration
    GPPUA = 0x0C, // Pull-up resistor A (1=enabled)
    GPPUB = 0x0D, // Pull-up resistor B
    INTFA = 0x0E, // Interrupt flag A (read-only)
    INTFB = 0x0F, // Interrupt flag B (read-only)
    INTCAPA = 0x10, // Interrupt captured value A (read-only)
    INTCAPB = 0x11, // Interrupt captured value B (read-only)
    GPIOA = 0x12, // Port A data
    GPIOB = 0x13, // Port B data
    OLATA = 0x14, // Output latch A
    OLATB = 0x15, // Output latch B
};

/// Port selection
pub const Port = enum(u8) {
    A = 0,
    B = 1,

    /// Get the offset for a given register and port
    pub fn registerOffset(self: Port, base_reg: Register) u8 {
        return @intFromEnum(base_reg) + @intFromEnum(self);
    }
};

/// Pin mode configuration
pub const PinMode = enum {
    Input,
    InputPullup,
    Output,
};

/// MCP23017 driver errors
pub const Error = error{
    I2CError,
    InvalidPin,
    InvalidPort,
};

/// MCP23017 driver instance
pub const MCP23017 = struct {
    i2c: I2C_Device,
    address: u8,
    pin_data: [2]u8, // Cached output state for ports A and B

    /// Initialize the MCP23017
    /// address: 7-bit I2C address (typically 0x20-0x27)
    pub fn init(i2c_dev: I2C_Device, address: u8) Error!MCP23017 {
        var self = MCP23017{
            .i2c = i2c_dev,
            .address = address,
            .pin_data = [_]u8{ 0, 0 },
        };

        // Configure IOCON: Sequential operation enabled, open-drain disabled
        try self.writeRegister(.IOCON, 0x20);

        // Enable all pull-ups by default (will only affect inputs)
        try self.writeRegister(.GPPUA, 0xFF);
        try self.writeRegister(.GPPUB, 0xFF);

        // Read initial GPIO state
        self.pin_data[0] = try self.readRegister(.GPIOA);
        self.pin_data[1] = try self.readRegister(.GPIOB);

        return self;
    }

    /// Write to a single register
    pub fn writeRegister(self: *const MCP23017, reg: Register, value: u8) Error!void {
        const data = [_]u8{ @intFromEnum(reg), value };
        const addr: I2C_Device.Address = @enumFromInt(self.address);
        self.i2c.write(addr, &data) catch return Error.I2CError;
    }

    /// Read from a single register
    pub fn readRegister(self: *const MCP23017, reg: Register) Error!u8 {
        const reg_addr = [_]u8{@intFromEnum(reg)};
        var value: [1]u8 = undefined;
        
        const addr: I2C_Device.Address = @enumFromInt(self.address);
        self.i2c.write_then_read(addr, &reg_addr, &value) catch return Error.I2CError;
        return value[0];
    }

    /// Write to both registers of a port pair atomically
    pub fn writeRegisterPair(self: *const MCP23017, base_reg: Register, port_a: u8, port_b: u8) Error!void {
        const data = [_]u8{ @intFromEnum(base_reg), port_a, port_b };
        const addr: I2C_Device.Address = @enumFromInt(self.address);
        self.i2c.write(addr, &data) catch return Error.I2CError;
    }

    /// Read from both registers of a port pair
    pub fn readRegisterPair(self: *const MCP23017, base_reg: Register) Error![2]u8 {
        const reg_addr = [_]u8{@intFromEnum(base_reg)};
        var values: [2]u8 = undefined;
        
        const addr: I2C_Device.Address = @enumFromInt(self.address);
        self.i2c.write_then_read(addr, &reg_addr, &values) catch return Error.I2CError;
        return values;
    }

    /// Set the I/O direction for an entire port
    /// dir: 0 = output, 1 = input (bitwise)
    pub fn setPortMode(self: *const MCP23017, port: Port, dir: u8) Error!void {
        const reg: Register = if (port == .A) .IODIRA else .IODIRB;
        try self.writeRegister(reg, dir);
    }

    /// Set the mode for a single pin (0-15)
    pub fn setPinMode(self: *const MCP23017, pin: u8, mode: PinMode) Error!void {
        if (pin >= 16) return Error.InvalidPin;

        const port: Port = if (pin < 8) .A else .B;
        const bit = pin % 8;
        const mask: u8 = @as(u8, 1) << @intCast(bit);

        // Configure direction
        const dir_reg: Register = if (port == .A) .IODIRA else .IODIRB;
        var dir = try self.readRegister(dir_reg);

        switch (mode) {
            .Output => {
                dir &= ~mask; // Clear bit for output
                try self.writeRegister(dir_reg, dir);
            },
            .Input, .InputPullup => {
                dir |= mask; // Set bit for input
                try self.writeRegister(dir_reg, dir);

                // Configure pull-up
                const pullup_reg: Register = if (port == .A) .GPPUA else .GPPUB;
                var pullup = try self.readRegister(pullup_reg);

                if (mode == .InputPullup) {
                    pullup |= mask;
                } else {
                    pullup &= ~mask;
                }
                try self.writeRegister(pullup_reg, pullup);
            },
        }
    }

    /// Write an 8-bit value to a port
    pub fn writePort(self: *MCP23017, port: Port, value: u8) Error!void {
        const port_idx = @intFromEnum(port);
        self.pin_data[port_idx] = value;

        const reg: Register = if (port == .A) .OLATA else .OLATB;
        try self.writeRegister(reg, value);
    }

    /// Read an 8-bit value from a port
    pub fn readPort(self: *const MCP23017, port: Port) Error!u8 {
        const reg: Register = if (port == .A) .GPIOA else .GPIOB;
        return try self.readRegister(reg);
    }

    /// Write to a single pin (0-15)
    pub fn writePin(self: *MCP23017, pin: u8, high: bool) Error!void {
        if (pin >= 16) return Error.InvalidPin;

        const port: Port = if (pin < 8) .A else .B;
        const port_idx = @intFromEnum(port);
        const bit = pin % 8;
        const mask: u8 = @as(u8, 1) << @intCast(bit);

        if (high) {
            self.pin_data[port_idx] |= mask;
        } else {
            self.pin_data[port_idx] &= ~mask;
        }

        const reg: Register = if (port == .A) .OLATA else .OLATB;
        try self.writeRegister(reg, self.pin_data[port_idx]);
    }

    /// Read a single pin (0-15)
    pub fn readPin(self: *const MCP23017, pin: u8) Error!bool {
        if (pin >= 16) return Error.InvalidPin;

        const port: Port = if (pin < 8) .A else .B;
        const bit = pin % 8;
        const mask: u8 = @as(u8, 1) << @intCast(bit);

        const value = try self.readPort(port);
        return (value & mask) != 0;
    }

    /// Read a specific bit from a port value (for cached reads)
    pub fn readBit(value: u8, bit: u8) bool {
        const mask: u8 = @as(u8, 1) << @intCast(bit);
        return (value & mask) != 0;
    }

    /// Toggle a pin
    pub fn togglePin(self: *MCP23017, pin: u8) Error!void {
        const current = try self.readPin(pin);
        try self.writePin(pin, !current);
    }

    /// Enable/disable pull-up for an entire port
    pub fn setPortPullups(self: *const MCP23017, port: Port, mask: u8) Error!void {
        const reg: Register = if (port == .A) .GPPUA else .GPPUB;
        try self.writeRegister(reg, mask);
    }

    /// Enable/disable pull-up for a single pin
    pub fn setPinPullup(self: *const MCP23017, pin: u8, enabled: bool) Error!void {
        if (pin >= 16) return Error.InvalidPin;

        const port: Port = if (pin < 8) .A else .B;
        const bit = pin % 8;
        const mask: u8 = @as(u8, 1) << @intCast(bit);

        const reg: Register = if (port == .A) .GPPUA else .GPPUB;
        var pullup = try self.readRegister(reg);

        if (enabled) {
            pullup |= mask;
        } else {
            pullup &= ~mask;
        }
        try self.writeRegister(reg, pullup);
    }

    /// Set polarity inversion for an entire port
    pub fn setPortPolarity(self: *const MCP23017, port: Port, mask: u8) Error!void {
        const reg: Register = if (port == .A) .IPOLA else .IPOLB;
        try self.writeRegister(reg, mask);
    }
};
