const std = @import("std");
const microzig = @import("microzig");

const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const RCC = chip.peripherals.RCC;

// const scb = cpu.peripherals.scb;
// const hal = @import("hal.zig");
// const stm32 = hal;
// const rcc_hal = stm32.rcc;

var uwTick: u32 = 0;
var uwTickFreq: u32 = 1; // Default 1 Hz freq
var uwTickPrio: cpu.interrupt.Priority = .lowest;

const HSI_VALUE: u32 = 64_000_000; // Value of the Internal oscillator in Hz
const CSI_VALUE: u32 = 4_000_000; // Value of the Internal oscillator in Hz
const HSE_VALUE: u32 = 16_000_000; // Value of the External oscillator in Hz
pub var SystemCoreClock: u32 = 0;
pub var SystemD2Clock: u32 = 0;

pub fn get_tick() u32 {
    return uwTick;
}

pub fn inc_tick() callconv(.c) void {
    uwTick += uwTickFreq;
}

pub fn get_sys_clock_freq() u32 {
    const sw = RCC.CFGR.read().SWS;
    const hsi_div = @intFromEnum(RCC.CR.read().HSIDIV);

    return switch (sw) {
        .HSI => HSI_VALUE >> hsi_div,
        // .HSI => blk: {
        //     // HSI used as system clock
        //     if (rcc_hal.get_flag(.HSIDIV) != 0) {
        //         break :blk HSI_VALUE >> (hsi_div >> 3);
        //     } else {
        //         break :blk HSI_VALUE;
        //     }
        // },
        .CSI => CSI_VALUE, // CSI used as system clock
        .HSE => HSE_VALUE, // HSE used as system clock
        .PLL1_P => blk: {
            // PLL1 used as system clock
            const pllsource = RCC.PLLCKSELR.read().PLLSRC;
            const pllm = @intFromEnum(RCC.PLLCKSELR.read().DIVM1);
            const pllfracen = RCC.PLLCFGR.read().PLL1FRACEN;
            const fracn1 = if (pllfracen != 0)
                // @as(f32, @floatFromInt((RCC.PLL1FRACR.read().FRACN1 >> 3)))
                @as(f32, @floatFromInt((RCC.PLL1FRACR.read().FRACN1 >> 3)))
            else
                0.0;

            if (pllm == 0) break :blk 0;

            const n1 = @intFromEnum(RCC.PLL1DIVR.read().DIVN1);
            const vco_mul = @as(f32, @floatFromInt(n1)) + (fracn1 / 0x2000) + 1.0;

            const pll_input: f32 = switch (pllsource) {
                .HSI => @as(f32, @floatFromInt(HSI_VALUE >> hsi_div)),
                // .HSI => blk2: {
                //     if (rcc_hal.get_flag(.HSIDIV) != 0) {
                //         const hsi_val = HSI_VALUE >> (hsi_div >> 3);
                //         break :blk2 @as(f32, @floatFromInt(hsi_val));
                //     } else break :blk2 @as(f32, @floatFromInt(HSI_VALUE));
                // },
                .CSI => @as(f32, @floatFromInt(CSI_VALUE)),
                .HSE => @as(f32, @floatFromInt(HSE_VALUE)),
                else => @as(f32, @floatFromInt(CSI_VALUE)),
            };

            const pllvco = (pll_input / @as(f32, @floatFromInt(pllm))) * vco_mul;
            const pllp = @intFromEnum(RCC.PLL1DIVR.read().DIVP1) + 1;
            // pllp = (((RCC->PLL1DIVR & RCC_PLL1DIVR_P1) >> 9) + 1U) ;
            break :blk @intFromFloat(pllvco / @as(f32, @floatFromInt(pllp)));
        },
        _ => CSI_VALUE, // Default case
    };
}

pub fn hal_init_tick(priority: cpu.interrupt.Priority) !void {
    if (uwTickFreq == 0) {
        @breakpoint(); // we plan to devide by it!
    }
    const ticks = SystemCoreClock / 1000 / uwTickFreq;
    if (ticks - 1 > std.math.maxInt(u24)) {
        @breakpoint();
        return error.Overflow;
    }
    try init_systick(@intCast(ticks));

    if (@intFromEnum(priority) < @intFromEnum(cpu.interrupt.Priority.highest)) {
        cpu.interrupt.exception.set_priority(.SysTick, priority);
        uwTickPrio = priority;
    }
}

fn init_systick(tick_limit: u24) !void {
    cpu.interrupt.enable_interrupts();
    cpu.interrupt.exception.set_priority(.SysTick, .highest);
    uwTick = 0;
    systick.LOAD.modify(.{ .RELOAD = tick_limit });
    systick.VAL.modify(.{ .CURRENT = 0 });
    systick.CTRL.modify(.{
        .ENABLE = 1,
        .TICKINT = 1,
        .CLKSOURCE = 1,
    });
}
