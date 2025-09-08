const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Microcontroller Debug Unit
pub const DBGMCU = extern struct {
    /// DBGMCU Identity Code Register
    /// offset: 0x00
    IDC: mmio.Mmio(packed struct(u32) {
        /// Device ID
        DEV_ID: u12,
        reserved16: u4 = 0,
        /// Revision
        REV_ID: u16,
    }),
    /// DBGMCU Configuration Register
    /// offset: 0x04
    CR: mmio.Mmio(packed struct(u32) {
        /// Allow D1 domain debug in Sleep mode
        DBGSLEEP_D1: u1,
        /// Allow D1 domain debug in Stop mode
        DBGSTOP_D1: u1,
        /// Allow D1 domain debug in Standby mode
        DBGSTBY_D1: u1,
        /// Allow D2 domain debug in Sleep mode
        DBGSLEEP_D2: u1,
        /// Allow D2 domain debug in Stop mode
        DBGSTOP_D2: u1,
        /// Allow D2 domain debug in Standby mode
        DBGSTBY_D2: u1,
        reserved7: u1 = 0,
        /// Allow debug in D3 Stop mode
        DBGSTOP_D3: u1,
        /// Allow debug in D3 Standby mode
        DBGSTBY_D3: u1,
        reserved20: u11 = 0,
        /// Trace port clock enable
        TRACECLKEN: u1,
        /// D1 debug clock enable
        D1DBGCKEN: u1,
        /// D3 debug clock enable
        D3DBGCKEN: u1,
        reserved28: u5 = 0,
        /// External trigger output enable
        TRGOEN: u1,
        padding: u3 = 0,
    }),
    /// offset: 0x08
    reserved8: [44]u8,
    /// DBGMCU APB3 peripheral freeze register
    /// offset: 0x34
    APB3FZ1: mmio.Mmio(packed struct(u32) {
        reserved6: u6 = 0,
        /// WWDG1 stop in debug
        WWDG1: u1,
        padding: u25 = 0,
    }),
    /// offset: 0x38
    reserved56: [4]u8,
    /// DBGMCU APB1L peripheral freeze register
    /// offset: 0x3c
    APB1LFZ1: mmio.Mmio(packed struct(u32) {
        /// TIM2 stop in debug
        DBG_TIM2: u1,
        /// TIM3 stop in debug
        DBG_TIM3: u1,
        /// TIM4 stop in debug
        DBG_TIM4: u1,
        /// TIM5 stop in debug
        DBG_TIM5: u1,
        /// TIM6 stop in debug
        DBG_TIM6: u1,
        /// TIM7 stop in debug
        DBG_TIM7: u1,
        /// TIM12 stop in debug
        DBG_TIM12: u1,
        /// TIM13 stop in debug
        DBG_TIM13: u1,
        /// TIM14 stop in debug
        DBG_TIM14: u1,
        /// LPTIM1 stop in debug
        DBG_LPTIM1: u1,
        reserved21: u11 = 0,
        /// I2C1 SMBUS timeout stop in debug
        DBG_I2C1: u1,
        /// I2C2 SMBUS timeout stop in debug
        DBG_I2C2: u1,
        /// I2C3 SMBUS timeout stop in debug
        DBG_I2C3: u1,
        padding: u8 = 0,
    }),
    /// offset: 0x40
    reserved64: [12]u8,
    /// DBGMCU APB2 peripheral freeze register
    /// offset: 0x4c
    APB2FZ1: mmio.Mmio(packed struct(u32) {
        /// TIM1 stop in debug
        DBG_TIM1: u1,
        /// TIM8 stop in debug
        DBG_TIM8: u1,
        reserved16: u14 = 0,
        /// TIM15 stop in debug
        DBG_TIM15: u1,
        /// TIM16 stop in debug
        DBG_TIM16: u1,
        /// TIM17 stop in debug
        DBG_TIM17: u1,
        reserved29: u10 = 0,
        /// HRTIM stop in debug
        DBG_HRTIM: u1,
        padding: u2 = 0,
    }),
    /// offset: 0x50
    reserved80: [4]u8,
    /// DBGMCU APB4 peripheral freeze register
    /// offset: 0x54
    APB4FZ1: mmio.Mmio(packed struct(u32) {
        reserved7: u7 = 0,
        /// I2C4 SMBUS timeout stop in debug
        DBG_I2C4: u1,
        reserved9: u1 = 0,
        /// LPTIM2 stop in debug
        DBG_LPTIM2: u1,
        /// LPTIM2 stop in debug
        DBG_LPTIM3: u1,
        /// LPTIM4 stop in debug
        DBG_LPTIM4: u1,
        /// LPTIM5 stop in debug
        DBG_LPTIM5: u1,
        reserved16: u3 = 0,
        /// RTC stop in debug
        DBG_RTC: u1,
        reserved18: u1 = 0,
        /// Independent watchdog for D1 stop in debug
        DBG_WDGLSD1: u1,
        padding: u13 = 0,
    }),
};
