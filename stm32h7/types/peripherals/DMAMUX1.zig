const mz = @import("microzig");
const mmio = mz.mmio;
const types = @import("../../types.zig");

/// DMAMUX
pub const DMAMUX1 = extern struct {
    /// DMAMux - DMA request line multiplexer channel x control register
    /// offset: 0x00
    DMAMUX1_C0CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C1CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C2CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C3CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C4CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C5CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C6CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_C7CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x20
    DMAMUX1_C8CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x24
    DMAMUX1_C9CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x28
    DMAMUX1_C10CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x2c
    DMAMUX1_C11CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x30
    DMAMUX1_C12CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x34
    DMAMUX1_C13CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x38
    DMAMUX1_C14CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x3c
    DMAMUX1_C15CR: mmio.Mmio(packed struct(u32) {
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
    /// offset: 0x40
    reserved64: [64]u8,
    /// DMAMUX request line multiplexer interrupt channel status register
    /// offset: 0x80
    DMAMUX1_CSR: mmio.Mmio(packed struct(u32) {
        /// Synchronization overrun event flag
        SOF: u16,
        padding: u16 = 0,
    }),
    /// DMAMUX request line multiplexer interrupt clear flag register
    /// offset: 0x84
    DMAMUX1_CFR: mmio.Mmio(packed struct(u32) {
        /// Clear synchronization overrun event flag
        CSOF: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x88
    reserved136: [120]u8,
    /// DMAMux - DMA request generator channel x control register
    /// offset: 0x100
    DMAMUX1_RG0CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG1CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG2CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG3CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG4CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG5CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG6CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RG7CR: mmio.Mmio(packed struct(u32) {
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
    DMAMUX1_RGSR: mmio.Mmio(packed struct(u32) {
        /// Trigger event overrun flag The flag is set when a trigger event occurs on DMA request generator channel x, while the DMA request generator counter value is lower than GNBREQ. The flag is cleared by writing 1 to the corresponding COFx bit in DMAMUX_RGCFR register.
        OF: u8,
        padding: u24 = 0,
    }),
    /// DMAMux - DMA request generator clear flag register
    /// offset: 0x144
    DMAMUX1_RGCFR: mmio.Mmio(packed struct(u32) {
        /// Clear trigger event overrun flag Upon setting, this bit clears the corresponding overrun flag OFx in the DMAMUX_RGCSR register.
        COF: u8,
        padding: u24 = 0,
    }),
};
