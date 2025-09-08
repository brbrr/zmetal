const mmio = @import("mmio");
const types = @import("../../types.zig");

/// COMP1
pub const COMP1 = extern struct {
    /// Comparator status register
    /// offset: 0x00
    COMP1_SR: mmio.Mmio(packed struct(u32) {
        /// COMP channel 1 output status bit
        C1VAL: u1,
        /// COMP channel 2 output status bit
        C2VAL: u1,
        reserved16: u14 = 0,
        /// COMP channel 1 Interrupt Flag
        C1IF: u1,
        /// COMP channel 2 Interrupt Flag
        C2IF: u1,
        padding: u14 = 0,
    }),
    /// Comparator interrupt clear flag register
    /// offset: 0x04
    COMP1_ICFR: mmio.Mmio(packed struct(u32) {
        reserved16: u16 = 0,
        /// Clear COMP channel 1 Interrupt Flag
        CC1IF: u1,
        /// Clear COMP channel 2 Interrupt Flag
        CC2IF: u1,
        padding: u14 = 0,
    }),
    /// Comparator option register
    /// offset: 0x08
    COMP1_OR: mmio.Mmio(packed struct(u32) {
        /// Selection of source for alternate function of output ports
        AFOP: u11,
        /// Option Register
        OR: u21,
    }),
    /// Comparator configuration register 1
    /// offset: 0x0c
    COMP1_CFGR1: mmio.Mmio(packed struct(u32) {
        /// COMP channel 1 enable bit
        EN: u1,
        /// Scaler bridge enable
        BRGEN: u1,
        /// Voltage scaler enable bit
        SCALEN: u1,
        /// COMP channel 1 polarity selection bit
        POLARITY: u1,
        reserved6: u2 = 0,
        /// COMP channel 1 interrupt enable
        ITEN: u1,
        reserved8: u1 = 0,
        /// COMP channel 1 hysteresis selection bits
        HYST: u2,
        reserved12: u2 = 0,
        /// Power Mode of the COMP channel 1
        PWRMODE: u2,
        reserved16: u2 = 0,
        /// COMP channel 1 inverting input selection field
        INMSEL: u3,
        reserved20: u1 = 0,
        /// COMP channel 1 non-inverting input selection bit
        INPSEL: u1,
        reserved24: u3 = 0,
        /// COMP channel 1 blanking source selection bits
        BLANKING: u4,
        reserved31: u3 = 0,
        /// Lock bit
        LOCK: u1,
    }),
    /// Comparator configuration register 2
    /// offset: 0x10
    COMP1_CFGR2: mmio.Mmio(packed struct(u32) {
        /// COMP channel 1 enable bit
        EN: u1,
        /// Scaler bridge enable
        BRGEN: u1,
        /// Voltage scaler enable bit
        SCALEN: u1,
        /// COMP channel 1 polarity selection bit
        POLARITY: u1,
        /// Window comparator mode selection bit
        WINMODE: u1,
        reserved6: u1 = 0,
        /// COMP channel 1 interrupt enable
        ITEN: u1,
        reserved8: u1 = 0,
        /// COMP channel 1 hysteresis selection bits
        HYST: u2,
        reserved12: u2 = 0,
        /// Power Mode of the COMP channel 1
        PWRMODE: u2,
        reserved16: u2 = 0,
        /// COMP channel 1 inverting input selection field
        INMSEL: u3,
        reserved20: u1 = 0,
        /// COMP channel 1 non-inverting input selection bit
        INPSEL: u1,
        reserved24: u3 = 0,
        /// COMP channel 1 blanking source selection bits
        BLANKING: u4,
        reserved31: u3 = 0,
        /// Lock bit
        LOCK: u1,
    }),
};
