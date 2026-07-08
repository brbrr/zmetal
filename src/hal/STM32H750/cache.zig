const std = @import("std");
const microzig = @import("microzig");
const cpu = microzig.cpu;
const comptimePrint = std.fmt.comptimePrint;
const scb = microzig.cpu.peripherals.scb;
const pf = microzig.chip.peripherals.PF;
const cache_m = microzig.chip.peripherals.CACHE;

pub inline fn enableICache() void {
    if (scb.CCR.read().IC != 0) return; // already enabled

    cpu.dsb();
    cpu.isb();
    // invalidate I-Cache
    cache_m.ICIALLU.raw = 0;
    cpu.dsb();
    cpu.isb();
    scb.CCR.modify_one("IC", 1);
    cpu.dsb();
    cpu.isb();
}

pub fn disableICache() void {
    cpu.dsb();
    cpu.isb();
    scb.CCR.modify_one("IC", 0);
    // invalidate I-Cache
    cache_m.ICIALLU.raw = 0;
    cpu.dsb();
    cpu.isb();
}

const SCB_DCISW_SET_Pos = 5;
const SCB_DCISW_SET_Msk = (0x1FF << SCB_DCISW_SET_Pos);
const SCB_DCISW_WAY_Pos = 30;
const SCB_DCISW_WAY_Msk = (0x3 << SCB_DCISW_WAY_Pos);

pub inline fn enableDCache() void {
    if (scb.CCR.read().DC != 0) unreachable; // already enabled

    scb.CSSELR = 0; // select Level 1 data cache
    cpu.dsb();

    var sets: u32 = pf.CCSIDR.read().NumSets;
    // (ccsidr & SCB_CCSIDR_NUMSETS_Msk) >> SCB_CCSIDR_NUMSETS_Pos;
    while (true) {
        var ways: u32 = pf.CCSIDR.read().Associativity;
        while (true) {
            cache_m.DCISW.raw =
                ((sets << SCB_DCISW_SET_Pos) & SCB_DCISW_SET_Msk) |
                ((ways << SCB_DCISW_WAY_Pos) & SCB_DCISW_WAY_Msk);

            if (ways == 0) break;
            ways -= 1;
        }
        if (sets == 0) break;
        sets -= 1;
    }
    cpu.dsb();

    scb.CCR.modify(.{ .DC = 1 }); // enable D-Cache
    cpu.dsb();
    cpu.isb();
}

pub inline fn disableDCache() void {
    if (scb.CCR.read().DC == 0) return; // already disabled
    scb.CSSELR.raw = 0; // select Level 1 data cache
    cpu.dsb();

    scb.CCR.modify(.{ .DC = 0 }); // disable D-Cache
    cpu.dsb();

    var sets: u32 = pf.CCSIDR.read().NumSets;
    while (true) {
        var ways: u32 = pf.CCSIDR.read().Associativity;
        while (true) {
            cache_m.DCCISW.raw =
                ((sets << SCB_DCISW_SET_Pos) & SCB_DCISW_SET_Msk) |
                ((ways << SCB_DCISW_WAY_Pos) & SCB_DCISW_WAY_Msk);

            if (ways == 0) break;
            ways -= 1;
        }
        if (sets == 0) break;
        sets -= 1;
    }
    cpu.dsb();
    cpu.isb();
}

// Before starting DMA transfer
pub fn invalidate_dcache_by_addr(addr: usize, size: usize) void {
    const cache_line_size: u32 = 32; // STM32H7 cache line size
    const start_addr = addr & ~(cache_line_size - 1); // Align to cache line
    const end_addr = (addr + size + cache_line_size - 1) & ~(cache_line_size - 1);

    var current_addr = start_addr;
    while (current_addr < end_addr) : (current_addr += cache_line_size) {
        cache_m.DCIMVAC.raw = current_addr;
    }
    cpu.dsb();
}

// After DMA transfer completes
pub fn clean_dcache_by_addr(addr: usize, size: usize) void {
    const cache_line_size: usize = 32;
    const start_addr = addr & ~(cache_line_size - 1);
    const end_addr = (addr + size + cache_line_size - 1) & ~(cache_line_size - 1);

    var current_addr = start_addr;
    while (current_addr < end_addr) : (current_addr += cache_line_size) {
        cache_m.DCCMVAC.raw = current_addr;
    }
    cpu.dsb();
}
