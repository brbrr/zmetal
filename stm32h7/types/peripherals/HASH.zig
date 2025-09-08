const mmio = @import("mmio");
const types = @import("../../types.zig");

/// Hash processor
pub const HASH = extern struct {
    /// control register
    /// offset: 0x00
    CR: mmio.Mmio(packed struct(u32) {
        reserved2: u2 = 0,
        /// Initialize message digest calculation
        INIT: u1,
        /// DMA enable
        DMAE: u1,
        /// Data type selection
        DATATYPE: u2,
        /// Mode selection
        MODE: u1,
        /// Algorithm selection
        ALGO0: u1,
        /// Number of words already pushed
        NBW: u4,
        /// DIN not empty
        DINNE: u1,
        /// Multiple DMA Transfers
        MDMAT: u1,
        reserved16: u2 = 0,
        /// Long key selection
        LKEY: u1,
        reserved18: u1 = 0,
        /// ALGO
        ALGO1: u1,
        padding: u13 = 0,
    }),
    /// data input register
    /// offset: 0x04
    DIN: mmio.Mmio(packed struct(u32) {
        /// Data input
        DATAIN: u32,
    }),
    /// start register
    /// offset: 0x08
    STR: mmio.Mmio(packed struct(u32) {
        /// Number of valid bits in the last word of the message
        NBLW: u5,
        reserved8: u3 = 0,
        /// Digest calculation
        DCAL: u1,
        padding: u23 = 0,
    }),
    /// digest registers
    /// offset: 0x0c
    HR0: mmio.Mmio(packed struct(u32) {
        /// H0
        H0: u32,
    }),
    /// digest registers
    /// offset: 0x10
    HR1: mmio.Mmio(packed struct(u32) {
        /// H1
        H1: u32,
    }),
    /// digest registers
    /// offset: 0x14
    HR2: mmio.Mmio(packed struct(u32) {
        /// H2
        H2: u32,
    }),
    /// digest registers
    /// offset: 0x18
    HR3: mmio.Mmio(packed struct(u32) {
        /// H3
        H3: u32,
    }),
    /// digest registers
    /// offset: 0x1c
    HR4: mmio.Mmio(packed struct(u32) {
        /// H4
        H4: u32,
    }),
    /// interrupt enable register
    /// offset: 0x20
    IMR: mmio.Mmio(packed struct(u32) {
        /// Data input interrupt enable
        DINIE: u1,
        /// Digest calculation completion interrupt enable
        DCIE: u1,
        padding: u30 = 0,
    }),
    /// status register
    /// offset: 0x24
    SR: mmio.Mmio(packed struct(u32) {
        /// Data input interrupt status
        DINIS: u1,
        /// Digest calculation completion interrupt status
        DCIS: u1,
        /// DMA Status
        DMAS: u1,
        /// Busy bit
        BUSY: u1,
        padding: u28 = 0,
    }),
    /// offset: 0x28
    reserved40: [208]u8,
    /// context swap registers
    /// offset: 0xf8
    CSR0: mmio.Mmio(packed struct(u32) {
        /// CSR0
        CSR0: u32,
    }),
    /// context swap registers
    /// offset: 0xfc
    CSR1: mmio.Mmio(packed struct(u32) {
        /// CSR1
        CSR1: u32,
    }),
    /// context swap registers
    /// offset: 0x100
    CSR2: mmio.Mmio(packed struct(u32) {
        /// CSR2
        CSR2: u32,
    }),
    /// context swap registers
    /// offset: 0x104
    CSR3: mmio.Mmio(packed struct(u32) {
        /// CSR3
        CSR3: u32,
    }),
    /// context swap registers
    /// offset: 0x108
    CSR4: mmio.Mmio(packed struct(u32) {
        /// CSR4
        CSR4: u32,
    }),
    /// context swap registers
    /// offset: 0x10c
    CSR5: mmio.Mmio(packed struct(u32) {
        /// CSR5
        CSR5: u32,
    }),
    /// context swap registers
    /// offset: 0x110
    CSR6: mmio.Mmio(packed struct(u32) {
        /// CSR6
        CSR6: u32,
    }),
    /// context swap registers
    /// offset: 0x114
    CSR7: mmio.Mmio(packed struct(u32) {
        /// CSR7
        CSR7: u32,
    }),
    /// context swap registers
    /// offset: 0x118
    CSR8: mmio.Mmio(packed struct(u32) {
        /// CSR8
        CSR8: u32,
    }),
    /// context swap registers
    /// offset: 0x11c
    CSR9: mmio.Mmio(packed struct(u32) {
        /// CSR9
        CSR9: u32,
    }),
    /// context swap registers
    /// offset: 0x120
    CSR10: mmio.Mmio(packed struct(u32) {
        /// CSR10
        CSR10: u32,
    }),
    /// context swap registers
    /// offset: 0x124
    CSR11: mmio.Mmio(packed struct(u32) {
        /// CSR11
        CSR11: u32,
    }),
    /// context swap registers
    /// offset: 0x128
    CSR12: mmio.Mmio(packed struct(u32) {
        /// CSR12
        CSR12: u32,
    }),
    /// context swap registers
    /// offset: 0x12c
    CSR13: mmio.Mmio(packed struct(u32) {
        /// CSR13
        CSR13: u32,
    }),
    /// context swap registers
    /// offset: 0x130
    CSR14: mmio.Mmio(packed struct(u32) {
        /// CSR14
        CSR14: u32,
    }),
    /// context swap registers
    /// offset: 0x134
    CSR15: mmio.Mmio(packed struct(u32) {
        /// CSR15
        CSR15: u32,
    }),
    /// context swap registers
    /// offset: 0x138
    CSR16: mmio.Mmio(packed struct(u32) {
        /// CSR16
        CSR16: u32,
    }),
    /// context swap registers
    /// offset: 0x13c
    CSR17: mmio.Mmio(packed struct(u32) {
        /// CSR17
        CSR17: u32,
    }),
    /// context swap registers
    /// offset: 0x140
    CSR18: mmio.Mmio(packed struct(u32) {
        /// CSR18
        CSR18: u32,
    }),
    /// context swap registers
    /// offset: 0x144
    CSR19: mmio.Mmio(packed struct(u32) {
        /// CSR19
        CSR19: u32,
    }),
    /// context swap registers
    /// offset: 0x148
    CSR20: mmio.Mmio(packed struct(u32) {
        /// CSR20
        CSR20: u32,
    }),
    /// context swap registers
    /// offset: 0x14c
    CSR21: mmio.Mmio(packed struct(u32) {
        /// CSR21
        CSR21: u32,
    }),
    /// context swap registers
    /// offset: 0x150
    CSR22: mmio.Mmio(packed struct(u32) {
        /// CSR22
        CSR22: u32,
    }),
    /// context swap registers
    /// offset: 0x154
    CSR23: mmio.Mmio(packed struct(u32) {
        /// CSR23
        CSR23: u32,
    }),
    /// context swap registers
    /// offset: 0x158
    CSR24: mmio.Mmio(packed struct(u32) {
        /// CSR24
        CSR24: u32,
    }),
    /// context swap registers
    /// offset: 0x15c
    CSR25: mmio.Mmio(packed struct(u32) {
        /// CSR25
        CSR25: u32,
    }),
    /// context swap registers
    /// offset: 0x160
    CSR26: mmio.Mmio(packed struct(u32) {
        /// CSR26
        CSR26: u32,
    }),
    /// context swap registers
    /// offset: 0x164
    CSR27: mmio.Mmio(packed struct(u32) {
        /// CSR27
        CSR27: u32,
    }),
    /// context swap registers
    /// offset: 0x168
    CSR28: mmio.Mmio(packed struct(u32) {
        /// CSR28
        CSR28: u32,
    }),
    /// context swap registers
    /// offset: 0x16c
    CSR29: mmio.Mmio(packed struct(u32) {
        /// CSR29
        CSR29: u32,
    }),
    /// context swap registers
    /// offset: 0x170
    CSR30: mmio.Mmio(packed struct(u32) {
        /// CSR30
        CSR30: u32,
    }),
    /// context swap registers
    /// offset: 0x174
    CSR31: mmio.Mmio(packed struct(u32) {
        /// CSR31
        CSR31: u32,
    }),
    /// context swap registers
    /// offset: 0x178
    CSR32: mmio.Mmio(packed struct(u32) {
        /// CSR32
        CSR32: u32,
    }),
    /// context swap registers
    /// offset: 0x17c
    CSR33: mmio.Mmio(packed struct(u32) {
        /// CSR33
        CSR33: u32,
    }),
    /// context swap registers
    /// offset: 0x180
    CSR34: mmio.Mmio(packed struct(u32) {
        /// CSR34
        CSR34: u32,
    }),
    /// context swap registers
    /// offset: 0x184
    CSR35: mmio.Mmio(packed struct(u32) {
        /// CSR35
        CSR35: u32,
    }),
    /// context swap registers
    /// offset: 0x188
    CSR36: mmio.Mmio(packed struct(u32) {
        /// CSR36
        CSR36: u32,
    }),
    /// context swap registers
    /// offset: 0x18c
    CSR37: mmio.Mmio(packed struct(u32) {
        /// CSR37
        CSR37: u32,
    }),
    /// context swap registers
    /// offset: 0x190
    CSR38: mmio.Mmio(packed struct(u32) {
        /// CSR38
        CSR38: u32,
    }),
    /// context swap registers
    /// offset: 0x194
    CSR39: mmio.Mmio(packed struct(u32) {
        /// CSR39
        CSR39: u32,
    }),
    /// context swap registers
    /// offset: 0x198
    CSR40: mmio.Mmio(packed struct(u32) {
        /// CSR40
        CSR40: u32,
    }),
    /// context swap registers
    /// offset: 0x19c
    CSR41: mmio.Mmio(packed struct(u32) {
        /// CSR41
        CSR41: u32,
    }),
    /// context swap registers
    /// offset: 0x1a0
    CSR42: mmio.Mmio(packed struct(u32) {
        /// CSR42
        CSR42: u32,
    }),
    /// context swap registers
    /// offset: 0x1a4
    CSR43: mmio.Mmio(packed struct(u32) {
        /// CSR43
        CSR43: u32,
    }),
    /// context swap registers
    /// offset: 0x1a8
    CSR44: mmio.Mmio(packed struct(u32) {
        /// CSR44
        CSR44: u32,
    }),
    /// context swap registers
    /// offset: 0x1ac
    CSR45: mmio.Mmio(packed struct(u32) {
        /// CSR45
        CSR45: u32,
    }),
    /// context swap registers
    /// offset: 0x1b0
    CSR46: mmio.Mmio(packed struct(u32) {
        /// CSR46
        CSR46: u32,
    }),
    /// context swap registers
    /// offset: 0x1b4
    CSR47: mmio.Mmio(packed struct(u32) {
        /// CSR47
        CSR47: u32,
    }),
    /// context swap registers
    /// offset: 0x1b8
    CSR48: mmio.Mmio(packed struct(u32) {
        /// CSR48
        CSR48: u32,
    }),
    /// context swap registers
    /// offset: 0x1bc
    CSR49: mmio.Mmio(packed struct(u32) {
        /// CSR49
        CSR49: u32,
    }),
    /// context swap registers
    /// offset: 0x1c0
    CSR50: mmio.Mmio(packed struct(u32) {
        /// CSR50
        CSR50: u32,
    }),
    /// context swap registers
    /// offset: 0x1c4
    CSR51: mmio.Mmio(packed struct(u32) {
        /// CSR51
        CSR51: u32,
    }),
    /// context swap registers
    /// offset: 0x1c8
    CSR52: mmio.Mmio(packed struct(u32) {
        /// CSR52
        CSR52: u32,
    }),
    /// context swap registers
    /// offset: 0x1cc
    CSR53: mmio.Mmio(packed struct(u32) {
        /// CSR53
        CSR53: u32,
    }),
    /// offset: 0x1d0
    reserved464: [320]u8,
    /// HASH digest register
    /// offset: 0x310
    HASH_HR0: mmio.Mmio(packed struct(u32) {
        /// H0
        H0: u32,
    }),
    /// read-only
    /// offset: 0x314
    HASH_HR1: mmio.Mmio(packed struct(u32) {
        /// H1
        H1: u32,
    }),
    /// read-only
    /// offset: 0x318
    HASH_HR2: mmio.Mmio(packed struct(u32) {
        /// H2
        H2: u32,
    }),
    /// read-only
    /// offset: 0x31c
    HASH_HR3: mmio.Mmio(packed struct(u32) {
        /// H3
        H3: u32,
    }),
    /// read-only
    /// offset: 0x320
    HASH_HR4: mmio.Mmio(packed struct(u32) {
        /// H4
        H4: u32,
    }),
    /// read-only
    /// offset: 0x324
    HASH_HR5: mmio.Mmio(packed struct(u32) {
        /// H5
        H5: u32,
    }),
    /// read-only
    /// offset: 0x328
    HASH_HR6: mmio.Mmio(packed struct(u32) {
        /// H6
        H6: u32,
    }),
    /// read-only
    /// offset: 0x32c
    HASH_HR7: mmio.Mmio(packed struct(u32) {
        /// H7
        H7: u32,
    }),
};
