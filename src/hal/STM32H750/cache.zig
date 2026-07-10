const std = @import("std");
const microzig = @import("microzig");
const cpu = microzig.cpu;
const comptimePrint = std.fmt.comptimePrint;
const scb = microzig.cpu.peripherals.scb;

// Cortex-M7 cache-maintenance operation registers @ 0xE000EF50. microzig's SCB
// definition stops at CPACR (0x88) and the built-in chip does not expose these,
// so define them locally (they are architectural, fixed for all Cortex-M7).
const CacheMaint = extern struct {
    ICIALLU: u32, // 0xE000EF50  I-cache invalidate all to PoU
    reserved0: u32,
    ICIMVAU: u32, // 0xE000EF58  I-cache invalidate by MVA to PoU
    DCIMVAC: u32, // 0xE000EF5C  D-cache invalidate by MVA to PoC
    DCISW: u32, // 0xE000EF60  D-cache invalidate by set/way
    DCCMVAU: u32, // 0xE000EF64  D-cache clean by MVA to PoU
    DCCMVAC: u32, // 0xE000EF68  D-cache clean by MVA to PoC
    DCCSW: u32, // 0xE000EF6C  D-cache clean by set/way
    DCCIMVAC: u32, // 0xE000EF70  D-cache clean & invalidate by MVA to PoC
    DCCISW: u32, // 0xE000EF74  D-cache clean & invalidate by set/way
};
const cache_m: *volatile CacheMaint = @ptrFromInt(0xE000EF50);

// Decode the current cache's CCSIDR (a plain u32 in microzig's SCB).
inline fn ccsidr_num_sets() u32 {
    return (scb.CCSIDR >> 13) & 0x7FFF;
}
inline fn ccsidr_associativity() u32 {
    return (scb.CCSIDR >> 3) & 0x3FF;
}

pub inline fn enableICache() void {
    if (scb.CCR.read().IC != 0) return; // already enabled

    cpu.dsb();
    cpu.isb();
    // invalidate I-Cache
    cache_m.ICIALLU = 0;
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
    cache_m.ICIALLU = 0;
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

    var sets: u32 = ccsidr_num_sets();
    while (true) {
        var ways: u32 = ccsidr_associativity();
        while (true) {
            cache_m.DCISW =
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
    scb.CSSELR = 0; // select Level 1 data cache
    cpu.dsb();

    scb.CCR.modify(.{ .DC = 0 }); // disable D-Cache
    cpu.dsb();

    var sets: u32 = ccsidr_num_sets();
    while (true) {
        var ways: u32 = ccsidr_associativity();
        while (true) {
            cache_m.DCCISW =
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
        cache_m.DCIMVAC = current_addr;
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
        cache_m.DCCMVAC = current_addr;
    }
    cpu.dsb();
}
