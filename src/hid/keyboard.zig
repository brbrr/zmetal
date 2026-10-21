//! Key matrix on an MCP23017 I2C GPIO expander, with debounced key events.
//!
//! Wiring (fixed, so a scan is one write + one read per column, and one
//! read in all while no key is down):
//! - Port A pins 0..cols-1: column drivers (outputs, driven low one at a time)
//! - Port B pins 0..rows-1 (expander pins 8..): row sensors (inputs, pull-ups)
//!
//! Usage:
//! ```zig
//! const Keyboard = zmetal.hid.keyboard.McpMatrixKeyboard(.{ .address = 0x21, .rows = 8, .cols = 6 });
//! var kbd: Keyboard = undefined; // must not move after init
//! try kbd.init(i2c.i2c_device());
//! // every ~10 ms:
//! const events = try kbd.process();
//! for (events.slice()) |evt| { ... } // evt.key = row * cols + col
//! ```

const std = @import("std");
const microzig = @import("microzig");
const mcp23017 = @import("../drivers/mcp23017.zig");
const debounce = @import("debounce.zig");
const matrix_scan = @import("matrix_scan.zig");

const drivers = microzig.drivers;
const Keyboard_Matrix = drivers.input.KeyboardMatrix;
const Key = drivers.input.Key;

/// I2C Device interface type from microzig
pub const I2C_Device = drivers.base.I2C_Device;

const hal = microzig.hal;
const MCP23017 = mcp23017.MCP23017;

pub const MatrixConfig = struct {
    /// 7-bit I2C address of the expander.
    address: u7,
    /// Rows on Port B pins 0..rows-1 (max 8).
    rows: u4,
    /// Columns on Port A pins 0..cols-1 (max 8).
    cols: u4,
};

/// A `check` result: what the chip held, and whether it was set up again.
pub const Check = struct { readback: mcp23017.Readback, repaired: bool };

pub const KeyEvent = debounce.KeyEvent;
pub const KeyEventData = debounce.KeyEventData;
pub const EventQueue = debounce.EventQueue;

pub fn McpMatrixKeyboard(comptime cfg: MatrixConfig) type {
    comptime if (cfg.rows == 0 or cfg.rows > 8 or cfg.cols == 0 or cfg.cols > 8) @compileError("rows/cols must be 1..8");
    const ROWS: usize = cfg.rows;
    const COLS: usize = cfg.cols;
    const KEY_COUNT = ROWS * COLS;

    return struct {
        const Self = @This();

        pub const row_count = ROWS;
        pub const col_count = COLS;
        pub const key_count = KEY_COUNT;

        // microzig's matrix type is kept only for its `Set`/`Key`/`index` helpers;
        // scanning goes through `PortMatrix` below, not its per-pin `scan()`.
        const Matrix = Keyboard_Matrix(.{
            .rows = ROWS,
            .columns = COLS,
        });

        pub const Set = Matrix.Set;

        const DebouncerType = debounce.Debouncer(PortMatrix, KEY_COUNT, ROWS, COLS);

        /// The expander's ports as the scanner's I/O: columns on Port A,
        /// rows on Port B.
        const PortIo = struct {
            mcp: *MCP23017,

            pub fn drive(self: PortIo, columns: u8) !void {
                try self.mcp.writeRegister(.OLATA, columns);
            }

            pub fn sense(self: PortIo) !u8 {
                return self.mcp.readPort(.B);
            }

            /// Let a driven column settle before sampling rows. The I2C read
            /// that follows already takes tens of µs, so this is nominal.
            pub fn settle(_: PortIo) void {
                for (0..50) |_| asm volatile ("" ::: .{ .memory = true });
            }
        };

        /// Port-batched matrix scanner (see `matrix_scan.zig`). microzig's
        /// generic `Keyboard_Matrix.scan` does one I2C transaction per pin,
        /// 72 per scan for 8x6. A column-by-column scan takes 13; with no
        /// key down, one row read is the whole scan.
        const PortMatrix = struct {
            scanner: matrix_scan.Scanner(PortIo, ROWS, COLS),

            pub fn scan(self: *PortMatrix) !Matrix.Set {
                const bits = try self.scanner.scan();
                var result = Matrix.Set{};
                if (bits == 0) return result;
                for (0..ROWS) |row| for (0..COLS) |col| {
                    if (bits & (@as(u64, 1) << @intCast(row * COLS + col)) != 0) result.add(Key.new(@intCast(row), @intCast(col)));
                };
                return result;
            }
        };

        /// Port A (columns): outputs, idle high. Port B (rows): inputs
        /// with pull-ups.
        pub const setup: mcp23017.Setup = .{ .iodir = .{ 0x00, 0xFF }, .gppu = .{ 0xFF, 0xFF }, .olat = .{ 0xFF, 0x00 } };

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
            self.mcp = try MCP23017.initWith(i2c_dev, cfg.address, setup);
            self.port_matrix = .{ .scanner = .{ .io = .{ .mcp = &self.mcp } } };
            self.debouncer = DebouncerType.init(&self.port_matrix);
        }

        /// Reads the expander's configuration back and, if the chip lost
        /// it, writes it again. The chip keeps its registers through a
        /// reset of the MCU, so a bad value stays until a power cycle
        /// unless something writes it again. Call it every second or so,
        /// between scans.
        pub fn check(self: *Self) mcp23017.Error!Check {
            const rb = try self.mcp.readback();
            if (rb.matches(setup)) return .{ .readback = rb, .repaired = false };
            try self.mcp.configure(setup);
            // The columns are at their set-up level now, not low.
            self.port_matrix.scanner.idle_low = false;
            return .{ .readback = rb, .repaired = true };
        }

        /// Process keyboard matrix scan and update debounce state
        /// Returns a queue of key events (press/release)
        /// Call this function periodically (recommended: every 10ms)
        pub fn process(self: *Self) !*EventQueue {
            self.events.count = 0;
            try self.debouncer.process(&self.events);
            return &self.events;
        }

        /// Check if a key (row * cols + col) is currently pressed
        pub fn isPressed(self: *const Self, key_id: u8) bool {
            return self.debouncer.isPressed(key_id);
        }

        /// Get the key index from row and column
        pub fn keyIndex(row: u8, col: u8) usize {
            return Matrix.index(Key.new(row, col));
        }
    };
}
