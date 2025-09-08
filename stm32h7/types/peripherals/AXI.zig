const mmio = @import("mmio");
const types = @import("../../types.zig");

/// AXI interconnect registers
pub const AXI = extern struct {
    /// offset: 0x00
    reserved0: [8144]u8,
    /// AXI interconnect - peripheral ID4 register
    /// offset: 0x1fd0
    AXI_PERIPH_ID_4: mmio.Mmio(packed struct(u32) {
        /// JEP106 continuation code
        JEP106CON: u4,
        /// Register file size
        KCOUNT4: u4,
        padding: u24 = 0,
    }),
    /// offset: 0x1fd4
    reserved8148: [12]u8,
    /// AXI interconnect - peripheral ID0 register
    /// offset: 0x1fe0
    AXI_PERIPH_ID_0: mmio.Mmio(packed struct(u32) {
        /// Peripheral part number bits 0 to 7
        PARTNUM: u8,
        padding: u24 = 0,
    }),
    /// AXI interconnect - peripheral ID1 register
    /// offset: 0x1fe4
    AXI_PERIPH_ID_1: mmio.Mmio(packed struct(u32) {
        /// Peripheral part number bits 8 to 11
        PARTNUM: u4,
        /// JEP106 identity bits 0 to 3
        JEP106I: u4,
        padding: u24 = 0,
    }),
    /// AXI interconnect - peripheral ID2 register
    /// offset: 0x1fe8
    AXI_PERIPH_ID_2: mmio.Mmio(packed struct(u32) {
        /// JEP106 Identity bits 4 to 6
        JEP106ID: u3,
        /// JEP106 code flag
        JEDEC: u1,
        /// Peripheral revision number
        REVISION: u4,
        padding: u24 = 0,
    }),
    /// AXI interconnect - peripheral ID3 register
    /// offset: 0x1fec
    AXI_PERIPH_ID_3: mmio.Mmio(packed struct(u32) {
        /// Customer modification
        CUST_MOD_NUM: u4,
        /// Customer version
        REV_AND: u4,
        padding: u24 = 0,
    }),
    /// AXI interconnect - component ID0 register
    /// offset: 0x1ff0
    AXI_COMP_ID_0: mmio.Mmio(packed struct(u32) {
        /// Preamble bits 0 to 7
        PREAMBLE: u8,
        padding: u24 = 0,
    }),
    /// AXI interconnect - component ID1 register
    /// offset: 0x1ff4
    AXI_COMP_ID_1: mmio.Mmio(packed struct(u32) {
        /// Preamble bits 8 to 11
        PREAMBLE: u4,
        /// Component class
        CLASS: u4,
        padding: u24 = 0,
    }),
    /// AXI interconnect - component ID2 register
    /// offset: 0x1ff8
    AXI_COMP_ID_2: mmio.Mmio(packed struct(u32) {
        /// Preamble bits 12 to 19
        PREAMBLE: u8,
        padding: u24 = 0,
    }),
    /// AXI interconnect - component ID3 register
    /// offset: 0x1ffc
    AXI_COMP_ID_3: mmio.Mmio(packed struct(u32) {
        /// Preamble bits 20 to 27
        PREAMBLE: u8,
        padding: u24 = 0,
    }),
    /// offset: 0x2000
    reserved8192: [8]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x2008
    AXI_TARG1_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x200c
    reserved8204: [24]u8,
    /// AXI interconnect - TARG x bus matrix functionality 2 register
    /// offset: 0x2024
    AXI_TARG1_FN_MOD2: mmio.Mmio(packed struct(u32) {
        /// Disable packing of beats to match the output data width
        BYPASS_MERGE: u1,
        padding: u31 = 0,
    }),
    /// offset: 0x2028
    reserved8232: [4]u8,
    /// AXI interconnect - TARG x long burst functionality modification
    /// offset: 0x202c
    AXI_TARG1_FN_MOD_LB: mmio.Mmio(packed struct(u32) {
        /// Controls burst breaking of long bursts
        FN_MOD_LB: u1,
        padding: u31 = 0,
    }),
    /// offset: 0x2030
    reserved8240: [216]u8,
    /// AXI interconnect - TARG x long burst functionality modification
    /// offset: 0x2108
    AXI_TARG1_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override AMIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override AMIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x210c
    reserved8460: [3836]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x3008
    AXI_TARG2_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x300c
    reserved12300: [24]u8,
    /// AXI interconnect - TARG x bus matrix functionality 2 register
    /// offset: 0x3024
    AXI_TARG2_FN_MOD2: mmio.Mmio(packed struct(u32) {
        /// Disable packing of beats to match the output data width
        BYPASS_MERGE: u1,
        padding: u31 = 0,
    }),
    /// offset: 0x3028
    reserved12328: [4]u8,
    /// AXI interconnect - TARG x long burst functionality modification
    /// offset: 0x302c
    AXI_TARG2_FN_MOD_LB: mmio.Mmio(packed struct(u32) {
        /// Controls burst breaking of long bursts
        FN_MOD_LB: u1,
        padding: u31 = 0,
    }),
    /// offset: 0x3030
    reserved12336: [216]u8,
    /// AXI interconnect - TARG x long burst functionality modification
    /// offset: 0x3108
    AXI_TARG2_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override AMIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override AMIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x310c
    reserved12556: [3836]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x4008
    AXI_TARG3_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x400c
    reserved16396: [4092]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x5008
    AXI_TARG4_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x500c
    reserved20492: [4092]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x6008
    AXI_TARG5_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x600c
    reserved24588: [4092]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x7008
    AXI_TARG6_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x700c
    reserved28684: [4096]u8,
    /// AXI interconnect - TARG x bus matrix issuing functionality register
    /// offset: 0x800c
    AXI_TARG7_FN_MOD_ISS_BM: mmio.Mmio(packed struct(u32) {
        /// READ_ISS_OVERRIDE
        READ_ISS_OVERRIDE: u1,
        /// Switch matrix write issuing override for target
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x8010
    reserved32784: [20]u8,
    /// AXI interconnect - TARG x bus matrix functionality 2 register
    /// offset: 0x8024
    AXI_TARG7_FN_MOD2: mmio.Mmio(packed struct(u32) {
        /// Disable packing of beats to match the output data width
        BYPASS_MERGE: u1,
        padding: u31 = 0,
    }),
    /// offset: 0x8028
    reserved32808: [224]u8,
    /// AXI interconnect - TARG x long burst functionality modification
    /// offset: 0x8108
    AXI_TARG7_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override AMIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override AMIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x810c
    reserved33036: [237336]u8,
    /// AXI interconnect - INI x functionality modification 2 register
    /// offset: 0x42024
    AXI_INI1_FN_MOD2: mmio.Mmio(packed struct(u32) {
        /// Disables alteration of transactions by the up-sizer unless required by the protocol
        BYPASS_MERGE: u1,
        padding: u31 = 0,
    }),
    /// AXI interconnect - INI x AHB functionality modification register
    /// offset: 0x42028
    AXI_INI1_FN_MOD_AHB: mmio.Mmio(packed struct(u32) {
        /// Converts all AHB-Lite write transactions to a series of single beat AXI
        RD_INC_OVERRIDE: u1,
        /// Converts all AHB-Lite read transactions to a series of single beat AXI
        WR_INC_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4202c
    reserved270380: [212]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x42100
    AXI_INI1_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x42104
    AXI_INI1_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x42108
    AXI_INI1_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4210c
    reserved270604: [4084]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x43100
    AXI_INI2_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x43104
    AXI_INI2_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x43108
    AXI_INI2_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4310c
    reserved274700: [3864]u8,
    /// AXI interconnect - INI x functionality modification 2 register
    /// offset: 0x44024
    AXI_INI3_FN_MOD2: mmio.Mmio(packed struct(u32) {
        /// Disables alteration of transactions by the up-sizer unless required by the protocol
        BYPASS_MERGE: u1,
        padding: u31 = 0,
    }),
    /// AXI interconnect - INI x AHB functionality modification register
    /// offset: 0x44028
    AXI_INI3_FN_MOD_AHB: mmio.Mmio(packed struct(u32) {
        /// Converts all AHB-Lite write transactions to a series of single beat AXI
        RD_INC_OVERRIDE: u1,
        /// Converts all AHB-Lite read transactions to a series of single beat AXI
        WR_INC_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4402c
    reserved278572: [212]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x44100
    AXI_INI3_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x44104
    AXI_INI3_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x44108
    AXI_INI3_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4410c
    reserved278796: [4084]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x45100
    AXI_INI4_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x45104
    AXI_INI4_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x45108
    AXI_INI4_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4510c
    reserved282892: [4084]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x46100
    AXI_INI5_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x46104
    AXI_INI5_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x46108
    AXI_INI5_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
    /// offset: 0x4610c
    reserved286988: [4084]u8,
    /// AXI interconnect - INI x read QoS register
    /// offset: 0x47100
    AXI_INI6_READ_QOS: mmio.Mmio(packed struct(u32) {
        /// Read channel QoS setting
        AR_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x write QoS register
    /// offset: 0x47104
    AXI_INI6_WRITE_QOS: mmio.Mmio(packed struct(u32) {
        /// Write channel QoS setting
        AW_QOS: u4,
        padding: u28 = 0,
    }),
    /// AXI interconnect - INI x issuing functionality modification register
    /// offset: 0x47108
    AXI_INI6_FN_MOD: mmio.Mmio(packed struct(u32) {
        /// Override ASIB read issuing capability
        READ_ISS_OVERRIDE: u1,
        /// Override ASIB write issuing capability
        WRITE_ISS_OVERRIDE: u1,
        padding: u30 = 0,
    }),
};
