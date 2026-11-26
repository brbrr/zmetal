//! The least time between two I2C bus conditions (pure): how long the
//! driver still has to wait before its next START. Host-tested; used by
//! i2c.zig for `min_start_gap_us` (START to START) and `min_bus_free_us`
//! (STOP to START).
//!
//! Times are `nowUs` values: microseconds as a u64, the millisecond tick
//! times 1000 plus the part of the current millisecond. That value does
//! not wrap at `maxInt(u32)` (about 71.6 minutes); it steps back only with
//! the tick: when `clock.hal_init_tick` sets the tick to 0 again, and when
//! the u32 tick wraps after about 49.7 days (from 4_294_967_295_999 to 0).
//! So a stamp can be later than now; `pullBack` says what that means.
const std = @import("std");

/// Added to every configured gap, in microseconds. A gap is measured
/// between two `nowUs` readings, and neither is the moment its condition
/// is on the wire. `nowUs` counts whole microseconds, so a difference of n
/// can be a little more than n - 1 of real time. And the driver stamps a
/// START just before it sets START: a repeated START reaches the wire
/// later than its stamp (the peripheral releases SCL, then waits tSU:STA,
/// about 1 us at 400 kHz), a plain START almost at once, so a repeated
/// START followed by a plain one are closer on the wire than their stamps.
/// Together up to about 2 us.
pub const guard_us: u32 = 2;

/// The time the driver keeps for a configured gap: `min_gap_us` and
/// `guard_us`. A gap of 0 is off and stays 0: no guard, no wait.
pub fn guardedUs(min_gap_us: u32) u32 {
    if (min_gap_us == 0) return 0;
    return min_gap_us +| guard_us;
}

/// `stamp_us`, or `now_us` when the stamp is later than now: the clock was
/// set back after the stamp, and the stamp then counts as taken now, so
/// what is waited after it is at most one whole gap.
///
/// The rule: the stamp is later than now when `now_us -% stamp_us` is
/// more than half the u64 range. For `nowUs` values, all below 2^42, that
/// is the same as `stamp_us > now_us`. There is no wrap to tell apart from
/// a set-back: `nowUs` does not wrap at `maxInt(u32)`, and the one wrap it
/// has, the tick's after 49.7 days, is a step back like a set-back and is
/// treated as one. That costs one whole gap where the true rest would be
/// less, once in 49.7 days, and never a shorter wait.
pub fn pullBack(now_us: u64, stamp_us: u64) u64 {
    return if (now_us -% stamp_us > std.math.maxInt(u64) / 2) now_us else stamp_us;
}

/// How long to wait, in microseconds, before the next START so that at
/// least `gap_us` lie between `stamp_us` (the last START, or the last
/// STOP) and it; 0 once that time has passed. Never more than `gap_us`: a
/// stamp later than `now_us` counts as taken now (`pullBack`).
pub fn remainingUs(now_us: u64, stamp_us: u64, gap_us: u32) u32 {
    // Below half the range after `pullBack`, so no wrap.
    const elapsed = now_us -% pullBack(now_us, stamp_us);
    if (elapsed >= gap_us) return 0;
    return gap_us - @as(u32, @intCast(elapsed));
}

/// One round of the wait before a START at `now_us`, as `awaitStartGap`
/// (i2c.zig) runs it. It pulls a stamp later than now back to now, in
/// place (`pullBack`), so a clock set back costs one gap, not one per
/// round. Then it returns what is left, in microseconds, of the guarded
/// START gap after `last_start_us` and, unless the START is `repeated`,
/// of the guarded bus-free gap after `last_stop_us` (`guardedUs`; a gap
/// of 0 is off). 0: the START may go now.
pub fn startWaitUs(now_us: u64, last_start_us: *u64, last_stop_us: *u64, min_start_gap_us: u32, min_bus_free_us: u32, repeated: bool) u32 {
    last_start_us.* = pullBack(now_us, last_start_us.*);
    last_stop_us.* = pullBack(now_us, last_stop_us.*);
    const after_start = remainingUs(now_us, last_start_us.*, guardedUs(min_start_gap_us));
    if (repeated) return after_start;
    return @max(after_start, remainingUs(now_us, last_stop_us.*, guardedUs(min_bus_free_us)));
}

const testing = std.testing;

/// `startWaitUs` with stamps the test keeps.
fn waitAt(now_us: u64, last_start_us: u64, last_stop_us: u64, min_start_gap_us: u32, min_bus_free_us: u32, repeated: bool) u32 {
    var start = last_start_us;
    var stop = last_stop_us;
    return startWaitUs(now_us, &start, &stop, min_start_gap_us, min_bus_free_us, repeated);
}

/// The 49.7-day wrap of the millisecond tick: the last `nowUs` before it.
const last_us_before_tick_wrap: u64 = @as(u64, std.math.maxInt(u32)) * 1000 + 999;

/// What `awaitStartGap`'s loop (i2c.zig) does with `startWaitUs` on a test
/// clock: each round asks for the wait, and the clock moves by what was
/// waited (`clock_runs`) or stands still. `rounds_max` is i2c.zig's
/// `GAP_ROUNDS_MAX`.
const rounds_max: u32 = 64;
const Waited = struct { rounds: u32, total_us: u64 };
fn simulateWait(now_us: u64, last_start_us: u64, last_stop_us: u64, min_start_gap_us: u32, min_bus_free_us: u32, repeated: bool, clock_runs: bool) Waited {
    var now = now_us;
    var start = last_start_us;
    var stop = last_stop_us;
    var waited = Waited{ .rounds = 0, .total_us = 0 };
    while (waited.rounds < rounds_max) : (waited.rounds += 1) {
        const wait = startWaitUs(now, &start, &stop, min_start_gap_us, min_bus_free_us, repeated);
        if (wait == 0) break;
        waited.total_us += wait;
        if (clock_runs) now += wait;
    }
    return waited;
}

