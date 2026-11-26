//! PWM timing (pure, host-tested): the timer counts in one period and the
//! compare value for a duty. Used by pwm.zig.
const std = @import("std");

/// The fewest counts in a period: 100 gives duty steps of 1 %.
const min_period_counts = 100;

/// Timer counts in one PWM period at `timer_hz`, rounded to nearest.
/// `FrequencyTooHigh` when that is under 100 counts (duty steps coarser
/// than 1 %).
pub fn periodCounts(timer_hz: u32, pwm_hz: u32) error{ FrequencyZero, FrequencyTooHigh }!u32 {
    if (pwm_hz == 0) return error.FrequencyZero;
    // u64: `timer_hz + pwm_hz / 2` can overflow a u32.
    const counts = (@as(u64, timer_hz) + pwm_hz / 2) / pwm_hz;
    if (counts < min_period_counts) return error.FrequencyTooHigh;
    return @intCast(counts); // at most `timer_hz`
}

/// Active counts in a period of `period` counts for a duty of 0..65535,
/// rounded to nearest: 0 gives 0 (never active), 65535 gives `period`
/// (active the whole period).
pub fn compareCounts(period: u32, duty: u16) u32 {
    // u64: `period * duty` overflows a u32 for any period above 65537.
    const counts = (@as(u64, period) * duty + 65535 / 2) / 65535;
    return @intCast(counts); // at most `period`
}

test "period at the board's 240 MHz timer clock" {
    try std.testing.expectEqual(@as(u32, 2400), try periodCounts(240_000_000, 100_000));
    try std.testing.expectEqual(@as(u32, 12000), try periodCounts(240_000_000, 20_000));
}
test "frequencies with no usable resolution" {
    try std.testing.expectError(error.FrequencyTooHigh, periodCounts(240_000_000, 3_000_000)); // 80 counts
    try std.testing.expectError(error.FrequencyZero, periodCounts(240_000_000, 0));
}
test "duty end points are constant levels" {
    try std.testing.expectEqual(@as(u32, 0), compareCounts(2400, 0));
    try std.testing.expectEqual(@as(u32, 2400), compareCounts(2400, 65535));
}
test "half scale, and never decreasing" {
    try std.testing.expectEqual(@as(u32, 1200), compareCounts(2400, 32768));
    var last: u32 = 0;
    var d: u32 = 0;
    while (d <= 65535) : (d += 257) {
        const c = compareCounts(2400, @intCast(d));
        try std.testing.expect(c >= last);
        last = c;
    }
}
