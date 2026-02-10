const microzig = @import("microzig");
const mmio = microzig.mmio;
const types = @import("../../types.zig");

/// Low power timer
pub const LPTIM3 = extern struct {
    /// Interrupt and Status Register
    /// offset: 0x00
    ISR: mmio.Mmio(packed struct(u32) {
        /// Compare match
        CMPM: u1,
        /// Autoreload match
        ARRM: u1,
        /// External trigger edge event
        EXTTRIG: u1,
        /// Compare register update OK
        CMPOK: u1,
        /// Autoreload register update OK
        ARROK: u1,
        /// Counter direction change down to up
        UP: u1,
        /// Counter direction change up to down
        DOWN: u1,
        padding: u25 = 0,
    }),
    /// Interrupt Clear Register
    /// offset: 0x04
    ICR: mmio.Mmio(packed struct(u32) {
        /// compare match Clear Flag
        CMPMCF: u1,
        /// Autoreload match Clear Flag
        ARRMCF: u1,
        /// External trigger valid edge Clear Flag
        EXTTRIGCF: u1,
        /// Compare register update OK Clear Flag
        CMPOKCF: u1,
        /// Autoreload register update OK Clear Flag
        ARROKCF: u1,
        /// Direction change to UP Clear Flag
        UPCF: u1,
        /// Direction change to down Clear Flag
        DOWNCF: u1,
        padding: u25 = 0,
    }),
    /// Interrupt Enable Register
    /// offset: 0x08
    IER: mmio.Mmio(packed struct(u32) {
        /// Compare match Interrupt Enable
        CMPMIE: u1,
        /// Autoreload match Interrupt Enable
        ARRMIE: u1,
        /// External trigger valid edge Interrupt Enable
        EXTTRIGIE: u1,
        /// Compare register update OK Interrupt Enable
        CMPOKIE: u1,
        /// Autoreload register update OK Interrupt Enable
        ARROKIE: u1,
        /// Direction change to UP Interrupt Enable
        UPIE: u1,
        /// Direction change to down Interrupt Enable
        DOWNIE: u1,
        padding: u25 = 0,
    }),
    /// Configuration Register
    /// offset: 0x0c
    CFGR: mmio.Mmio(packed struct(u32) {
        /// Clock selector
        CKSEL: u1,
        /// Clock Polarity
        CKPOL: u2,
        /// Configurable digital filter for external clock
        CKFLT: u2,
        reserved6: u1 = 0,
        /// Configurable digital filter for trigger
        TRGFLT: u2,
        reserved9: u1 = 0,
        /// Clock prescaler
        PRESC: u3,
        reserved13: u1 = 0,
        /// Trigger selector
        TRIGSEL: u3,
        reserved17: u1 = 0,
        /// Trigger enable and polarity
        TRIGEN: u2,
        /// Timeout enable
        TIMOUT: u1,
        /// Waveform shape
        WAVE: u1,
        /// Waveform shape polarity
        WAVPOL: u1,
        /// Registers update mode
        PRELOAD: u1,
        /// counter mode enabled
        COUNTMODE: u1,
        /// Encoder mode enable
        ENC: u1,
        padding: u7 = 0,
    }),
    /// Control Register
    /// offset: 0x10
    CR: mmio.Mmio(packed struct(u32) {
        /// LPTIM Enable
        ENABLE: u1,
        /// LPTIM start in single mode
        SNGSTRT: u1,
        /// Timer start in continuous mode
        CNTSTRT: u1,
        /// Counter reset
        COUNTRST: u1,
        /// Reset after read enable
        RSTARE: u1,
        padding: u27 = 0,
    }),
    /// Compare Register
    /// offset: 0x14
    CMP: mmio.Mmio(packed struct(u32) {
        /// Compare value
        CMP: u16,
        padding: u16 = 0,
    }),
    /// Autoreload Register
    /// offset: 0x18
    ARR: mmio.Mmio(packed struct(u32) {
        /// Auto reload value
        ARR: u16,
        padding: u16 = 0,
    }),
    /// Counter Register
    /// offset: 0x1c
    CNT: mmio.Mmio(packed struct(u32) {
        /// Counter value
        CNT: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x20
    reserved32: [4]u8,
    /// LPTIM configuration register 2
    /// offset: 0x24
    LPTIM_CFGR2: mmio.Mmio(packed struct(u32) {
        /// LPTIM Input 1 selection
        IN1SEL: u2,
        padding: u30 = 0,
    }),
};
