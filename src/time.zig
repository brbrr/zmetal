//! Time since boot and blocking delays (libdaisy System::GetNow/GetUs/Delay).
//! Backed by the HAL's 1 kHz SysTick, which `hal.default_interrupts` installs.
const microzig = @import("microzig");
const hal = microzig.hal;
const tick_math = hal.tick_math;
const systick = microzig.cpu.peripherals.systick;

/// Milliseconds since boot (wraps after ~49.7 days; compare with `-%`).
pub fn nowMs() u32 {
    return hal.clock.get_tick();
}

/// Interrupt Control and State Register; bit 26 = PENDSTSET (SysTick pending).
const icsr: *const volatile u32 = @ptrFromInt(0xE000_ED04);

/// Microseconds since boot. Monotonic in thread mode, in ISRs and with
/// interrupts masked (wraps with the 32-bit ms tick after ~49.7 days).
pub fn nowUs() u64 {
    while (true) {
        const ms = hal.clock.get_tick();
        var val: u32 = systick.VAL.read().CURRENT;
        // Reloaded but its ISR hasn't run (we're in a higher-priority ISR or
        // masked): VAL may already be post-reload while `ms` isn't. Re-read VAL
        // so both belong to the new millisecond, and count that ms.
        const pending = icsr.* & (1 << 26) != 0;
        if (pending) val = systick.VAL.read().CURRENT;
        // Thread mode: the SysTick ISR may run between the reads; retry.
        if (hal.clock.get_tick() == ms) return tick_math.nowUsFrom(ms, systick.LOAD.read().RELOAD, val, pending);
    }
}

/// Block for at least `ms` milliseconds (SysTick-based).
pub fn delayMs(ms: u32) void {
    hal.clock.delay_ms(ms);
}

/// Block for approximately `us` microseconds (calibrated busy loop).
pub fn delayUs(us: u32) void {
    hal.clock.delay_us(us);
}
