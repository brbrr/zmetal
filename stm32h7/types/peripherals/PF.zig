const mz = @import("microzig");
const mmio = mz.mmio;
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

pub const CacheMaintenance = extern struct {
    /// Instruction cache invalidate all to PoU
    /// offset: 0x00 (relative to 0xE000EF50)
    ICIALLU: mmio.Mmio(u32),
    /// Reserved
    _reserved0: u32,
    /// Instruction cache invalidate by address to PoU
    ICIMVAU: mmio.Mmio(u32),
    /// Data cache invalidate by address to PoC
    DCIMVAC: mmio.Mmio(u32),
    /// Data cache invalidate by set/way
    DCISW: mmio.Mmio(packed struct(u32) {
        /// Way that operation applies to (bits 31:30)
        Way: u2,
        /// Reserved (bits 29:14)
        _reserved0: u16 = 0,
        /// Set/index that operation applies to (bits 13:5)
        Set: u9,
        /// Reserved (bits 4:1)
        _reserved1: u4 = 0,
        /// Always reads as zero (bit 0)
        _zero: u1 = 0,
    }),
    /// Data cache clean by address to PoU
    DCCMVAU: mmio.Mmio(u32),
    /// Data cache clean by address to PoC
    DCCMVAC: mmio.Mmio(u32),
    /// Data cache clean by set/way
    DCCSW: mmio.Mmio(u32),
    /// Data cache clean and invalidate by address to PoC
    DCCIMVAC: mmio.Mmio(u32),
    /// Data cache clean and invalidate by set/way
    DCCISW: mmio.Mmio(u32),
    /// BPIALL register (RAZ/WI, not implemented)
    BPIALL: mmio.Mmio(u32),
};
