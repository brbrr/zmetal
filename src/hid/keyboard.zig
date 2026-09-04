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
//! var kbd: keyboard.Keyboard = undefined;
//! try kbd.init(i2c_dev.i2c_device());
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
const debounce = @import("debounce.zig");

const drivers = microzig.drivers;
const Keyboard_Matrix = drivers.input.KeyboardMatrix;
const Key = drivers.input.Key;

/// I2C Device interface type from microzig
pub const I2C_Device = drivers.base.I2C_Device;

const hal = microzig.hal;
const MCP23017 = mcp23017.MCP23017;

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

    // microzig's matrix type is kept only for its `Set`/`Key`/`index` helpers;
    // scanning goes through `PortMatrix` below, not its per-pin `scan()`.
    const Matrix = Keyboard_Matrix(.{
        .rows = ROWS,
        .columns = COLS,
    });

    pub const Set = Matrix.Set;

    const DebouncerType = debounce.Debouncer(PortMatrix, KEY_COUNT, ROWS, COLS);

    /// Port-batched matrix scanner.
    ///
    /// microzig's generic `Keyboard_Matrix.scan` drives/reads one pin at a
    /// time, and every MCP23017 pin op is a full I2C transaction — 72 per
    /// scan for 8×6 (48 of them redundant full-register row reads), ~7 ms.
    /// This scanner exploits the fixed layout (columns on Port A, rows on
    /// Port B): drive each column with a single `OLATA` write and read all 8
    /// rows in ONE `GPIOB` read → ~14 transactions/scan (~5× fewer, ~1.4 ms).
    const PortMatrix = struct {
        mcp: *MCP23017,

        pub fn scan(self: *PortMatrix) !Matrix.Set {
            var result = Matrix.Set{};
            for (COL_PINS, 0..) |col_pin, col| {
                // Drive the active column low, all others high (Port A).
                try self.mcp.writeRegister(.OLATA, ~(@as(u8, 1) << @intCast(col_pin)));
                settle();
                // A single read samples every row; a pressed key pulls its
                // (pulled-up) row low.
                const rows = try self.mcp.readPort(.B);
                for (ROW_PINS, 0..) |row_pin, row| {
                    const bit = @as(u8, 1) << @intCast(row_pin - 8);
                    if (rows & bit == 0) result.add(Key.new(@intCast(row), @intCast(col)));
                }
            }
            // Idle: release all columns high.
            try self.mcp.writeRegister(.OLATA, 0xFF);
            return result;
        }

        /// Let a driven column settle before sampling rows. The I2C read that
        /// follows already inserts >100 µs, so this only needs to be nominal.
        inline fn settle() void {
            for (0..50) |_| asm volatile ("" ::: .{ .memory = true });
        }
    };

    mcp: MCP23017,
    port_matrix: PortMatrix,
    debouncer: DebouncerType,

    events: EventQueue = .{},

    /// Initialize the keyboard in place.
    ///
    /// This must initialize through `self` (a stable, caller-owned address)
    /// rather than returning a value: the struct is self-referential
    /// (`port_matrix.mcp` -> `&self.mcp`, `debouncer.matrix` ->
    /// `&self.port_matrix`). Returning by value would copy the struct while
    /// leaving those internal pointers dangling at the init frame, faulting on
    /// the first process() call.
    pub fn init(self: *Self, i2c_dev: I2C_Device) !void {
        // Initialize MCP23017 with the interface
        self.mcp = try MCP23017.init(i2c_dev, MCP_I2C_ADDRESS);

        // Configure Port A as outputs (columns) - default HIGH
        try self.mcp.setPortMode(.A, 0x00);
        try self.mcp.writePort(.A, 0xFF);

        // Configure Port B as inputs with pull-ups (rows)
        try self.mcp.setPortMode(.B, 0xFF);
        try self.mcp.setPortPullups(.B, 0xFF);

        self.port_matrix = .{ .mcp = &self.mcp };
        self.debouncer = DebouncerType.init(&self.port_matrix);
    }

    /// Process keyboard matrix scan and update debounce state
    /// Returns a queue of key events (press/release)
    /// Call this function periodically (recommended: every 10ms)
    pub fn process(self: *Self) !*EventQueue {
        self.events.count = 0;
        try self.debouncer.process(&self.events);
        return &self.events;
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

/// Translate the debouncer's scan-order index (row-major, `row*COLS + col`) into
/// this keyboard's physical/logical key numbering — the WoopyOne column-major
/// layout `col*ROWS + row`, where logical keys 0..23 (Port-A columns 0..2) are
/// the note keys and columns 3..5 are non-note keys.
pub fn logicalKey(scan_idx: u8) u8 {
    const row = scan_idx / COLS; // 0..ROWS-1  (Port B row pin)
    const col = scan_idx % COLS; // 0..COLS-1  (Port A col pin)
    return col * ROWS + row;
}
