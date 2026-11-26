//! ADC1 helpers (pure, host-tested): the ADC1 input behind a pin, and raw
//! counts to millivolts. Used by adc.zig.
const std = @import("std");
const pin_name = @import("pin_name.zig");

/// The pins with an ADC1 input (ADC1_INPn) and n, as libdaisy lists them
/// (`src/per/adc.cpp`): the Seed's analog pins. ADC1_INP2 (PF11) and
/// ADC1_INP6 (PF12) are not listed: the Seed's SDRAM uses those pins.
const inputs = [_]struct { pin: pin_name.Pin, channel: u5 }{
    .{ .pin = .{ .port = .A, .num = 6 }, .channel = 3 },
    .{ .pin = .{ .port = .C, .num = 4 }, .channel = 4 },
    .{ .pin = .{ .port = .B, .num = 1 }, .channel = 5 },
    .{ .pin = .{ .port = .A, .num = 7 }, .channel = 7 },
    .{ .pin = .{ .port = .C, .num = 5 }, .channel = 8 },
    .{ .pin = .{ .port = .B, .num = 0 }, .channel = 9 },
    .{ .pin = .{ .port = .C, .num = 0 }, .channel = 10 },
    .{ .pin = .{ .port = .C, .num = 1 }, .channel = 11 },
    .{ .pin = .{ .port = .C, .num = 2 }, .channel = 12 },
    .{ .pin = .{ .port = .C, .num = 3 }, .channel = 13 },
    .{ .pin = .{ .port = .A, .num = 2 }, .channel = 14 },
    .{ .pin = .{ .port = .A, .num = 3 }, .channel = 15 },
    .{ .pin = .{ .port = .A, .num = 0 }, .channel = 16 },
    .{ .pin = .{ .port = .A, .num = 1 }, .channel = 17 },
    .{ .pin = .{ .port = .A, .num = 4 }, .channel = 18 },
    .{ .pin = .{ .port = .A, .num = 5 }, .channel = 19 },
};

/// The ADC1 input (the n of ADC1_INPn) on `pin`, or null when it has none.
pub fn channelFor(pin: pin_name.Pin) ?u5 {
    for (inputs) |in| {
        if (in.pin.port == pin.port and in.pin.num == pin.num) return in.channel;
    }
    return null;
}

/// A 16-bit reading in millivolts, `vref_mv` being the reference (VREF+):
/// 65535 is `vref_mv`. Rounded down.
pub fn toMillivolts(raw: u16, vref_mv: u16) u16 {
    // u32: 65535 * 65535 fits; the quotient is at most `vref_mv`.
    return @intCast(@as(u32, raw) * vref_mv / 65535);
}

test "Seed analog pins map to their ADC1 inputs" {
    try std.testing.expectEqual(@as(?u5, 17), channelFor(.{ .port = .A, .num = 1 })); // D24, CC_SENSE on v3
    try std.testing.expectEqual(@as(?u5, 16), channelFor(.{ .port = .A, .num = 0 })); // D25
    try std.testing.expectEqual(@as(?u5, 15), channelFor(.{ .port = .A, .num = 3 })); // D16
    try std.testing.expectEqual(@as(?u5, 10), channelFor(.{ .port = .C, .num = 0 })); // D15
    try std.testing.expectEqual(@as(?u5, 3), channelFor(.{ .port = .A, .num = 6 })); // D19
}
test "a pin with no ADC1 input" {
    try std.testing.expectEqual(@as(?u5, null), channelFor(.{ .port = .B, .num = 6 }));
}
test "raw counts to millivolts" {
    try std.testing.expectEqual(@as(u16, 0), toMillivolts(0, 3300));
    try std.testing.expectEqual(@as(u16, 3300), toMillivolts(65535, 3300));
    try std.testing.expectEqual(@as(u16, 1650), toMillivolts(32768, 3300));
}
