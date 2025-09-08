const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Analog-to-Digital Converter
pub const ADC3_Common = extern struct {
    /// ADC Common status register
    /// offset: 0x00
    CSR: mmio.Mmio(packed struct(u32) {
        /// Master ADC ready
        ADRDY_MST: u1,
        /// End of Sampling phase flag of the master ADC
        EOSMP_MST: u1,
        /// End of regular conversion of the master ADC
        EOC_MST: u1,
        /// End of regular sequence flag of the master ADC
        EOS_MST: u1,
        /// Overrun flag of the master ADC
        OVR_MST: u1,
        /// End of injected conversion flag of the master ADC
        JEOC_MST: u1,
        /// End of injected sequence flag of the master ADC
        JEOS_MST: u1,
        /// Analog watchdog 1 flag of the master ADC
        AWD1_MST: u1,
        /// Analog watchdog 2 flag of the master ADC
        AWD2_MST: u1,
        /// Analog watchdog 3 flag of the master ADC
        AWD3_MST: u1,
        /// Injected Context Queue Overflow flag of the master ADC
        JQOVF_MST: u1,
        reserved16: u5 = 0,
        /// Slave ADC ready
        ADRDY_SLV: u1,
        /// End of Sampling phase flag of the slave ADC
        EOSMP_SLV: u1,
        /// End of regular conversion of the slave ADC
        EOC_SLV: u1,
        /// End of regular sequence flag of the slave ADC
        EOS_SLV: u1,
        /// Overrun flag of the slave ADC
        OVR_SLV: u1,
        /// End of injected conversion flag of the slave ADC
        JEOC_SLV: u1,
        /// End of injected sequence flag of the slave ADC
        JEOS_SLV: u1,
        /// Analog watchdog 1 flag of the slave ADC
        AWD1_SLV: u1,
        /// Analog watchdog 2 flag of the slave ADC
        AWD2_SLV: u1,
        /// Analog watchdog 3 flag of the slave ADC
        AWD3_SLV: u1,
        /// Injected Context Queue Overflow flag of the slave ADC
        JQOVF_SLV: u1,
        padding: u5 = 0,
    }),
    /// offset: 0x04
    reserved4: [4]u8,
    /// ADC common control register
    /// offset: 0x08
    CCR: mmio.Mmio(packed struct(u32) {
        /// Dual ADC mode selection
        DUAL: u5,
        reserved8: u3 = 0,
        /// Delay between 2 sampling phases
        DELAY: u4,
        reserved14: u2 = 0,
        /// Dual ADC Mode Data Format
        DAMDF: u2,
        /// ADC clock mode
        CKMODE: u2,
        /// ADC prescaler
        PRESC: u4,
        /// VREFINT enable
        VREFEN: u1,
        /// Temperature sensor enable
        VSENSEEN: u1,
        /// VBAT enable
        VBATEN: u1,
        padding: u7 = 0,
    }),
    /// ADC common regular data register for dual and triple modes
    /// offset: 0x0c
    CDR: mmio.Mmio(packed struct(u32) {
        /// Regular data of the master ADC
        RDATA_MST: u16,
        /// Regular data of the slave ADC
        RDATA_SLV: u16,
    }),
};
