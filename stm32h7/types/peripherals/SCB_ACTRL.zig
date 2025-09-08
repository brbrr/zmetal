const mmio = @import("mmio");
const types = @import("../../types.zig");

/// System control block ACTLR
pub const SCB_ACTRL = extern struct {
    /// Auxiliary control register
    /// offset: 0x00
    ACTRL: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// DISFOLD
        DISFOLD: u1,
        reserved10: u7 = 0,
        /// FPEXCODIS
        FPEXCODIS: u1,
        /// DISRAMODE
        DISRAMODE: u1,
        /// DISITMATBFLUSH
        DISITMATBFLUSH: u1,
        padding: u19 = 0,
    }),
};
