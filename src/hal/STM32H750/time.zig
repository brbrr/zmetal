const std = @import("std");
const microzig = @import("microzig");
const time = microzig.drivers.time;
const clk = @import("clock.zig");
// hal.clock.inc_tick();

// TODO: Implement Clock_Device

/// microzig's `time.Absolute` is in microseconds; the SysTick tick is 1 ms.
pub fn get_time_since_boot() time.Absolute {
    return @enumFromInt(@as(u64, clk.get_tick()) * 1000);
}

pub fn sleep_ms(time_ms: u32) void {
    sleep_us(@as(u64, time_ms) * 1000);
}

pub fn sleep_us(time_us: u64) void {
    const end_time = time.make_timeout_us(get_time_since_boot(), time_us);
    while (!end_time.is_reached_by(get_time_since_boot())) {}
}
