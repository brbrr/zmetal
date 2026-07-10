//! Keyboard Module for ZMetal
//!
//! Implements an 8×6 keyboard matrix (48 keys) using MCP23017 I2C GPIO expander.
//! Provides debounced key events and state queries.
//!
//! Hardware configuration:
//! - MCP23017 at I2C address 0x21, 400 kHz
//! - Port A (pins 0-5): Column drivers (outputs)
//! - Port B (pins 8-15): Row sensors (inputs with pull-ups)
//!
//! Usage:
//! ```zig
//! var i2c_dev = try hal.i2c.I2C_Device.init(.I2C1, .{});
//! i2c_dev.apply();
//! var kbd = try keyboard.Keyboard.init(i2c_dev.i2c_device());
//!
//! while (true) {
//!     const events = try kbd.process();
//!     for (events.slice()) |evt| {
//!         // Handle key event
//!     }
//!     hal.clock.delay_ms(10);
//! }
//! ```

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");
const mcp_digital_io = @import("mcp_digital_io.zig");
const debounce = @import("debounce.zig");

const drivers = microzig.drivers;
const Keyboard_Matrix = drivers.input.KeyboardMatrix;
const Key = drivers.input.Key;
const Digital_IO = drivers.base.Digital_IO;

/// I2C Device interface type from microzig
pub const I2C_Device = drivers.base.I2C_Device;

const hal = microzig.hal;
const MCP23017 = mcp23017.MCP23017;
const McpPin = mcp_digital_io.McpPin;

/// Matrix configuration
pub const ROWS = 8;
pub const COLS = 6;
pub const KEY_COUNT = ROWS * COLS; // 48 keys

/// Column pins: Port A pins 0-5
const COL_PINS = [COLS]u8{ 0, 1, 2, 3, 4, 5 };

/// Row pins: Port B pins 8-15
const ROW_PINS = [ROWS]u8{ 8, 9, 10, 11, 12, 13, 14, 15 };

pub const KeyEvent = debounce.KeyEvent;
pub const KeyEventData = debounce.KeyEventData;
pub const EventQueue = debounce.EventQueue;

/// MCP23017 I2C configuration
const MCP_I2C_ADDRESS: u8 = 0x21;

pub const Keyboard = struct {
    const Self = @This();

    const Matrix = Keyboard_Matrix(.{
        .rows = ROWS,
        .columns = COLS,
    });

    pub const Set = Matrix.Set;

    const DebouncerType = debounce.Debouncer(Matrix, KEY_COUNT, ROWS, COLS);

    mcp: MCP23017,

    // Matrix fields - directly embedded, no wrapper
    col_pins: [COLS]McpPin,
    row_pins: [ROWS]McpPin,
    col_ios: [COLS]Digital_IO,
    row_ios: [ROWS]Digital_IO,
    matrix: Matrix,

    debouncer: DebouncerType,

    /// Initialize the keyboard
    pub fn init(i2c_dev: I2C_Device) !Self {
        // Create keyboard struct
        var self = Self{
            .mcp = undefined,
            .col_pins = undefined,
            .row_pins = undefined,
            .col_ios = undefined,
            .row_ios = undefined,
            .matrix = undefined,
            .debouncer = undefined,
        };

        // Initialize MCP23017 with the interface
        self.mcp = try MCP23017.init(i2c_dev, MCP_I2C_ADDRESS);

        // Configure Port A as outputs (columns) - default HIGH
        try self.mcp.setPortMode(.A, 0x00);
        try self.mcp.writePort(.A, 0xFF);

        // Configure Port B as inputs with pull-ups (rows)
        try self.mcp.setPortMode(.B, 0xFF);
        try self.mcp.setPortPullups(.B, 0xFF);

        // Initialize McpPin instances
        for (COL_PINS, 0..) |pin, i| {
            self.col_pins[i] = McpPin.init(&self.mcp, pin);
        }

        for (ROW_PINS, 0..) |pin, i| {
            self.row_pins[i] = McpPin.init(&self.mcp, pin);
        }

        // Create Digital_IO interfaces pointing to pins
        for (0..COLS) |i| {
            self.col_ios[i] = self.col_pins[i].digital_io();
        }

        for (0..ROWS) |i| {
            self.row_ios[i] = self.row_pins[i].digital_io();
        }

        // Create matrix with embedded Digital_IO arrays
        self.matrix = Matrix{
            .cols = self.col_ios,
            .rows = self.row_ios,
        };

        // Initialize debouncer with pointer to matrix
        self.debouncer = DebouncerType.init(&self.matrix);

        return self;
    }

    /// Process keyboard matrix scan and update debounce state
    /// Returns a queue of key events (press/release)
    /// Call this function periodically (recommended: every 10ms)
    pub fn process(self: *Self) !EventQueue {
        return try self.debouncer.process();
    }

    /// Check if a specific key is currently pressed (0-47)
    pub fn isPressed(self: *const Self, key_id: u8) bool {
        return self.debouncer.isPressed(key_id);
    }

    /// Get the key index from row and column
    pub fn keyIndex(row: u8, col: u8) usize {
        return Matrix.index(Key.new(row, col));
    }
};
