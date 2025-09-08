const mmio = @import("mmio");
const types = @import("../../types.zig");

/// DELAY_Block_SDMMC1
pub const DELAY_Block_SDMMC1 = extern struct {
    /// DLYB control register
    /// offset: 0x00
    CR: mmio.Mmio(packed struct(u32) {
        /// Delay block enable bit
        DEN: u1,
        /// Sampler length enable bit
        SEN: u1,
        padding: u30 = 0,
    }),
    /// DLYB configuration register
    /// offset: 0x04
    CFGR: mmio.Mmio(packed struct(u32) {
        /// Select the phase for the Output clock
        SEL: u4,
        reserved8: u4 = 0,
        /// Delay Defines the delay of a Unit delay cell
        UNIT: u7,
        reserved16: u1 = 0,
        /// Delay line length value
        LNG: u12,
        reserved31: u3 = 0,
        /// Length valid flag
        LNGF: u1,
    }),
};
