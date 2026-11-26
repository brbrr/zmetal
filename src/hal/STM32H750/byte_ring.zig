//! Lock-free single-producer single-consumer byte queue (pure, host-tested).
//! One side only pushes and the other only pops, e.g. an interrupt handler
//! and the main loop on one core. Each side stores only its own index:
//! the producer `head`, the consumer `tail`.
const std = @import("std");

/// A ring of `capacity` bytes (a power of two) that holds `capacity - 1`:
/// one slot stays empty so that `head == tail` means empty.
pub fn ByteRing(comptime capacity: usize) type {
    if (capacity == 0 or capacity & (capacity - 1) != 0)
        @compileError(std.fmt.comptimePrint("ByteRing capacity must be a power of two, got {d}", .{capacity}));

    return struct {
        const Self = @This();
        const mask = capacity - 1;

        buf: [capacity]u8 = undefined,
        head: usize = 0, // next write slot, stored only by the producer
        tail: usize = 0, // next read slot, stored only by the consumer

        /// Producer: queue `b`. False, and nothing queued, when the ring is full.
        pub fn push(self: *Self, b: u8) bool {
            const h = self.head;
            const next = (h + 1) & mask;
            if (next == @atomicLoad(usize, &self.tail, .acquire)) return false; // full
            self.buf[h] = b;
            @atomicStore(usize, &self.head, next, .release);
            return true;
        }

        /// Producer: queue all of `bytes`, or none of them when they do not
        /// fit. The consumer sees the whole slice at once: `head` moves once.
        pub fn pushSlice(self: *Self, bytes: []const u8) bool {
            if (bytes.len > self.free()) return false;
            var h = self.head;
            for (bytes) |b| {
                self.buf[h] = b;
                h = (h + 1) & mask;
            }
            @atomicStore(usize, &self.head, h, .release);
            return true;
        }

        /// Consumer: the oldest byte, or null when the ring is empty.
        pub fn pop(self: *Self) ?u8 {
            const t = self.tail;
            if (t == @atomicLoad(usize, &self.head, .acquire)) return null; // empty
            const b = self.buf[t];
            @atomicStore(usize, &self.tail, (t + 1) & mask, .release);
            return b;
        }

        /// Bytes that can be pushed now. For the producer a lower bound (the
        /// consumer can only free more), for the consumer an upper bound.
        pub fn free(self: *const Self) usize {
            const h = @atomicLoad(usize, &self.head, .acquire);
            const t = @atomicLoad(usize, &self.tail, .acquire);
            return (t -% h -% 1) & mask;
        }
    };
}

test "empty ring pops nothing" {
    var r: ByteRing(8) = .{};
    try std.testing.expectEqual(@as(?u8, null), r.pop());
    try std.testing.expectEqual(@as(usize, 7), r.free());
}
test "bytes come out in order, across the wrap" {
    var r: ByteRing(4) = .{};
    for (0..10) |i| {
        try std.testing.expect(r.push(@intCast(i)));
        try std.testing.expectEqual(@as(?u8, @intCast(i)), r.pop());
    }
}
test "a full ring refuses a byte and keeps its content" {
    var r: ByteRing(4) = .{};
    try std.testing.expect(r.push(1) and r.push(2) and r.push(3));
    try std.testing.expect(!r.push(4));
    try std.testing.expectEqual(@as(?u8, 1), r.pop());
}
test "pushSlice queues all bytes or none" {
    var r: ByteRing(8) = .{};
    try std.testing.expect(r.pushSlice(&.{ 1, 2, 3, 4, 5 }));
    try std.testing.expect(!r.pushSlice(&.{ 6, 7, 8 })); // 2 free
    try std.testing.expectEqual(@as(usize, 2), r.free());
    try std.testing.expect(r.pushSlice(&.{ 6, 7 }));
    for (1..8) |i| try std.testing.expectEqual(@as(?u8, @intCast(i)), r.pop());
}
test "a slice pushed across the wrap comes out in order" {
    var r: ByteRing(8) = .{};
    for (0..6) |i| try std.testing.expect(r.push(@intCast(i)));
    for (0..6) |i| try std.testing.expectEqual(@as(?u8, @intCast(i)), r.pop());
    try std.testing.expect(r.pushSlice(&.{ 10, 11, 12, 13, 14 })); // slots 6, 7, 0, 1, 2
    try std.testing.expectEqual(@as(usize, 2), r.free());
    for (10..15) |i| try std.testing.expectEqual(@as(?u8, @intCast(i)), r.pop());
    try std.testing.expectEqual(@as(?u8, null), r.pop());
}
