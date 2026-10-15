//! I2C transfer segmentation (pure): a transaction of N bytes is sent as
//! NBYTES <= 255 pieces with RELOAD set on all but the last, so one START/STOP
//! frames the whole transfer regardless of how the caller chunked the data.
//! Host-tested; used by i2c.zig.
const std = @import("std");

pub const Segment = struct { nbytes: u8, reload: bool };

pub const SegmentIter = struct {
    remaining: usize,

    pub fn next(self: *SegmentIter) ?Segment {
        if (self.remaining == 0) return null;
        const n: u8 = @intCast(@min(self.remaining, 255));
        self.remaining -= n;
        return .{ .nbytes = n, .reload = self.remaining > 0 };
    }
};

pub fn segments(total: usize) SegmentIter {
    return .{ .remaining = total };
}

/// Flattens `[]const Slice` (Slice = `[]const u8` for writes, `[]u8` for
/// reads) into one stream of element pointers.
pub fn ByteIter(comptime Slice: type) type {
    return struct {
        pub const Ptr = @TypeOf(&@as(Slice, undefined)[0]);
        chunks: []const Slice,
        ci: usize = 0,
        bi: usize = 0,

        pub fn next(self: *@This()) ?Ptr {
            while (self.ci < self.chunks.len) {
                const c = self.chunks[self.ci];
                if (self.bi < c.len) {
                    defer self.bi += 1;
                    return &c[self.bi];
                }
                self.ci += 1;
                self.bi = 0;
            }
            return null;
        }
    };
}

pub fn totalLen(comptime Slice: type, chunks: []const Slice) usize {
    var n: usize = 0;
    for (chunks) |c| n += c.len;
    return n;
}

test "register write: 1 + 2 bytes is one 3-byte segment" {
    var it = segments(3);
    try std.testing.expectEqual(Segment{ .nbytes = 3, .reload = false }, it.next().?);
    try std.testing.expectEqual(@as(?Segment, null), it.next());
}

test "600 bytes: 255+255 with RELOAD, then 90" {
    var it = segments(600);
    try std.testing.expectEqual(Segment{ .nbytes = 255, .reload = true }, it.next().?);
    try std.testing.expectEqual(Segment{ .nbytes = 255, .reload = true }, it.next().?);
    try std.testing.expectEqual(Segment{ .nbytes = 90, .reload = false }, it.next().?);
    try std.testing.expectEqual(@as(?Segment, null), it.next());
}

test "exactly 255 needs no reload" {
    var it = segments(255);
    try std.testing.expectEqual(Segment{ .nbytes = 255, .reload = false }, it.next().?);
    try std.testing.expectEqual(@as(?Segment, null), it.next());
}

test "byte iterator walks chunks in order, skipping empty ones" {
    const a = [_]u8{0x10};
    const b = [_]u8{};
    const c = [_]u8{ 0xAA, 0xBB };
    const chunks = [_][]const u8{ &a, &b, &c };
    var it = ByteIter([]const u8){ .chunks = &chunks };
    try std.testing.expectEqual(@as(u8, 0x10), it.next().?.*);
    try std.testing.expectEqual(@as(u8, 0xAA), it.next().?.*);
    try std.testing.expectEqual(@as(u8, 0xBB), it.next().?.*);
    try std.testing.expectEqual(@as(?*const u8, null), it.next());
    try std.testing.expectEqual(@as(usize, 3), totalLen([]const u8, &chunks));
}

test "byte iterator writes through for read buffers" {
    var a = [_]u8{ 0, 0 };
    var b = [_]u8{0};
    const chunks = [_][]u8{ &a, &b };
    var it = ByteIter([]u8){ .chunks = &chunks };
    var v: u8 = 1;
    while (it.next()) |p| : (v += 1) p.* = v;
    try std.testing.expectEqualSlices(u8, &.{ 1, 2 }, &a);
    try std.testing.expectEqualSlices(u8, &.{3}, &b);
}
