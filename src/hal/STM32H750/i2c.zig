//! I2C peripheral driver for STM32H750
//!
//! This module provides a zero-cost abstraction over microzig's I2C_Device for STM32H750.
//! It wraps microzig's i2c_v2 implementation with Daisy-specific configuration and
//! provides a comptime-based API for type-safe I2C communication.
//!
//! Features:
//! - Zero-cost abstractions using comptime
//! - Compatible with microzig's I2C_Device framework
//! - Blocking read/write operations
//! - Configurable speed (100kHz, 400kHz, 1MHz)
//! - Support for all 4 I2C peripherals (I2C1-4)
//!
//! Example usage:
//! ```zig
//! // Initialize I2C1 at comptime
//! var i2c1_dev = try hal.i2c.I2C_Device.init(.I2C1, .{
//!     .speed = .I2C_400KHZ,
//! });
//! i2c1_dev.apply();
//!
//! // Get the I2C_Device interface for use with drivers
//! const i2c_dev = i2c1_dev.i2c_device();
//!
//! // Use with any microzig driver that accepts I2C_Device
//! const sensor = try AHT30.init(i2c_dev, @enumFromInt(0x38));
//! ```

const std = @import("std");
const microzig = @import("microzig");
const chip = microzig.chip;
const drivers = microzig.drivers;

// Import STM32 common I2C implementation
const stm32_common = @import("stm32_common");
const i2c_v2 = stm32_common.i2c_v2;
const enums = stm32_common.enums;

// Import HAL modules
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const pins = @import("pins.zig");

/// Re-export I2C_Device types from microzig
pub const Address = drivers.base.I2C_Device.Address;
pub const Error = drivers.base.I2C_Device.Error;
pub const InterfaceError = drivers.base.I2C_Device.InterfaceError;

/// I2C peripheral selection
pub const Peripheral = enum {
    I2C1,
    I2C2,
    I2C3,
    I2C4,

    fn to_i2c_type(self: Peripheral) enums.I2C_Type {
        return switch (self) {
            .I2C1 => .I2C1,
            .I2C2 => .I2C2,
            .I2C3 => .I2C3,
            .I2C4 => .I2C4,
        };
    }

    fn to_rcc_peripheral(self: Peripheral) rcc.RccPeriferals {
        return switch (self) {
            .I2C1 => .I2C1,
            .I2C2 => .I2C2,
            .I2C3 => .I2C3,
            .I2C4 => .I2C4,
        };
    }
};

/// I2C clock speed configuration
pub const Speed = enum {
    /// Standard mode: 100 kHz
    I2C_100KHZ,
    /// Fast mode: 400 kHz
    I2C_400KHZ,
    /// Fast mode plus: ~886 kHz (approximates 1 MHz)
    I2C_1MHZ,
};

/// I2C configuration structure
pub const Config = struct {
    /// Clock speed selection (default: 400 kHz)
    speed: Speed = .I2C_400KHZ,
    
    /// Pin configuration (optional - use default Daisy Seed pins if not specified)
    /// If provided, these pins will be configured automatically
    pin_config: ?PinConfig = null,
};

/// Pin configuration for I2C
pub const PinConfig = struct {
    scl: struct { port: []const u8, pin: []const u8, af: u8 },
    sda: struct { port: []const u8, pin: []const u8, af: u8 },
};

/// Default pin configurations for Daisy Seed board
pub const daisy_pin_configs = struct {
    /// I2C1: PB8 (SCL), PB9 (SDA) - AF4
    pub const I2C1 = PinConfig{
        .scl = .{ .port = "B", .pin = "8", .af = 4 },
        .sda = .{ .port = "B", .pin = "9", .af = 4 },
    };
    
    /// I2C2: PB10 (SCL), PB11 (SDA) - AF4
    pub const I2C2 = PinConfig{
        .scl = .{ .port = "B", .pin = "10", .af = 4 },
        .sda = .{ .port = "B", .pin = "11", .af = 4 },
    };
    
    /// I2C3: PA8 (SCL), PC9 (SDA) - AF4
    pub const I2C3 = PinConfig{
        .scl = .{ .port = "A", .pin = "8", .af = 4 },
        .sda = .{ .port = "C", .pin = "9", .af = 4 },
    };
    
    /// I2C4: PD12 (SCL), PD13 (SDA) - AF4
    pub const I2C4 = PinConfig{
        .scl = .{ .port = "D", .pin = "12", .af = 4 },
        .sda = .{ .port = "D", .pin = "13", .af = 4 },
    };
};

