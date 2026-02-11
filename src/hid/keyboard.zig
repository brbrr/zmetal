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
//! var keyboard = try Keyboard.init(i2c_device);
//! while (true) {
//!     const events = try keyboard.process();
//!     for (events.constSlice()) |evt| {
//!         // Handle key event
//!     }
//!     hal.clock.delay_ms(10);
//! }
//! ```

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");
const matrix_scanner = @import("matrix_scanner.zig");
const debounce = @import("debounce.zig");

const hal = microzig.hal;
const MCP23017 = mcp23017.MCP23017;
const MatrixScanner = matrix_scanner.MatrixScanner;
const Debouncer = debounce.Debouncer;

pub const KEY_COUNT = matrix_scanner.KEY_COUNT;
pub const ROWS = matrix_scanner.ROWS;
pub const COLS = matrix_scanner.COLS;
pub const KeyEvent = debounce.KeyEvent;
pub const KeyEventData = debounce.KeyEventData;
pub const EventQueue = debounce.EventQueue;

/// MCP23017 I2C configuration
const MCP_I2C_ADDRESS: u8 = 0x21;
const MCP_I2C_SPEED = hal.i2c.I2C_Speed.I2C_400KHZ;

/// Main keyboard instance
pub const Keyboard = struct {
    mcp: MCP23017,
    scanner: MatrixScanner,
    debouncer: Debouncer,

    /// Initialize the keyboard
    /// Requires an initialized I2C device interface
    pub fn init(i2c_device: microzig.drivers.base.I2C_Device) !Keyboard {
        // Initialize MCP23017
        var mcp = try MCP23017.init(i2c_device, MCP_I2C_ADDRESS);

        // Configure Port A as outputs (columns) - default HIGH
        try mcp.setPortMode(.A, 0x00);
        try mcp.writePort(.A, 0xFF);

        // Configure Port B as inputs with pull-ups (rows)
        try mcp.setPortMode(.B, 0xFF);
        try mcp.setPortPullups(.B, 0xFF);

        // Initialize matrix scanner
        var scanner = try MatrixScanner.init(&mcp);

        // Initialize debouncer
        const debouncer_inst = Debouncer.init(&scanner);

        return Keyboard{
            .mcp = mcp,
            .scanner = scanner,
            .debouncer = debouncer_inst,
        };
    }

    /// Process keyboard matrix scan and update debounce state
    /// Returns a queue of key events (press/release)
    /// Call this function periodically (recommended: every 10ms)
    pub fn process(self: *Keyboard) !EventQueue {
        return try self.debouncer.process();
    }

    /// Check if a specific key is currently pressed (0-47)
    pub fn isPressed(self: *const Keyboard, key_id: u8) bool {
        return self.debouncer.isPressed(key_id);
    }

    /// Get the key index from row and column
    pub fn keyIndex(row: u8, col: u8) usize {
        return MatrixScanner.keyIndex(row, col);
    }
};
