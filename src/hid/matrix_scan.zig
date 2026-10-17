//! The column-by-row scan of a key matrix on a port-pair expander, std
//! only so the host tests it. `Io` drives the columns and senses the rows:
//!
//! - `drive(io, columns: u8) !void`: a 0 bit drives that column low.
//! - `sense(io) !u8`: the row inputs; a pressed key pulls its row low.
//! - `settle(io) void`: the wait between a drive and a sense.
//!
//! Each bus transfer is slow (about 70-100 µs at 400 kHz) and the scan
//! runs every few milliseconds. So between scans every column stays
//! driven low, and a scan starts with one row read: with no key down no
//! row is low, and that read is the whole scan. Only a low row costs the
//! column-by-column scan, after which the columns go low again.

const std = @import("std");

pub fn Scanner(comptime Io: type, comptime rows: usize, comptime cols: usize) type {
    comptime if (rows == 0 or rows > 8 or cols == 0 or cols > 8) @compileError("rows/cols must be 1..8");
    const row_mask: u8 = @intCast((@as(u16, 1) << rows) - 1);

    return struct {
        const Self = @This();

        io: Io,
        /// True while every column is driven low. False at start and
        /// after a failed transfer, which leaves the columns unknown.
        idle_low: bool = false,

        /// The pressed keys, bit `row * cols + col`.
        pub fn scan(self: *Self) !u64 {
            errdefer self.idle_low = false;
            if (!self.idle_low) {
                try self.io.drive(0x00);
                self.io.settle();
                self.idle_low = true;
            }
            if (try self.io.sense() & row_mask == row_mask) return 0;

            self.idle_low = false;
            var result: u64 = 0;
            for (0..cols) |col| {
                try self.io.drive(~(@as(u8, 1) << @intCast(col)));
                self.io.settle();
                const sensed = try self.io.sense();
                for (0..rows) |row| {
                    if (sensed & (@as(u8, 1) << @intCast(row)) == 0) result |= @as(u64, 1) << @intCast(row * cols + col);
                }
            }
            try self.io.drive(0x00);
            self.idle_low = true;
            return result;
        }
    };
}

// ============================================================================

const testing = std.testing;

/// A matrix of switches: a pressed key joins its row to its column, so a
/// row reads low when any column it joins is driven low.
const FakeIo = struct {
    pressed: u64 = 0,
    driven: u8 = 0xFF,
    drives: usize = 0,
    senses: usize = 0,
    fail_next_sense: bool = false,

    const R = 8;
    const C = 6;

    fn drive(self: *FakeIo, columns: u8) !void {
        self.driven = columns;
        self.drives += 1;
    }

    fn sense(self: *FakeIo) !u8 {
        self.senses += 1;
        if (self.fail_next_sense) {
            self.fail_next_sense = false;
            return error.I2CError;
        }
        var v: u8 = 0xFF;
        for (0..R) |row| for (0..C) |col| {
            const down = self.pressed & (@as(u64, 1) << @intCast(row * C + col)) != 0;
            const col_low = self.driven & (@as(u8, 1) << @intCast(col)) == 0;
            if (down and col_low) v &= ~(@as(u8, 1) << @intCast(row));
        };
        return v;
    }

    fn settle(_: *FakeIo) void {}

    fn transfers(self: *const FakeIo) usize {
        return self.drives + self.senses;
    }
};

const TestScanner = Scanner(*FakeIo, FakeIo.R, FakeIo.C);

fn key(row: usize, col: usize) u64 {
    return @as(u64, 1) << @intCast(row * FakeIo.C + col);
}

test "with no key down a scan is one row read, after the first one drives the columns low" {
    var io = FakeIo{};
    var s = TestScanner{ .io = &io };
    try testing.expectEqual(@as(u64, 0), try s.scan());
    try testing.expectEqual(@as(usize, 2), io.transfers());
    try testing.expectEqual(@as(u64, 0), try s.scan());
    try testing.expectEqual(@as(usize, 3), io.transfers());
}

test "a key down costs the full scan and names its row and column, then idle is one read again" {
    var io = FakeIo{};
    var s = TestScanner{ .io = &io };
    _ = try s.scan();
    io.pressed = key(5, 3);
    const before = io.transfers();
    try testing.expectEqual(key(5, 3), try s.scan());
    // One read, a drive and a read per column, and the drive back to idle.
    try testing.expectEqual(before + 1 + 2 * FakeIo.C + 1, io.transfers());
    try testing.expectEqual(@as(u8, 0x00), io.driven);

    io.pressed = 0;
    const after = io.transfers();
    try testing.expectEqual(@as(u64, 0), try s.scan());
    try testing.expectEqual(after + 1, io.transfers());
}

test "the scan gives the same keys as a column-by-column scan, for many key sets" {
    var prng = std.Random.DefaultPrng.init(7);
    const r = prng.random();
    var io = FakeIo{};
    var s = TestScanner{ .io = &io };
    for (0..200) |_| {
        // At most two keys, which a diode-less matrix reads without ghosts.
        io.pressed = 0;
        for (0..r.uintLessThan(usize, 3)) |_| io.pressed |= key(r.uintLessThan(usize, FakeIo.R), r.uintLessThan(usize, FakeIo.C));
        try testing.expectEqual(io.pressed, try s.scan());
    }
}

test "a failed read leaves the columns unknown, so the next scan drives them low first" {
    var io = FakeIo{};
    var s = TestScanner{ .io = &io };
    _ = try s.scan();
    io.pressed = key(0, 0);
    io.fail_next_sense = true;
    try testing.expectError(error.I2CError, s.scan());
    try testing.expect(!s.idle_low);
    io.driven = 0xFF; // what a half-done column scan could leave
    io.pressed = 0;
    const before = io.drives;
    try testing.expectEqual(@as(u64, 0), try s.scan());
    try testing.expectEqual(before + 1, io.drives);
}
