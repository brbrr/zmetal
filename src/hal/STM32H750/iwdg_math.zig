//! Independent watchdog timing (pure, host-tested): the prescaler and
//! reload that give a timeout. Used by iwdg.zig at comptime.
const std = @import("std");

/// IWDG_PR and IWDG_RLR values. The counter runs from the 32 kHz LSI
/// divided by `4 << prescaler` and counts down from `reload`.
pub const Setting = struct { prescaler: u3, reload: u12 };

/// LSI ticks per millisecond (32 kHz, nominal).
const lsi_per_ms = 32;

/// The largest prescaler used: 6 divides by 256. PR = 7 divides by 256 as
/// well (RM0433; `DivideBy256bis` in the register definitions), not by the
/// 512 that `4 << 7` would give, so it adds no range and is never picked.
const max_prescaler = 6;

/// The setting for a timeout of at least `timeout_ms`: the smallest
/// prescaler that fits, with the reload rounded up, so the real timeout,
/// `(reload + 1) * (4 << prescaler) / 32` ms, is never shorter than asked.
/// The longest is 32768 ms (prescaler 6, reload 4095).
pub fn settingFor(timeout_ms: u32) error{ TimeoutTooShort, TimeoutTooLong }!Setting {
    if (timeout_ms == 0) return error.TimeoutTooShort;
    // u64: `timeout_ms * 32` does not fit a u32 for large timeouts.
    const ticks = @as(u64, timeout_ms) * lsi_per_ms;
    for (0..max_prescaler + 1) |p| {
        const divider = @as(u64, 4) << @intCast(p);
        const counts = (ticks + divider - 1) / divider; // rounded up
        if (counts <= 4096) return .{ .prescaler = @intCast(p), .reload = @intCast(counts - 1) };
    }
    return error.TimeoutTooLong;
}

test "smallest prescaler that fits" {
    try std.testing.expectEqual(Setting{ .prescaler = 0, .reload = 3999 }, try settingFor(500));
    try std.testing.expectEqual(Setting{ .prescaler = 1, .reload = 3999 }, try settingFor(1000));
}
test "limits" {
    try std.testing.expectEqual(Setting{ .prescaler = 0, .reload = 7 }, try settingFor(1));
    try std.testing.expectEqual(Setting{ .prescaler = 6, .reload = 4095 }, try settingFor(32768));
    try std.testing.expectError(error.TimeoutTooLong, settingFor(32769));
    try std.testing.expectError(error.TimeoutTooShort, settingFor(0));
}
test "the real timeout is never shorter than asked" {
    for ([_]u32{ 3, 250, 513, 2001, 30000 }) |ms| {
        const s = try settingFor(ms);
        const real_ms = (@as(u64, s.reload) + 1) * (@as(u64, 4) << s.prescaler) / 32;
        try std.testing.expect(real_ms >= ms);
    }
}
