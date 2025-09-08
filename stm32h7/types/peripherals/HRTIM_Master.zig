const mmio = @import("mmio");
const types = @import("../../types.zig");

/// High Resolution Timer: Master Timers
pub const HRTIM_Master = extern struct {
    /// Master Timer Control Register
    /// offset: 0x00
    MCR: mmio.Mmio(packed struct(u32) {
        /// HRTIM Master Clock prescaler
        CK_PSC: u3,
        /// Master Continuous mode
        CONT: u1,
        /// Master Re-triggerable mode
        RETRIG: u1,
        /// Half mode enable
        HALF: u1,
        reserved8: u2 = 0,
        /// ynchronization input
        SYNC_IN: u2,
        /// Synchronization Resets Master
        SYNCRSTM: u1,
        /// Synchronization Starts Master
        SYNCSTRTM: u1,
        /// Synchronization output
        SYNC_OUT: u2,
        /// Synchronization source
        SYNC_SRC: u2,
        /// Master Counter enable
        MCEN: u1,
        /// Timer A counter enable
        TACEN: u1,
        /// Timer B counter enable
        TBCEN: u1,
        /// Timer C counter enable
        TCCEN: u1,
        /// Timer D counter enable
        TDCEN: u1,
        /// Timer E counter enable
        TECEN: u1,
        reserved25: u3 = 0,
        /// AC Synchronization
        DACSYNC: u2,
        /// Preload enable
        PREEN: u1,
        reserved29: u1 = 0,
        /// Master Timer Repetition update
        MREPU: u1,
        /// Burst DMA Update
        BRSTDMA: u2,
    }),
    /// Master Timer Interrupt Status Register
    /// offset: 0x04
    MISR: mmio.Mmio(packed struct(u32) {
        /// Master Compare 1 Interrupt Flag
        MCMP1: u1,
        /// Master Compare 2 Interrupt Flag
        MCMP2: u1,
        /// Master Compare 3 Interrupt Flag
        MCMP3: u1,
        /// Master Compare 4 Interrupt Flag
        MCMP4: u1,
        /// Master Repetition Interrupt Flag
        MREP: u1,
        /// Sync Input Interrupt Flag
        SYNC: u1,
        /// Master Update Interrupt Flag
        MUPD: u1,
        padding: u25 = 0,
    }),
    /// Master Timer Interrupt Clear Register
    /// offset: 0x08
    MICR: mmio.Mmio(packed struct(u32) {
        /// Master Compare 1 Interrupt flag clear
        MCMP1C: u1,
        /// Master Compare 2 Interrupt flag clear
        MCMP2C: u1,
        /// Master Compare 3 Interrupt flag clear
        MCMP3C: u1,
        /// Master Compare 4 Interrupt flag clear
        MCMP4C: u1,
        /// Repetition Interrupt flag clear
        MREPC: u1,
        /// Sync Input Interrupt flag clear
        SYNCC: u1,
        /// Master update Interrupt flag clear
        MUPDC: u1,
        padding: u25 = 0,
    }),
    /// MDIER4
    /// offset: 0x0c
    MDIER4: mmio.Mmio(packed struct(u32) {
        /// MCMP1IE
        MCMP1IE: u1,
        /// MCMP2IE
        MCMP2IE: u1,
        /// MCMP3IE
        MCMP3IE: u1,
        /// MCMP4IE
        MCMP4IE: u1,
        /// MREPIE
        MREPIE: u1,
        /// SYNCIE
        SYNCIE: u1,
        /// MUPDIE
        MUPDIE: u1,
        reserved16: u9 = 0,
        /// MCMP1DE
        MCMP1DE: u1,
        /// MCMP2DE
        MCMP2DE: u1,
        /// MCMP3DE
        MCMP3DE: u1,
        /// MCMP4DE
        MCMP4DE: u1,
        /// MREPDE
        MREPDE: u1,
        /// SYNCDE
        SYNCDE: u1,
        /// MUPDDE
        MUPDDE: u1,
        padding: u9 = 0,
    }),
    /// Master Timer Counter Register
    /// offset: 0x10
    MCNTR: mmio.Mmio(packed struct(u32) {
        /// Counter value
        MCNT: u16,
        padding: u16 = 0,
    }),
    /// Master Timer Period Register
    /// offset: 0x14
    MPER: mmio.Mmio(packed struct(u32) {
        /// Master Timer Period value
        MPER: u16,
        padding: u16 = 0,
    }),
    /// Master Timer Repetition Register
    /// offset: 0x18
    MREP: mmio.Mmio(packed struct(u32) {
        /// Master Timer Repetition counter value
        MREP: u8,
        padding: u24 = 0,
    }),
    /// Master Timer Compare 1 Register
    /// offset: 0x1c
    MCMP1R: mmio.Mmio(packed struct(u32) {
        /// Master Timer Compare 1 value
        MCMP1: u16,
        padding: u16 = 0,
    }),
    /// offset: 0x20
    reserved32: [4]u8,
    /// Master Timer Compare 2 Register
    /// offset: 0x24
    MCMP2R: mmio.Mmio(packed struct(u32) {
        /// Master Timer Compare 2 value
        MCMP2: u16,
        padding: u16 = 0,
    }),
    /// Master Timer Compare 3 Register
    /// offset: 0x28
    MCMP3R: mmio.Mmio(packed struct(u32) {
        /// Master Timer Compare 3 value
        MCMP3: u16,
        padding: u16 = 0,
    }),
    /// Master Timer Compare 4 Register
    /// offset: 0x2c
    MCMP4R: mmio.Mmio(packed struct(u32) {
        /// Master Timer Compare 4 value
        MCMP4: u16,
        padding: u16 = 0,
    }),
};
