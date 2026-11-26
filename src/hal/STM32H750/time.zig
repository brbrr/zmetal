const std = @import("std");
const microzig = @import("microzig");
const time = microzig.drivers.time;
const clk = @import("clock.zig");
const tick_math = @import("tick_math.zig");
const systick = microzig.cpu.peripherals.systick;

/// Interrupt Control and State Register; bit 26 = PENDSTSET (SysTick pending).
const icsr: *const volatile u32 = @ptrFromInt(0xE000_ED04);

/// Microseconds since boot. Monotonic in thread mode, in ISRs and with
/// interrupts masked (wraps with the 32-bit ms tick after ~49.7 days).
pub fn nowUs() u64 {
    while (true) {
        const ms = clk.get_tick();
        var val: u32 = systick.VAL.read().CURRENT;
        // Reloaded but its ISR hasn't run (we're in a higher-priority ISR or
        // masked): VAL may already be post-reload while `ms` isn't. Re-read VAL
        // so both belong to the new millisecond, and count that ms.
        const pending = icsr.* & (1 << 26) != 0;
        if (pending) val = systick.VAL.read().CURRENT;
        // Thread mode: the SysTick ISR may run between the reads; retry.
        if (clk.get_tick() == ms) return tick_math.nowUsFrom(ms, systick.LOAD.read().RELOAD, val, pending);
    }
}

/// microzig's `time.Absolute` is in microseconds.
pub fn get_time_since_boot() time.Absolute {
    return @enumFromInt(nowUs());
}

pub fn sleep_ms(time_ms: u32) void {
    sleep_us(@as(u64, time_ms) * 1000);
}

pub fn sleep_us(time_us: u64) void {
    const end_time = time.make_timeout_us(get_time_since_boot(), time_us);
    while (!end_time.is_reached_by(get_time_since_boot())) {}
}
