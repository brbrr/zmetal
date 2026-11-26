//! GPIO register field math (pure, host-tested): the values `hal.Gpio`
//! writes to MODER, OTYPER, OSPEEDR, PUPDR, AFR and BSRR.
const std = @import("std");

/// `reg` with the `width`-bit field number `index` replaced by `value`
/// (masked to the field): MODER/OSPEEDR/PUPDR are 2 bits per pin, OTYPER 1,
/// AFR 4 (index = pin number modulo 8).
pub fn setField(reg: u32, index: u5, comptime width: u6, value: u32) u32 {
    const mask: u32 = (1 << width) - 1;
    const shift: u5 = @intCast(@as(u32, index) * width);
    return (reg & ~(mask << shift)) | ((value & mask) << shift);
}

/// The BSRR word that sets (`high`) or resets one pin: atomic, no
/// read-modify-write of ODR.
pub fn bsrr(num: u4, high: bool) u32 {
    const bit = @as(u32, 1) << num;
    return if (high) bit else bit << 16;
}

test "two-bit fields (MODER, PUPDR, OSPEEDR)" {
    try std.testing.expectEqual(@as(u32, 0xC0), setField(0, 3, 2, 0b11));
    try std.testing.expectEqual(@as(u32, 0x7FFF_FFFF), setField(0xFFFF_FFFF, 15, 2, 0b01));
}
test "one-bit field (OTYPER)" {
    try std.testing.expectEqual(@as(u32, 0x0800), setField(0, 11, 1, 1));
    try std.testing.expectEqual(@as(u32, 0xFFFF_F7FF), setField(0xFFFF_FFFF, 11, 1, 0));
}
test "four-bit field (AFR: index is the pin number modulo 8)" {
    try std.testing.expectEqual(@as(u32, 0x70), setField(0, 1, 4, 7));
}
test "a value wider than the field is masked" {
    try std.testing.expectEqual(@as(u32, 0b11), setField(0, 0, 2, 0b111));
}
test "BSRR words" {
    try std.testing.expectEqual(@as(u32, 0x0000_0080), bsrr(7, true));
    try std.testing.expectEqual(@as(u32, 0x0080_0000), bsrr(7, false));
}
