const mmio = @import("mmio");
const types = @import("../../types.zig");

/// HSEM
pub const HSEM = extern struct {
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x00
    HSEM_R0: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x04
    HSEM_R1: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x08
    HSEM_R2: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x0c
    HSEM_R3: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x10
    HSEM_R4: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x14
    HSEM_R5: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x18
    HSEM_R6: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x1c
    HSEM_R7: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x20
    HSEM_R8: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x24
    HSEM_R9: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x28
    HSEM_R10: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x2c
    HSEM_R11: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x30
    HSEM_R12: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x34
    HSEM_R13: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x38
    HSEM_R14: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x3c
    HSEM_R15: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x40
    HSEM_R16: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x44
    HSEM_R17: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x48
    HSEM_R18: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x4c
    HSEM_R19: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x50
    HSEM_R20: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x54
    HSEM_R21: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x58
    HSEM_R22: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x5c
    HSEM_R23: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x60
    HSEM_R24: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x64
    HSEM_R25: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x68
    HSEM_R26: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x6c
    HSEM_R27: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x70
    HSEM_R28: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x74
    HSEM_R29: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x78
    HSEM_R30: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM register HSEM_R0 HSEM_R31
    /// offset: 0x7c
    HSEM_R31: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x80
    HSEM_RLR0: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x84
    HSEM_RLR1: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x88
    HSEM_RLR2: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x8c
    HSEM_RLR3: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x90
    HSEM_RLR4: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x94
    HSEM_RLR5: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x98
    HSEM_RLR6: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0x9c
    HSEM_RLR7: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xa0
    HSEM_RLR8: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xa4
    HSEM_RLR9: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xa8
    HSEM_RLR10: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xac
    HSEM_RLR11: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xb0
    HSEM_RLR12: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xb4
    HSEM_RLR13: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xb8
    HSEM_RLR14: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xbc
    HSEM_RLR15: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xc0
    HSEM_RLR16: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xc4
    HSEM_RLR17: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xc8
    HSEM_RLR18: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xcc
    HSEM_RLR19: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xd0
    HSEM_RLR20: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xd4
    HSEM_RLR21: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xd8
    HSEM_RLR22: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xdc
    HSEM_RLR23: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xe0
    HSEM_RLR24: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xe4
    HSEM_RLR25: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xe8
    HSEM_RLR26: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xec
    HSEM_RLR27: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xf0
    HSEM_RLR28: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xf4
    HSEM_RLR29: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xf8
    HSEM_RLR30: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Read lock register
    /// offset: 0xfc
    HSEM_RLR31: mmio.Mmio(packed struct(u32) {
        /// Semaphore ProcessID
        PROCID: u8,
        /// Semaphore MasterID
        MASTERID: u8,
        reserved31: u15 = 0,
        /// Lock indication
        LOCK: u1,
    }),
    /// HSEM Interrupt enable register
    /// offset: 0x100
    HSEM_IER: mmio.Mmio(packed struct(u32) {
        /// Interrupt semaphore n enable bit
        ISEM0: u1,
        /// Interrupt semaphore n enable bit
        ISEM1: u1,
        /// Interrupt semaphore n enable bit
        ISEM2: u1,
        /// Interrupt semaphore n enable bit
        ISEM3: u1,
        /// Interrupt semaphore n enable bit
        ISEM4: u1,
        /// Interrupt semaphore n enable bit
        ISEM5: u1,
        /// Interrupt semaphore n enable bit
        ISEM6: u1,
        /// Interrupt semaphore n enable bit
        ISEM7: u1,
        /// Interrupt semaphore n enable bit
        ISEM8: u1,
        /// Interrupt semaphore n enable bit
        ISEM9: u1,
        /// Interrupt semaphore n enable bit
        ISEM10: u1,
        /// Interrupt semaphore n enable bit
        ISEM11: u1,
        /// Interrupt semaphore n enable bit
        ISEM12: u1,
        /// Interrupt semaphore n enable bit
        ISEM13: u1,
        /// Interrupt semaphore n enable bit
        ISEM14: u1,
        /// Interrupt semaphore n enable bit
        ISEM15: u1,
        /// Interrupt semaphore n enable bit
        ISEM16: u1,
        /// Interrupt semaphore n enable bit
        ISEM17: u1,
        /// Interrupt semaphore n enable bit
        ISEM18: u1,
        /// Interrupt semaphore n enable bit
        ISEM19: u1,
        /// Interrupt semaphore n enable bit
        ISEM20: u1,
        /// Interrupt semaphore n enable bit
        ISEM21: u1,
        /// Interrupt semaphore n enable bit
        ISEM22: u1,
        /// Interrupt semaphore n enable bit
        ISEM23: u1,
        /// Interrupt semaphore n enable bit
        ISEM24: u1,
        /// Interrupt semaphore n enable bit
        ISEM25: u1,
        /// Interrupt semaphore n enable bit
        ISEM26: u1,
        /// Interrupt semaphore n enable bit
        ISEM27: u1,
        /// Interrupt semaphore n enable bit
        ISEM28: u1,
        /// Interrupt semaphore n enable bit
        ISEM29: u1,
        /// Interrupt semaphore n enable bit
        ISEM30: u1,
        /// Interrupt(N) semaphore n enable bit.
        ISEM31: u1,
    }),
    /// HSEM Interrupt clear register
    /// offset: 0x104
    HSEM_ICR: mmio.Mmio(packed struct(u32) {
        /// Interrupt(N) semaphore n clear bit
        ISEM0: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM1: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM2: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM3: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM4: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM5: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM6: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM7: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM8: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM9: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM10: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM11: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM12: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM13: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM14: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM15: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM16: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM17: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM18: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM19: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM20: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM21: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM22: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM23: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM24: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM25: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM26: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM27: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM28: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM29: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM30: u1,
        /// Interrupt(N) semaphore n clear bit
        ISEM31: u1,
    }),
    /// HSEM Interrupt status register
    /// offset: 0x108
    HSEM_ISR: mmio.Mmio(packed struct(u32) {
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM0: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM1: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM2: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM3: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM4: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM5: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM6: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM7: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM8: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM9: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM10: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM11: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM12: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM13: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM14: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM15: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM16: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM17: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM18: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM19: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM20: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM21: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM22: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM23: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM24: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM25: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM26: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM27: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM28: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM29: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM30: u1,
        /// Interrupt(N) semaphore n status bit before enable (mask)
        ISEM31: u1,
    }),
    /// HSEM Masked interrupt status register
    /// offset: 0x10c
    HSEM_MISR: mmio.Mmio(packed struct(u32) {
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM0: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM1: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM2: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM3: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM4: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM5: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM6: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM7: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM8: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM9: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM10: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM11: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM12: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM13: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM14: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM15: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM16: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM17: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM18: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM19: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM20: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM21: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM22: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM23: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM24: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM25: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM26: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM27: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM28: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM29: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM30: u1,
        /// masked interrupt(N) semaphore n status bit after enable (mask)
        ISEM31: u1,
    }),
    /// offset: 0x110
    reserved272: [48]u8,
    /// HSEM Clear register
    /// offset: 0x140
    HSEM_CR: mmio.Mmio(packed struct(u32) {
        reserved8: u8 = 0,
        /// MasterID of semaphores to be cleared
        MASTERID: u8,
        /// Semaphore clear Key
        KEY: u16,
    }),
    /// HSEM Interrupt clear register
    /// offset: 0x144
    HSEM_KEYR: mmio.Mmio(packed struct(u32) {
        reserved16: u16 = 0,
        /// Semaphore Clear Key
        KEY: u16,
    }),
};