/// I2C Device wrapper that provides zero-cost abstraction over microzig's I2C_Device
pub const I2C_Device = struct {
    inner: i2c_v2.I2C_Device,
    
    /// Initialize an I2C peripheral with the given configuration
    /// This should be called at comptime or at startup to compute timing parameters
    ///
    /// Note: After init(), call apply() to enable the peripheral
    pub fn init(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device {
        const i2c_type = peripheral.to_i2c_type();
        
        // Initialize the underlying microzig I2C device
        // This computes timing registers based on the clock configuration
        const inner = try i2c_v2.I2C_Device.init(i2c_type);
        
        // Configure pins if specified, otherwise use defaults
        const pin_cfg = config.pin_config orelse switch (peripheral) {
            .I2C1 => daisy_pin_configs.I2C1,
            .I2C2 => daisy_pin_configs.I2C2,
            .I2C3 => daisy_pin_configs.I2C3,
            .I2C4 => daisy_pin_configs.I2C4,
        };
        
        // Configure GPIO pins for I2C function
        configure_pins(pin_cfg);
        
        return I2C_Device{ .inner = inner };
    }
    
    /// Apply the configuration and enable the I2C peripheral
    /// Must be called after init() and before using the device
    pub fn apply(self: *const I2C_Device) void {
        self.inner.apply();
    }
    
    /// Get the I2C_Device interface for use with microzig drivers
    /// This returns a drivers.base.I2C_Device with vtable for runtime dispatch
    pub fn i2c_device(self: *I2C_Device) drivers.base.I2C_Device {
        return self.inner.i2c_device();
    }
    
    /// Write data to an I2C device (blocking)
    pub fn write(self: *I2C_Device, address: Address, data: []const u8) Error!void {
        const dev = self.i2c_device();
        return dev.write(address, data);
    }
    
    /// Write multiple chunks to an I2C device (blocking)
    pub fn writev(self: *I2C_Device, address: Address, chunks: []const []const u8) Error!void {
        const dev = self.i2c_device();
        return dev.writev(address, chunks);
    }
    
    /// Read data from an I2C device (blocking)
    pub fn read(self: *I2C_Device, address: Address, buffer: []u8) Error!usize {
        const dev = self.i2c_device();
        return dev.read(address, buffer);
    }
    
    /// Read multiple chunks from an I2C device (blocking)
    pub fn readv(self: *I2C_Device, address: Address, buffers: []const []u8) Error!usize {
        const dev = self.i2c_device();
        return dev.readv(address, buffers);
    }
    
    /// Write then read from an I2C device (blocking, with repeated start)
    /// This is useful for reading registers: write register address, then read value
    pub fn write_then_read(
        self: *I2C_Device,
        address: Address,
        write_data: []const u8,
        read_buffer: []u8,
    ) Error!void {
        const dev = self.i2c_device();
        return dev.write_then_read(address, write_data, read_buffer);
    }
    
    /// Write multiple chunks then read multiple chunks (blocking, with repeated start)
    pub fn writev_then_readv(
        self: *I2C_Device,
        address: Address,
        write_chunks: []const []const u8,
        read_chunks: []const []u8,
    ) Error!void {
        const dev = self.i2c_device();
        return dev.writev_then_readv(address, write_chunks, read_chunks);
    }
    
    /// Read from a specific register address (convenience function)
    /// Equivalent to write_then_read with a single-byte register address
    pub fn read_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        buffer: []u8,
    ) Error!void {
        const reg_bytes = [_]u8{register_addr};
        return self.write_then_read(device_addr, &reg_bytes, buffer);
    }
    
    /// Write to a specific register address (convenience function)
    /// Sends register address followed by data bytes
    pub fn write_register(
        self: *I2C_Device,
        device_addr: Address,
        register_addr: u8,
        data: []const u8,
    ) Error!void {
        const reg_bytes = [_]u8{register_addr};
        return self.writev(device_addr, &.{ &reg_bytes, data });
    }
};

/// Configure GPIO pins for I2C function
fn configure_pins(comptime pin_cfg: PinConfig) void {
    // Configure SCL pin
    const scl_pin = gpio.Pin.init(pin_cfg.scl.port, pin_cfg.scl.pin, .{
        .mode = .AlternateFunction,
        .output_type = .OpenDrain,
        .speed = .VeryHigh,
        .pull = .Up,
        .alternate_function = pin_cfg.scl.af,
    });
    scl_pin.configure();
    
    // Configure SDA pin
    const sda_pin = gpio.Pin.init(pin_cfg.sda.port, pin_cfg.sda.pin, .{
        .mode = .AlternateFunction,
        .output_type = .OpenDrain,
        .speed = .VeryHigh,
        .pull = .Up,
        .alternate_function = pin_cfg.sda.af,
    });
    sda_pin.configure();
}

/// Helper to create an I2C device at comptime with error handling
/// Usage: `const i2c = try hal.i2c.create(.I2C1, .{});`
pub fn create(comptime peripheral: Peripheral, comptime config: Config) !I2C_Device {
    return I2C_Device.init(peripheral, config);
}
