//! Cortex-M7 DWT (Data Watchpoint & Trace) cycle counter, as typed MMIO
//! registers. microzig models the core peripherals (SCB/NVIC/…) but not the
//! DWT, so we define the registers we need with `microzig.mmio.Mmio` rather
//! than raw pointer arithmetic. The counter is free-running at the CPU clock and
//! is used by the audio CPU-load meter (see cpu_load.zig) and by
//! `clock.delay_us`.
const microzig = @import("microzig");
const Mmio = microzig.mmio.Mmio;

// Debug Exception and Monitor Control Register (0xE000EDFC). TRCENA (bit 24)
// gates the trace subsystem, including the DWT.
const Demcr = Mmio(packed struct(u32) {
    _reserved_0: u24,
    TRCENA: u1,
    _reserved_25: u7,
});

// DWT Control Register (0xE0001000). CYCCNTENA (bit 0) enables CYCCNT.
const DwtCtrl = Mmio(packed struct(u32) {
    CYCCNTENA: u1,
    _reserved: u31,
});

const demcr: *volatile Demcr = @ptrFromInt(0xE000EDFC);
const dwt_ctrl: *volatile DwtCtrl = @ptrFromInt(0xE0001000);
const dwt_cyccnt: *volatile u32 = @ptrFromInt(0xE0001004);
// DWT Lock Access Register (0xE0001FB0, write-only): the CoreSight software
// lock. CMSIS's core_cm7.h gives the M7's DWT one (core_cm4.h does not). A
// part that comes out of reset locked (reported for the STM32F7) ignores
// software writes to the DWT until the key is written. Where no lock is
// implemented the register ignores writes.
const dwt_lar: *volatile u32 = @ptrFromInt(0xE0001FB0);
const lar_unlock_key: u32 = 0xC5AC_CE55;

/// Enable the free-running cycle counter. It zeroes the counter, so a
/// `clock.delay_us` running in a context this call interrupts would end
/// early; call it once at start-up.
pub fn enableCycleCounter() void {
    demcr.modify(.{ .TRCENA = 1 });
    dwt_cyccnt.* = 0;
    dwt_ctrl.modify(.{ .CYCCNTENA = 1 });
}

/// Turn the cycle counter on if it is off; a running counter is only read,
/// never written (the CPU-load meter may be timing a block with it). The
/// counter is not zeroed: its users take wrapping differences. Safe from an
/// interrupt: it keeps no state of its own.
pub fn ensureCycleCounter() void {
    // TRCENA first: while it is clear, DWT registers read UNKNOWN (ARMv7-M
    // ARM, DEMCR), so CYCCNTENA means nothing until it is set.
    if (demcr.read().TRCENA == 1 and dwt_ctrl.read().CYCCNTENA == 1) return;
    demcr.modify(.{ .TRCENA = 1 });
    dwt_lar.* = lar_unlock_key;
    dwt_ctrl.modify(.{ .CYCCNTENA = 1 });
}

/// Current CPU cycle count (wraps at 2^32; use wrapping subtraction on deltas).
pub inline fn cycles() u32 {
    return dwt_cyccnt.*;
}
