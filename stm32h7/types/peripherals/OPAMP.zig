const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Operational amplifiers
pub const OPAMP = extern struct {
    /// OPAMP1 control/status register
    /// offset: 0x00
    OPAMP1_CSR: mmio.Mmio(packed struct(u32) {
        /// Operational amplifier Enable
        OPAEN: u1,
        /// Force internal reference on VP (reserved for test
        FORCE_VP: u1,
        /// Operational amplifier PGA mode
        VP_SEL: u2,
        reserved5: u1 = 0,
        /// Inverting input selection
        VM_SEL: u2,
        reserved8: u1 = 0,
        /// Operational amplifier high-speed mode
        OPAHSM: u1,
        reserved11: u2 = 0,
        /// Calibration mode enabled
        CALON: u1,
        /// Calibration selection
        CALSEL: u2,
        /// allows to switch from AOP offset trimmed values to AOP offset
        PGA_GAIN: u4,
        /// User trimming enable
        USERTRIM: u1,
        reserved29: u10 = 0,
        /// OPAMP calibration reference voltage output control (reserved for test)
        TSTREF: u1,
        /// Operational amplifier calibration output
        CALOUT: u1,
        padding: u1 = 0,
    }),
    /// OPAMP1 offset trimming register in normal mode
    /// offset: 0x04
    OPAMP1_OTR: mmio.Mmio(packed struct(u32) {
        /// Trim for NMOS differential pairs
        TRIMOFFSETN: u5,
        reserved8: u3 = 0,
        /// Trim for PMOS differential pairs
        TRIMOFFSETP: u5,
        padding: u19 = 0,
    }),
    /// OPAMP1 offset trimming register in low-power mode
    /// offset: 0x08
    OPAMP1_HSOTR: mmio.Mmio(packed struct(u32) {
        /// Trim for NMOS differential pairs
        TRIMLPOFFSETN: u5,
        reserved8: u3 = 0,
        /// Trim for PMOS differential pairs
        TRIMLPOFFSETP: u5,
        padding: u19 = 0,
    }),
    /// offset: 0x0c
    reserved12: [4]u8,
    /// OPAMP2 control/status register
    /// offset: 0x10
    OPAMP2_CSR: mmio.Mmio(packed struct(u32) {
        /// Operational amplifier Enable
        OPAEN: u1,
        /// Force internal reference on VP (reserved for test)
        FORCE_VP: u1,
        reserved5: u3 = 0,
        /// Inverting input selection
        VM_SEL: u2,
        reserved8: u1 = 0,
        /// Operational amplifier high-speed mode
        OPAHSM: u1,
        reserved11: u2 = 0,
        /// Calibration mode enabled
        CALON: u1,
        /// Calibration selection
        CALSEL: u2,
        /// Operational amplifier Programmable amplifier gain value
        PGA_GAIN: u4,
        /// User trimming enable
        USERTRIM: u1,
        reserved29: u10 = 0,
        /// OPAMP calibration reference voltage output control (reserved for test)
        TSTREF: u1,
        /// Operational amplifier calibration output
        CALOUT: u1,
        padding: u1 = 0,
    }),
    /// OPAMP2 offset trimming register in normal mode
    /// offset: 0x14
    OPAMP2_OTR: mmio.Mmio(packed struct(u32) {
        /// Trim for NMOS differential pairs
        TRIMOFFSETN: u5,
        reserved8: u3 = 0,
        /// Trim for PMOS differential pairs
        TRIMOFFSETP: u5,
        padding: u19 = 0,
    }),
    /// OPAMP2 offset trimming register in low-power mode
    /// offset: 0x18
    OPAMP2_HSOTR: mmio.Mmio(packed struct(u32) {
        /// Trim for NMOS differential pairs
        TRIMLPOFFSETN: u5,
        reserved8: u3 = 0,
        /// Trim for PMOS differential pairs
        TRIMLPOFFSETP: u5,
        padding: u19 = 0,
    }),
};