test "the guard: a gap of 90 asks for 92 in all, a gap of 0 for nothing" {
    try testing.expectEqual(@as(u32, 92), guardedUs(90));
    try testing.expectEqual(@as(u32, 0), guardedUs(0));
    try testing.expectEqual(@as(u32, 92), waitAt(1000, 1000, 0, 90, 0, false));
    try testing.expectEqual(@as(u32, 70), waitAt(1000, 0, 1000, 0, 68, false));
    try testing.expectEqual(@as(u32, 0), waitAt(1000, 1000, 1000, 0, 0, false));
}

test "elapsed at, one below and one above the guarded gap" {
    try testing.expectEqual(@as(u32, 1), waitAt(1000 + 91, 1000, 0, 90, 0, false));
    try testing.expectEqual(@as(u32, 0), waitAt(1000 + 92, 1000, 0, 90, 0, false));
    try testing.expectEqual(@as(u32, 0), waitAt(1000 + 93, 1000, 0, 90, 0, false));
    try testing.expectEqual(@as(u32, 1), waitAt(1000 + 69, 0, 1000, 0, 68, false));
    try testing.expectEqual(@as(u32, 0), waitAt(1000 + 70, 0, 1000, 0, 68, false));
}

test "the clock passing maxInt(u32) is no wrap: nowUs is a u64" {
    const stamp: u64 = std.math.maxInt(u32) - 9;
    const now: u64 = @as(u64, std.math.maxInt(u32)) + 41; // 50 us later
    try testing.expectEqual(@as(u32, 42), waitAt(now, stamp, 0, 90, 0, false));
    try testing.expectEqual(@as(u32, 20), waitAt(now, 0, stamp, 0, 68, false));
}

test "the set-back rule, both sides: a stamp later than now is pulled back to now" {
    // Later than now by 1: the clock was set back.
    try testing.expectEqual(@as(u64, 1000), pullBack(1000, 1001));
    try testing.expectEqual(@as(u64, 1000), pullBack(1000, 500_000));
    // At now or earlier: kept.
    try testing.expectEqual(@as(u64, 1000), pullBack(1000, 1000));
    try testing.expectEqual(@as(u64, 999), pullBack(1000, 999));
    // The rule's own edge: a difference of exactly half the range is
    // still time that passed, one more is a step back.
    const half: u64 = std.math.maxInt(u64) / 2;
    try testing.expectEqual(@as(u64, 5), pullBack(half + 5, 5));
    try testing.expectEqual(@as(u64, half + 5), pullBack(half + 5, 4));
}

test "a stamp set back by the clock asks for one guarded gap" {
    // hal_init_tick zeroed the tick 300 us ago; the stamps are from before.
    try testing.expectEqual(@as(u32, 92), waitAt(300, 500_000, 500_000, 90, 0, false));
    try testing.expectEqual(@as(u32, 92), waitAt(300, 500_000, 500_000, 90, 68, false));
    // The tick's 49.7-day wrap reads as a set-back too: one whole gap
    // (the true rest would be 76), never less.
    try testing.expectEqual(@as(u32, 92), waitAt(5, last_us_before_tick_wrap - 10, 0, 90, 0, false));
}

test "a repeated START ignores the bus-free gap" {
    // The STOP was just now, the last START long ago.
    try testing.expectEqual(@as(u32, 0), waitAt(1000, 0, 1000, 90, 68, true));
    try testing.expectEqual(@as(u32, 70), waitAt(1000, 0, 1000, 90, 68, false));
    // The START gap still applies to a repeated START.
    try testing.expectEqual(@as(u32, 42), waitAt(1050, 1000, 1000, 90, 68, true));
}

test "the wait: a clock set back costs one guarded gap in one round, not the round bound" {
    const w = simulateWait(300, 500_000, 500_000, 90, 68, false, true);
    try testing.expectEqual(@as(u32, 1), w.rounds);
    try testing.expectEqual(@as(u64, 92), w.total_us);
    const r = simulateWait(300, 500_000, 500_000, 90, 68, true, true);
    try testing.expectEqual(@as(u32, 1), r.rounds);
    try testing.expectEqual(@as(u64, 92), r.total_us);
}

test "the wait: a clock that stands still ends at the round bound" {
    const w = simulateWait(1000, 1000, 1000, 90, 68, false, false);
    try testing.expectEqual(rounds_max, w.rounds);
}

test "waits for the rest of the gap" {
    try std.testing.expectEqual(@as(u32, 40), remainingUs(100, 50, 90));
    try std.testing.expectEqual(@as(u32, 90), remainingUs(50, 50, 90));
}
test "no wait once the gap has passed" {
    try std.testing.expectEqual(@as(u32, 0), remainingUs(140, 50, 90));
    try std.testing.expectEqual(@as(u32, 0), remainingUs(1_000_000, 50, 90));
}
test "no gap configured" {
    try std.testing.expectEqual(@as(u32, 0), remainingUs(50, 50, 0));
}
test "a last START in the future never asks for more than the gap" {
    try std.testing.expectEqual(@as(u32, 90), remainingUs(10, 50, 90));
}
