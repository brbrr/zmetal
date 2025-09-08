const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Access control
pub const AC = extern struct {
    /// Instruction and Data Tightly-Coupled Memory Control Registers
    /// offset: 0x00
    ITCMCR: mmio.Mmio(packed struct(u32) {
        /// EN
        EN: u1,
        /// RMW
        RMW: u1,
        /// RETEN
        RETEN: u1,
        /// SZ
        SZ: u4,
        padding: u25 = 0,
    }),
    /// Instruction and Data Tightly-Coupled Memory Control Registers
    /// offset: 0x04
    DTCMCR: mmio.Mmio(packed struct(u32) {
        /// EN
        EN: u1,
        /// RMW
        RMW: u1,
        /// RETEN
        RETEN: u1,
        /// SZ
        SZ: u4,
        padding: u25 = 0,
    }),
    /// AHBP Control register
    /// offset: 0x08
    AHBPCR: mmio.Mmio(packed struct(u32) {
        /// EN
        EN: u1,
        /// SZ
        SZ: u3,
        padding: u28 = 0,
    }),
    /// Auxiliary Cache Control register
    /// offset: 0x0c
    CACR: mmio.Mmio(packed struct(u32) {
        /// SIWT
        SIWT: u1,
        /// ECCEN
        ECCEN: u1,
        /// FORCEWT
        FORCEWT: u1,
        padding: u29 = 0,
    }),
    /// AHB Slave Control register
    /// offset: 0x10
    AHBSCR: mmio.Mmio(packed struct(u32) {
        /// CTL
        CTL: u2,
        /// TPRI
        TPRI: u9,
        /// INITCOUNT
        INITCOUNT: u5,
        padding: u16 = 0,
    }),
    /// offset: 0x14
    reserved20: [4]u8,
    /// Auxiliary Bus Fault Status register
    /// offset: 0x18
    ABFSR: mmio.Mmio(packed struct(u32) {
        /// ITCM
        ITCM: u1,
        /// DTCM
        DTCM: u1,
        /// AHBP
        AHBP: u1,
        /// AXIM
        AXIM: u1,
        /// EPPB
        EPPB: u1,
        reserved8: u3 = 0,
        /// AXIMTYPE
        AXIMTYPE: u2,
        padding: u22 = 0,
    }),
};
