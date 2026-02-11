//! Keyboard Matrix Scanner using microzig's Keyboard_Matrix driver
//!
//! Configured for 8 rows × 6 columns (48 keys) using MCP23017 I2C expander.
//! - Columns (0-5): Port A pins 0-5 (outputs)
//! - Rows (0-7): Port B pins 8-15 (inputs with pull-ups)

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");
const mcp_digital_io = @import("mcp_digital_io.zig");

const Keyboard_Matrix = microzig.drivers.input.Keyboard_Matrix;
const Key = microzig.drivers.input.Key;
const MCP23017 = mcp23017.MCP23017;
const McpPin = mcp_digital_io.McpPin;
const Digital_IO = microzig.drivers.base.Digital_IO;

/// Matrix configuration
pub const ROWS = 8;
pub const COLS = 6;
pub const KEY_COUNT = ROWS * COLS; // 48 keys

/// Column pins: Port A pins 0-5
const COL_PINS = [_]u8{ 0, 1, 2, 3, 4, 5 };

/// Row pins: Port B pins 8-15
const ROW_PINS = [_]u8{ 8, 9, 10, 11, 12, 13, 14, 15 };

/// Matrix scanner instance
pub const MatrixScanner = struct {
    mcp: *MCP23017,
    col_pins: [COLS]McpPin,
    row_pins: [ROWS]McpPin,
    matrix: Matrix,

    const Matrix = Keyboard_Matrix(.{
        .rows = ROWS,
        .columns = COLS,
    });

    pub const Set = Matrix.Set;

    pub fn init(mcp: *MCP23017) !MatrixScanner {
        // Create McpPin instances for columns and rows
        var col_pins: [COLS]McpPin = undefined;
        var row_pins: [ROWS]McpPin = undefined;

        for (COL_PINS, 0..) |pin, i| {
            col_pins[i] = McpPin.init(mcp, pin);
        }

        for (ROW_PINS, 0..) |pin, i| {
            row_pins[i] = McpPin.init(mcp, pin);
        }

        // Create Digital_IO array for matrix init
        var col_ios: [COLS]Digital_IO = undefined;
        var row_ios: [ROWS]Digital_IO = undefined;

        for (0..COLS) |i| {
            col_ios[i] = col_pins[i].digital_io();
        }

        for (0..ROWS) |i| {
            row_ios[i] = row_pins[i].digital_io();
        }

        // Initialize the keyboard matrix
        const matrix = try Matrix.init(col_ios, row_ios);

        return MatrixScanner{
            .mcp = mcp,
            .col_pins = col_pins,
            .row_pins = row_pins,
            .matrix = matrix,
        };
    }

    /// Scan the matrix and return a set of pressed keys
    pub fn scan(self: *MatrixScanner) !Set {
        return try self.matrix.scan();
    }

    /// Get the key index (0-47) from row and column
    pub fn keyIndex(row: u8, col: u8) usize {
        return Matrix.index(Key.new(row, col));
    }
};
