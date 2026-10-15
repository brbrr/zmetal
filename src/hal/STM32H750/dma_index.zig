//! DMA channel index <-> (controller, stream) mapping. Channels 0..7 are
//! DMA1 streams 0..7, channels 8..15 are DMA2 streams 0..7 (8 streams per
//! controller). Pure; host-tested.
const std = @import("std");

pub const Location = struct { controller: u1, stream: u3 };

pub fn locate(index: u4) Location {
    return .{ .controller = @intCast(index >> 3), .stream = @truncate(index) };
}

test "channels 0-7 are DMA1 streams 0-7" {
    for (0..8) |i| {
        const l = locate(@intCast(i));
        try std.testing.expectEqual(@as(u1, 0), l.controller);
        try std.testing.expectEqual(@as(u3, @intCast(i)), l.stream);
    }
}

test "channel 7 is DMA1 stream 7, not DMA2" {
    try std.testing.expectEqual(Location{ .controller = 0, .stream = 7 }, locate(7));
}

test "channels 8-15 are DMA2 streams 0-7" {
    try std.testing.expectEqual(Location{ .controller = 1, .stream = 0 }, locate(8));
    try std.testing.expectEqual(Location{ .controller = 1, .stream = 3 }, locate(11));
    try std.testing.expectEqual(Location{ .controller = 1, .stream = 7 }, locate(15));
}
