//! Time since boot and blocking delays (libdaisy System::GetNow/GetUs/Delay).
//! Backed by the HAL's 1 kHz SysTick, which `hal.default_interrupts` installs.
const microzig = @import("microzig");
const hal = microzig.hal;

/// Milliseconds since boot (wraps after ~49.7 days; compare with `-%`).
pub fn nowMs() u32 {
    return hal.clock.get_tick();
}

/// Microseconds since boot. Monotonic in thread mode, in ISRs and with
/// interrupts masked (wraps with the 32-bit ms tick after ~49.7 days).
pub fn nowUs() u64 {
    return hal.time.nowUs();
}

/// Block for at least `ms` milliseconds (SysTick-based).
pub fn delayMs(ms: u32) void {
    hal.clock.delay_ms(ms);
}

/// Block for at least `us` microseconds, timed on the core cycle counter
/// (see `clock.delay_us` for the cap and the clock it assumes).
pub fn delayUs(us: u32) void {
    hal.clock.delay_us(us);
}
