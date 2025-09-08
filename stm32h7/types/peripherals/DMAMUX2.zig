const mmio = @import("mmio");
const types = @import("../../types.zig");

/// DMAMUX
pub const DMAMUX2 = extern struct {
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x00
    DMAMUX2_C0CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x04
    DMAMUX2_C1CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x08
    DMAMUX2_C2CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x0c
    DMAMUX2_C3CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x10
    DMAMUX2_C4CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x14
    DMAMUX2_C5CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x18
    DMAMUX2_C6CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x1c
    DMAMUX2_C7CR: mmio.Mmio(packed struct(u32) {
        /// Input DMA request line selected
        DMAREQ_ID: u8,
        /// Interrupt enable at synchronization event overrun
        SOIE: u1,
        /// Event generation enable/disable
        EGE: u1,
        reserved16: u6 = 0,
        /// Synchronous operating mode enable/disable
        SE: u1,
        /// Synchronization event type selector Defines the synchronization event on the selected synchronization input:
        SPOL: u2,
        /// Number of DMA requests to forward Defines the number of DMA requests forwarded before output event is generated. In synchronous mode, it also defines the number of DMA requests to forward after a synchronization event, then stop forwarding. The actual number of DMA requests forwarded is NBREQ+1. Note: This field can only be written when both SE and EGE bits are reset.
        NBREQ: u5,
        /// Synchronization input selected
        SYNC_ID: u5,
        padding: u3 = 0,
    }),
    /// offset: 0x20
    reserved32: [96]u8,
    /// DMAMUX request line multiplexer interrupt channel status register
    /// offset: 0x80
    DMAMUX2_CSR: mmio.Mmio(packed struct(u32) {
        /// Synchronization overrun event flag
        SOF: u16,
        padding: u16 = 0,
    }),
    /// DMAMUX request line multiplexer interrupt clear flag register
    /// offset: 0x84
    DMAMUX2_CFR: mmio.Mmio(packed struct(u32) {
        /// Clear synchronization overrun event flag
        CSOF: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x88
    reserved136: [120]u8,
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x100
    DMAMUX2_RG0CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x104
    DMAMUX2_RG1CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x108
    DMAMUX2_RG2CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x10c
    DMAMUX2_RG3CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x110
    DMAMUX2_RG4CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x114
    DMAMUX2_RG5CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x118
    DMAMUX2_RG6CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x11c
    DMAMUX2_RG7CR: mmio.Mmio(packed struct(u32) {
        /// DMA request trigger input selected
        SIG_ID: u5,
        reserved8: u3 = 0,
        /// Interrupt enable at trigger event overrun
        OIE: u1,
        reserved16: u7 = 0,
        /// DMA request generator channel enable/disable
        GE: u1,
        /// DMA request generator trigger event type selection Defines the trigger event on the selected DMA request trigger input
        GPOL: u2,
        /// Number of DMA requests to generate Defines the number of DMA requests generated after a trigger event, then stop generating. The actual number of generated DMA requests is GNBREQ+1. Note: This field can only be written when GE bit is reset.
        GNBREQ: u5,
        padding: u8 = 0,
    }),
    /// offset: 0x120
    reserved288: [32]u8,
    /// DMAMux - DMA request generator status register
    /// offset: 0x140
    DMAMUX2_RGSR: mmio.Mmio(packed struct(u32) {
        /// Trigger event overrun flag The flag is set when a trigger event occurs on DMA request generator channel x, while the DMA request generator counter value is lower than GNBREQ. The flag is cleared by writing 1 to the corresponding COFx bit in DMAMUX_RGCFR register.
        OF: u8,
        padding: u24 = 0,
    }),
    /// DMAMux - DMA request generator clear flag register
    /// offset: 0x144
    DMAMUX2_RGCFR: mmio.Mmio(packed struct(u32) {
        /// Clear trigger event overrun flag Upon setting, this bit clears the corresponding overrun flag OFx in the DMAMUX_RGCSR register.
        COF: u8,
        padding: u24 = 0,
    }),
};
