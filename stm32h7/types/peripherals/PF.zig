const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Processor features
pub const PF = extern struct {
    /// Cache Level ID register
    /// offset: 0x00
    CLIDR: mmio.Mmio(packed struct(u32) {
        /// CL1
        CL1: u3,
        /// CL2
        CL2: u3,
        /// CL3
        CL3: u3,
        /// CL4
        CL4: u3,
        /// CL5
        CL5: u3,
        /// CL6
        CL6: u3,
        /// CL7
        CL7: u3,
        /// LoUIS
        LoUIS: u3,
        /// LoC
        LoC: u3,
        /// LoU
        LoU: u3,
        padding: u2 = 0,
    }),
    /// Cache Type register
    /// offset: 0x04
    CTR: mmio.Mmio(packed struct(u32) {
        /// IminLine
        _IminLine: u4,
        reserved16: u12 = 0,
        /// DMinLine
        DMinLine: u4,
        /// ERG
        ERG: u4,
        /// CWG
        CWG: u4,
        reserved29: u1 = 0,
        /// Format
        Format: u3,
    }),
    /// Cache Size ID register
    /// offset: 0x08
    CCSIDR: mmio.Mmio(packed struct(u32) {
        /// LineSize
        LineSize: u3,
        /// Associativity
        Associativity: u10,
        /// NumSets
        NumSets: u15,
        /// WA
        WA: u1,
        /// RA
        RA: u1,
        /// WB
        WB: u1,
        /// WT
        WT: u1,
    }),
};
