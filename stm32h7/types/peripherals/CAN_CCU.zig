const mmio = @import("mmio");
const types = @import("../../types.zig");

/// CCU registers
pub const CAN_CCU = extern struct {
    /// Clock Calibration Unit Core Release Register
    /// offset: 0x00
    CREL: mmio.Mmio(packed struct(u32) {
        /// Time Stamp Day
        DAY: u8,
        /// Time Stamp Month
        MON: u8,
        /// Time Stamp Year
        YEAR: u4,
        /// Sub-step of Core Release
        SUBSTEP: u4,
        /// Step of Core Release
        STEP: u4,
        /// Core Release
        REL: u4,
    }),
    /// Calibration Configuration Register
    /// offset: 0x04
    CCFG: mmio.Mmio(packed struct(u32) {
        /// Time Quanta per Bit Time
        TQBT: u5,
        reserved6: u1 = 0,
        /// Bypass Clock Calibration
        BCC: u1,
        /// Calibration Field Length
        CFL: u1,
        /// Oscillator Clock Periods Minimum
        OCPM: u8,
        /// Clock Divider
        CDIV: u4,
        reserved31: u11 = 0,
        /// Software Reset
        SWR: u1,
    }),
    /// Calibration Status Register
    /// offset: 0x08
    CSTAT: mmio.Mmio(packed struct(u32) {
        /// Oscillator Clock Period Counter
        OCPC: u18,
        /// Time Quanta Counter
        TQC: u11,
        reserved30: u1 = 0,
        /// Calibration State
        CALS: u2,
    }),
    /// Calibration Watchdog Register
    /// offset: 0x0c
    CWD: mmio.Mmio(packed struct(u32) {
        /// WDC
        WDC: u16,
        /// WDV
        WDV: u16,
    }),
    /// Clock Calibration Unit Interrupt Register
    /// offset: 0x10
    IR: mmio.Mmio(packed struct(u32) {
        /// Calibration Watchdog Event
        CWE: u1,
        /// Calibration State Changed
        CSC: u1,
        padding: u30 = 0,
    }),
    /// Clock Calibration Unit Interrupt Enable Register
    /// offset: 0x14
    IE: mmio.Mmio(packed struct(u32) {
        /// Calibration Watchdog Event Enable
        CWEE: u1,
        /// Calibration State Changed Enable
        CSCE: u1,
        padding: u30 = 0,
    }),
};
