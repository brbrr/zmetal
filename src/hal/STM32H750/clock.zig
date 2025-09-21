const std = @import("std");
const microzig = @import("microzig");

const hal = @import("hal.zig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const rcc = chip.peripherals.RCC;

// const scb = cpu.peripherals.scb;
// const hal = @import("hal.zig");
// const stm32 = hal;
// const rcc_hal = stm32.rcc;

var uwTick: u32 = 0;
var uwTickFreq: u32 = 1; // Default 1 Hz freq
pub var uwTickPrio: cpu.interrupt.Priority = .lowest;

const HSI_VALUE: u32 = 64_000_000; // Value of the Internal oscillator in Hz
const CSI_VALUE: u32 = 4_000_000; // Value of the Internal oscillator in Hz
const HSE_VALUE: u32 = 16_000_000; // Value of the External oscillator in Hz

/// This variable is updated in three ways:
///      1) by calling CMSIS function SystemCoreClockUpdate()
///      2) by calling HAL API function HAL_RCC_GetHCLKFreq()
///      3) each time HAL_RCC_ClockConfig() is called to configure the system clock frequency
///         Note: If you use this function to configure the system clock; then there
///               is no need to call the 2 first functions listed above, since SystemCoreClock
///               variable is updated automatically.
pub var SystemCoreClock: u32 = 0;
pub var SystemD2Clock: u32 = 0;
const D1CorePrescTable: [16]u8 = [_]u8{ 0, 0, 0, 0, 1, 2, 3, 4, 1, 2, 3, 4, 6, 7, 8, 9 };

pub fn get_tick() u32 {
    return uwTick;
}

pub fn inc_tick() callconv(.c) void {
    uwTick += uwTickFreq;
    const zz = uwTick;
    _ = zz;
}

pub fn delay(wait: u32) void {
    const tickstart = get_tick();
    var _wait = wait;

    _wait += uwTickFreq;
    //* Add a freq to guarantee minimum wait */
    while ((get_tick() - tickstart) < _wait) {}
}

pub fn get_sys_clock_freq() u32 {
    const sw = rcc.CFGR.read().SWS;
    const hsi_div = @intFromEnum(rcc.CR.read().HSIDIV);

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
            const pllsource = rcc.PLLCKSELR.read().PLLSRC;
            const pllm = @intFromEnum(rcc.PLLCKSELR.read().DIVM1);
            const pllfracen = rcc.PLLCFGR.read().PLL1FRACEN;
            const fracn1: f32 = if (pllfracen != 0)
                @floatFromInt((rcc.PLL1FRACR.read().FRACN1 >> 3))
            else
                0.0;

            if (pllm == 0) break :blk 0;

            const n1 = @intFromEnum(rcc.PLL1DIVR.read().DIVN1);
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
            const pllp = @intFromEnum(rcc.PLL1DIVR.read().DIVP1) + 1;
            // pllp = (((RCC->PLL1DIVR & RCC_PLL1DIVR_P1) >> 9) + 1U) ;
            break :blk @intFromFloat(pllvco / @as(f32, @floatFromInt(pllp)));
        },
        _ => CSI_VALUE, // Default case
    };
}

/// Based on system clock freq, updates global SystemClock variables
pub fn update_system_core_clock() void {
    // Update the SystemCoreClock global variable
    const clk_tmp = get_sys_clock_freq();
    const d1cpre = rcc.D1CFGR.read().D1CPRE;
    const shift = D1CorePrescTable[@intFromEnum(d1cpre)] & 0x1F;
    const common_system_clock: u32 = clk_tmp >> @intCast(shift);
    SystemCoreClock = common_system_clock;

    // Update the SystemD2Clock global variable
    const d1_hpre_index = @intFromEnum(rcc.D1CFGR.read().HPRE);
    const shift_2 = D1CorePrescTable[d1_hpre_index] & 0x1F;
    SystemD2Clock = common_system_clock >> @intCast(shift_2);
}

pub fn hal_init_tick(priority: cpu.interrupt.Priority) !void {
    if (uwTickFreq == 0) {
        @panic("BOOM");
    }
    const ticks = SystemCoreClock / 1000 / uwTickFreq;
    if (ticks - 1 > std.math.maxInt(u24)) {
        // @breakpoint();
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
