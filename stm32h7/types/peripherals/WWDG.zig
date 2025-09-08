const mmio = @import("mmio");
const types = @import("../../types.zig");

/// WWDG
pub const WWDG = extern struct {
    /// Control register
    /// offset: 0x00
    WWDG_CR: mmio.Mmio(packed struct(u32) {
        /// 7-bit counter (MSB to LSB) These bits contain the value of the watchdog counter. It is decremented every (4096 x 2WDGTB[1:0]) PCLK cycles. A reset is produced when it is decremented from 0x40 to 0x3F (T6 becomes cleared).
        T: u7,
        /// Activation bit This bit is set by software and only cleared by hardware after a reset. When WDGA=1, the watchdog can generate a reset.
        WDGA: u1,
        padding: u24 = 0,
    }),
    /// Configuration register
    /// offset: 0x04
    WWDG_CFR: mmio.Mmio(packed struct(u32) {
        /// 7-bit window value These bits contain the window value to be compared to the downcounter.
        W: u7,
        reserved9: u2 = 0,
        /// Early wakeup interrupt When set, an interrupt occurs whenever the counter reaches the value 0x40. This interrupt is only cleared by hardware after a reset.
        EWI: u1,
        reserved11: u1 = 0,
        /// Timer base The time base of the prescaler can be modified as follows:
        WDGTB: u2,
        padding: u19 = 0,
    }),
    /// Status register
    /// offset: 0x08
    WWDG_SR: mmio.Mmio(packed struct(u32) {
        /// Early wakeup interrupt flag This bit is set by hardware when the counter has reached the value 0x40. It must be cleared by software by writing 0. A write of 1 has no effect. This bit is also set if the interrupt is not enabled.
        EWIF: u1,
        padding: u31 = 0,
    }),
};
