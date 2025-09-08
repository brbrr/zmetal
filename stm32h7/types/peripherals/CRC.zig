const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Cryptographic processor
pub const CRC = extern struct {
    /// Data register
    /// offset: 0x00
    DR: mmio.Mmio(packed struct(u32) {
        /// Data Register
        DR: u32,
    }),
    /// Independent Data register
    /// offset: 0x04
    IDR: mmio.Mmio(packed struct(u32) {
        /// Independent Data register
        IDR: u32,
    }),
    /// Control register
    /// offset: 0x08
    CR: mmio.Mmio(packed struct(u32) {
        /// RESET bit
        RESET: u1,
        reserved3: u2 = 0,
        /// Polynomial size
        POLYSIZE: u2,
        /// Reverse input data
        REV_IN: u2,
        /// Reverse output data
        REV_OUT: u1,
        padding: u24 = 0,
    }),
    /// Initial CRC value
    /// offset: 0x0c
    INIT: mmio.Mmio(packed struct(u32) {
        /// Programmable initial CRC value
        CRC_INIT: u32,
    }),
    /// CRC polynomial
    /// offset: 0x10
    POL: mmio.Mmio(packed struct(u32) {
        /// Programmable polynomial
        POL: u32,
    }),
};
