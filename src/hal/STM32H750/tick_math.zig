//! Pure SysTick time math (host-tested). SysTick counts DOWN from LOAD to 0
//! once per millisecond; elapsed sub-ms ticks = LOAD - VAL.
const std = @import("std");

/// Microseconds since boot from the ms tick and the SysTick LOAD/VAL pair.
pub fn combineUs(ms: u32, load: u32, val: u32) u64 {
    const sub: u64 = (@as(u64, load - @min(val, load)) * 1000) / (@as(u64, load) + 1);
    return @as(u64, ms) * 1000 + sub;
}

/// `combineUs`, compensating for a SysTick reload that has happened but whose
/// ISR has not run yet (`pending` = ICSR.PENDSTSET): the ms tick is then one
/// behind the VAL that was read after the reload.
pub fn nowUsFrom(ms: u32, load: u32, val: u32, pending: bool) u64 {
    return combineUs(ms +% @intFromBool(pending), load, val);
}

test "start of a millisecond" {
    try std.testing.expectEqual(@as(u64, 5000), combineUs(5, 479_999, 479_999));
}

test "half way through a millisecond" {
    try std.testing.expectEqual(@as(u64, 5500), combineUs(5, 479_999, 239_999));
}

test "last tick before reload stays below the next ms" {
    try std.testing.expect(combineUs(5, 479_999, 0) < combineUs(6, 479_999, 479_999));
}

test "VAL above LOAD (just reloaded) clamps to the start of the ms" {
    try std.testing.expectEqual(@as(u64, 7000), combineUs(7, 1000, 2000));
}

test "pending SysTick (reload not yet counted) advances the ms" {
    // ISR/masked context: tick still 5 but SysTick already reloaded (VAL near
    // LOAD again). Without the pending flag this would read 5000 < 5999.
    try std.testing.expectEqual(@as(u64, 6000), nowUsFrom(5, 479_999, 479_999, true));
    try std.testing.expectEqual(@as(u64, 5000), nowUsFrom(5, 479_999, 479_999, false));
}
