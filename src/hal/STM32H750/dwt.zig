//! Cortex-M7 DWT (Data Watchpoint & Trace) cycle counter, as typed MMIO
//! registers. microzig models the core peripherals (SCB/NVIC/…) but not the
//! DWT, so we define the two registers we need with `microzig.mmio.Mmio` rather
//! than raw pointer arithmetic. The counter is free-running at the CPU clock and
//! is used by the audio CPU-load meter (see cpu_load.zig).
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

/// Enable the free-running cycle counter. Call once at startup.
pub fn enableCycleCounter() void {
    demcr.modify(.{ .TRCENA = 1 });
    dwt_cyccnt.* = 0;
    dwt_ctrl.modify(.{ .CYCCNTENA = 1 });
}

/// Current CPU cycle count (wraps at 2^32; use wrapping subtraction on deltas).
pub inline fn cycles() u32 {
    return dwt_cyccnt.*;
}
