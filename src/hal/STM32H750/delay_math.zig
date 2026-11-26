//! Busy-wait arithmetic (pure, host-tested): the CPU cycles in a number of
//! microseconds. Used by clock.zig's `delay_us`.
const std = @import("std");

/// The core clock the chip starts on: the 64 MHz HSI oscillator.
const reset_core_hz: u32 = 64_000_000;

/// CPU cycles in `us` microseconds at a core clock of `core_hz`, rounded
/// up, saturating at `maxInt(u32)`. A `core_hz` of 0 (the clock not yet
/// known) counts as the 64 MHz the chip starts on.
pub fn cyclesFor(us: u32, core_hz: u32) u32 {
    const hz: u64 = if (core_hz == 0) reset_core_hz else core_hz;
    // At most (2^32 - 1)^2 + 999_999, which is below 2^64: no overflow.
    const cycles = (@as(u64, us) * hz + 999_999) / 1_000_000;
    return @intCast(@min(cycles, std.math.maxInt(u32)));
}

test "cycles at the board's clocks" {
    try std.testing.expectEqual(@as(u32, 4800), cyclesFor(10, 480_000_000));
    try std.testing.expectEqual(@as(u32, 400), cyclesFor(1, 400_000_000));
    try std.testing.expectEqual(@as(u32, 64), cyclesFor(1, 64_000_000));
    try std.testing.expectEqual(@as(u32, 0), cyclesFor(0, 480_000_000));
}
test "a clock that is not a whole number of MHz rounds up" {
    try std.testing.expectEqual(@as(u32, 2), cyclesFor(1, 1_500_000));
    try std.testing.expectEqual(@as(u32, 15), cyclesFor(10, 1_500_000));
}
test "an unknown clock counts as the 64 MHz the chip starts on" {
    try std.testing.expectEqual(cyclesFor(10, 64_000_000), cyclesFor(10, 0));
}
test "a wait too long for the counter saturates" {
    try std.testing.expectEqual(@as(u32, std.math.maxInt(u32)), cyclesFor(10_000_000, 480_000_000));
}
