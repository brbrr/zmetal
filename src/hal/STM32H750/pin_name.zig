//! Pin naming and GPIO address math (pure, host-tested).
const std = @import("std");

pub const Port = enum(u4) { A, B, C, D, E, F, G, H, I, J, K };

/// A GPIO pin as a plain value: store it, pass it, put it in configs.
pub const Pin = struct { port: Port, num: u4 };

/// "PC7" -> .{ .port = .C, .num = 7 }.
pub fn parse(name: []const u8) error{InvalidPinName}!Pin {
    if (name.len < 3 or name.len > 4 or name[0] != 'P') return error.InvalidPinName;
    const port = std.meta.stringToEnum(Port, name[1..2]) orelse return error.InvalidPinName;
    const num = std.fmt.parseInt(u8, name[2..], 10) catch return error.InvalidPinName;
    if (num > 15) return error.InvalidPinName;
    return .{ .port = port, .num = @intCast(num) };
}

/// GPIOx register block base (RM0433: GPIOA 0x58020000, stride 0x400).
pub fn gpioBase(port: Port) usize {
    return 0x5802_0000 + @as(usize, @intFromEnum(port)) * 0x400;
}

test "parse PC7 and PG10" {
    try std.testing.expectEqual(Pin{ .port = .C, .num = 7 }, try parse("PC7"));
    try std.testing.expectEqual(Pin{ .port = .G, .num = 10 }, try parse("PG10"));
}

test "parse rejects bad names" {
    try std.testing.expectError(error.InvalidPinName, parse("C7"));
    try std.testing.expectError(error.InvalidPinName, parse("PZ1"));
    try std.testing.expectError(error.InvalidPinName, parse("PA16"));
    try std.testing.expectError(error.InvalidPinName, parse("PAx"));
}

test "GPIOG base (Seed D7 = PG10)" {
    try std.testing.expectEqual(@as(usize, 0x5802_1800), gpioBase(.G));
    try std.testing.expectEqual(@as(usize, 0x5802_0000), gpioBase(.A));
}
