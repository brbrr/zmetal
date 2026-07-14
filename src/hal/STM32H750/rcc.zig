const std = @import("std");
const microzig = @import("microzig");
const comptimePrint = std.fmt.comptimePrint;

const daisy = @import("daisy.zig");
const hal = @import("hal.zig");
const hal_power = @import("power.zig");
const clock = @import("clock.zig");

pub const ClockTree = @import("ClockTree").get_mcu_tree(microzig.config.chip_name);
pub const Config = ClockTree.Config;
pub const clock_outputs = daisy.clock_outputs;
pub const current_clocks = daisy.clocktree_outputs;

const flash = microzig.chip.peripherals.FLASH;
const rcc = microzig.chip.peripherals.RCC;
const pwr = microzig.chip.peripherals.PWR;

const perih_types = microzig.chip.types.peripherals;
const RCC = perih_types.rcc_h7rm0433;
const PWR = perih_types.pwr_h7rm0433;
const FLASH = perih_types.flash_h7;

const PLLM = RCC.PLLM;
const PLLN = RCC.PLLN;
const PLLDIV = RCC.PLLDIV;
const PLLSRC = RCC.PLLSRC;

const PPRE = RCC.PPRE;
const HPRE = RCC.HPRE;
const RTCSEL = RCC.RTCSEL;
const MCO1SEL = RCC.MCO1SEL;
const MCO2SEL = RCC.MCO2SEL;
const SW = RCC.SW;

const ClockSwitchTimeout: u32 = 5000; // 5 sec
const PLLTimeout: u32 = 10; // 2ms in C

const ClockInitError = error{
    HSETimeout,
    LSETimeout,
    FlashError,
    SysClkTimeout,
    ClockNotReady,
    ClockSetupError,
    ClockConfigError,
    PllError,
};

pub const DivUpdate = enum(u3) {
    DivP = 0,
    DivQ = 1,
    DivR = 2,
};

const stm32_common = @import("stm32_common");
pub const RccPeriferals = stm32_common.enums.Peripherals;
const util = stm32_common.util;

pub const ResetReason = enum {
    low_power,
    window_watchdog,
    independent_watchdog,
    POR_or_PDR,
    NRST,
};

pub const ClockOutputs = struct {
    //system clock
    SYS: u32 = 0,

    //Bus Clocks
    AHB: u32 = 0,
    APB1: u32 = 0,
    APB2: u32 = 0,
    APB3: u32 = 0,
    APB4: u32 = 0,

    //Peripheral clocks
    FSMC: u32 = 0,
    SDIO: u32 = 0,
    TimAPB1: u32 = 0,
    TimAPB2: u32 = 0,
    ADC: u32 = 0,
    // USB: u32 = 0,

    USART234578: u32 = 0,
    USART16: u32 = 0,

    SAI1: u32 = 0,
};

pub const Bus = enum {
    // AHB, //AHB cannot be reset by software
    APB1,
    APB2,
};

pub const RccFlag = enum(u8) {
    HSIRDY = 0x22,
    HSIDIV = 0x25,
    CSIRDY = 0x28,
    HSI48RDY = 0x2D,
    D1CKRDY = 0x2E, // or CPUCKRDY alias
    D2CKRDY = 0x2F, // or CDCKRDY alias
    HSERDY = 0x31,
    PLLRDY = 0x39,
    PLL2RDY = 0x3B,
    PLL3RDY = 0x3D,
    LSERDY = 0x41,
    LSIRDY = 0x61,
    CPURST = 0x91,
    D1RST = 0x93, // or CDRST alias
    D2RST = 0x94,
    BORRST = 0x95,
    PINRST = 0x96,
    PORRST = 0x97,
    SFTRST = 0x98,
    IWDG1RST = 0x9A,
    WWDG1RST = 0x9C,
    LPWR1RST = 0x9E,
    LPWR2RST = 0x9F,
};

pub fn get_flag(flag: RccFlag) u1 {
    const int_flag: u8 = @intFromEnum(flag);
    const reg_index = int_flag >> 5; // Which register group
    const bit_pos = int_flag & 0x1F; // Which bit in the register

    const reg_val: u32 = switch (reg_index) {
        1 => rcc.CR.raw,
        2 => rcc.BDCR.raw,
        3 => rcc.CSR.raw,
        4 => rcc.RSR.raw,
        else => rcc.CIFR.raw,
    };

    return if ((reg_val & (@as(u32, 1) << @as(u5, @intCast(bit_pos)))) != 0) 1 else 0;
    // return if ((reg_val & (1 << bit_pos)) != 0) 1 else 0;
}

pub fn wait_for_flag(flag: RccFlag, expected: u1, max_wait: u32) !void {
    const tick_start = clock.get_tick();
    while (get_flag(flag) != expected) {
        if (clock.get_tick() - tick_start > max_wait) return error.HSETimeout;
    }
    // var ticks: usize = clock.get_tick();
    // while (get_flag(flag) != expected) {
    //     if (ticks == max_wait - 1) return error.HSETimeout;
    //     ticks = clock.get_tick();
    //     asm volatile ("" ::: .{ .memory = true });
    // }
}

// NOTE: procedural style or loop through all elements of the struct?
///Configures the system clocks
/// NOTE: to configure the backup domain clocks (RTC) it is necessary to enable it through the power
///register before configuring the clocks
pub fn apply_clock(comptime tree_out: ClockTree.Tree_Output, flash_latency: u3) ClockInitError!void {
    if (clock_outputs.SysCLKOutput == 400_000_000) {
        hal_power.set_voltage_scalling(.Scale1);
    } else if (clock_outputs.SysCLKOutput == 480_000_000) {
        hal_power.set_voltage_scalling(.Scale0);
    } else {
        @panic("invalid sysclock?");
    }

    while (!hal_power.get_flag(.VOSRDY)) {
        microzig.cpu.nop();
    }

    const pllsrc: PLLSRC = @enumFromInt(tree_out.config.PLLSource.?.get());
    rcc.PLLCKSELR.modify_one("PLLSRC", pllsrc);

    try osc_config(tree_out);

    // NOTE: this is needed to propagate the changes?
    clock.delay_ms(10);

    try config_clocks(tree_out, flash_latency);

    try config_peripherals(tree_out);
    config_usb();
}

pub fn config_usb() void {
    // /* Enable the USB voltage detector */
    pwr.CR3.modify_one("USB33DEN", 1);
}

fn toPPRE(div: u32) PPRE {
    return switch (div) {
        1 => .Div1,
        2 => .Div2,
        4 => .Div4,
        8 => .Div8,
        16 => .Div16,
        else => @enumFromInt(div),
    };
}

fn toHPRE(div: u32) HPRE {
    return switch (div) {
        1 => .Div1,
        2 => .Div2,
        4 => .Div4,
        8 => .Div8,
        16 => .Div16,
        64 => .Div64,
        128 => .Div128,
        256 => .Div256,
        512 => .Div512,
        else => @enumFromInt(div),
    };
}

/// NOTE:
/// Current implementation assumes that below clock types are desired:
/// RCC_CLOCKTYPE_D1PCLK1, RCC_CLOCKTYPE_HCLK, RCC_CLOCKTYPE_SYSCLK,
/// RCC_CLOCKTYPE_PCLK1, RCC_CLOCKTYPE_PCLK2 ,RCC_CLOCKTYPE_D3PCLK1
pub fn config_clocks(comptime tree_out: ClockTree.Tree_Output, flash_latency: u3) ClockInitError!void {
    const cfg_out = tree_out.config; // configuration selections

    // To correctly read data from FLASH memory, the number of wait states (LATENCY)
    // must be correctly programmed according to the frequency of the CPU clock
    // (HCLK) and the supply voltage of the device.

    // Increasing the CPU frequency
    // if (@intFromEnum(flash_latency) > @intFromEnum(flash.ACR.read().LATENCY)) {
    // Program the new number of wait states to the LATENCY bits in the FLASH_ACR register
    // flash.ACR.modify_one("LATENCY", flash_latency);
    flash.ACR.modify(.{
        .LATENCY = flash_latency,
        .WRHIGHFREQ = switch (daisy.SysConfig.freq) {
            .boost => 3, // 480 MHz, VOS0
            .default => 2, // 400 MHz, VOS1
        },
    });

    // Check that the new number of wait states is taken into account to access the Flash memory by reading the FLASH_ACR register
    if (flash.ACR.read().LATENCY != flash_latency) {
        return error.FlashError;
    }
    // }

    // Increasing the BUS frequency divider */
    //-------------------------- D1PCLK1/CDPCLK1 Configuration ---------------------------*/
    {
        const cval: RCC.PPRE = toPPRE(@intFromFloat(cfg_out.D1PPRE.?.get()));
        if (@intFromEnum(cval) > @intFromEnum(rcc.D1CFGR.read().D1PPRE)) {
            rcc.D1CFGR.modify_one("D1PPRE", cval);
        }
    }

    //-------------------------- PCLK1 Configuration ---------------------------*/
    {
        const cval: RCC.PPRE = toPPRE(@intFromFloat(cfg_out.D2PPRE1.?.get()));
        if (@intFromEnum(cval) > @intFromEnum(rcc.D2CFGR.read().D2PPRE1)) {
            rcc.D2CFGR.modify_one("D2PPRE1", cval);
        }
    }

    //-------------------------- PCLK2 Configuration ---------------------------*/
    // if (config.D2PPRE2) |val| {
    {
        const cval: RCC.PPRE = toPPRE(@intFromFloat(cfg_out.D2PPRE2.?.get()));
        if (@intFromEnum(cval) > @intFromEnum(rcc.D2CFGR.read().D2PPRE2)) {
            rcc.D2CFGR.modify_one("D2PPRE2", cval);
        }
    }

    //-------------------------- D3PCLK1 Configuration ---------------------------*/
    // config.D3PPRE is f32 in Clock_Output, not optional
    {
        const cval: RCC.PPRE = toPPRE(@intFromFloat(cfg_out.D3PPRE.?.get()));
        if (@intFromEnum(cval) > @intFromEnum(rcc.D3CFGR.read().D3PPRE)) {
            rcc.D3CFGR.modify_one("D3PPRE", cval);
        }
    }

    //-------------------------- HCLK Configuration --------------------------*/
    // config.HPRE is f32 in Clock_Output, not optional
    {
        const cval = toHPRE(@intFromFloat(cfg_out.HPRE.?.get()));
        if (@intFromEnum(cval) > @intFromEnum(rcc.D1CFGR.read().HPRE)) {
            rcc.D1CFGR.modify_one("HPRE", cval);
        }
    }

    //------------------------- SYSCLK Configuration -------------------------*/
    // cfg_out.SYSCLKSource is the enum selection, config.SysClkSource is the frequency
    if (cfg_out.SYSCLKSource) |sysclk_source| {
        const cval = toHPRE(@intFromFloat(cfg_out.D1CPRE.?.get()));
        rcc.D1CFGR.modify_one("D1CPRE", cval);

        const flag_name = switch (sysclk_source) {
            .RCC_SYSCLKSOURCE_HSI => RccFlag.HSIRDY,
            .RCC_SYSCLKSOURCE_CSI => RccFlag.CSIRDY,
            .RCC_SYSCLKSOURCE_HSE => RccFlag.HSERDY,
            .RCC_SYSCLKSOURCE_PLLCLK => RccFlag.PLLRDY,
        };
        if (get_flag(flag_name) == 0) {
            return error.ClockNotReady;
        }

        const sw_src: RCC.SW = @enumFromInt(sysclk_source.get());
        rcc.CFGR.modify_one("SW", sw_src);
        const tick_start = clock.get_tick();
        // #define __HAL_RCC_GET_SYSCLK_SOURCE() ((uint32_t)(RCC->CFGR & RCC_CFGR_SWS))
        while (rcc.CFGR.read().SWS != sw_src) {
            if (clock.get_tick() - tick_start > ClockSwitchTimeout) {
                return error.SysClkTimeout;
            }
        }
    } else {
        return error.ClockConfigError;
    }

    // Decreasing the number of wait states because of lower CPU frequency */
    // if (@intFromEnum(flash_latency) < @intFromEnum(flash.ACR.read().LATENCY)) {
    // Program the new number of wait states to the LATENCY bits in the FLASH_ACR register
    // flash.ACR.modify_one("LATENCY", flash_latency);

    // Check that the new number of wait states is taken into account to access the Flash memory by reading the FLASH_ACR register
    // if (flash.ACR.read().LATENCY != flash_latency) {
    //     return error.FlashError;
    // }
    // }

    clock.update_system_core_clock();
    clock.hal_init_tick(clock.uwTickPrio) catch {
        return error.ClockSetupError;
    };
}

fn osc_config(comptime tree_out: ClockTree.Tree_Output) ClockInitError!void {
    if (tree_out.config.PLLSource) |src| {
        // const temp_sysclksrc = rcc.CFGR.read().SWS;
        // const temp_pllckselr = rcc.PLLCKSELR.read();

        // NOTE: Not sure what to check here tbh
        // if (temp_sysclksrc == .HSE or (temp_sysclksrc == .PLL1_P and temp_pllckselr.PLLSRC == .HSE)) {
        //     if (get_flag(.HSERDY) and config.HSESTATE == HSE_OFF) {
        //         @panic("OLOLO");
        //     }
        // }

        // Set the new HSE configuration
        try config_HSE(tree_out.config);
        try config_HSI48(tree_out.config);

        if (rcc.CFGR.read().SWS != .PLL1_P) {
            try config_PLL1(tree_out, @enumFromInt(src.get()));
        } else {
            const sws = rcc.CFGR.read().SWS;
            _ = sws;
            @panic("Not supported for now!\n");
        }
    } else {
        @panic("Not implemented!\n");
    }
}

fn config_PLL1(comptime tree_out: ClockTree.Tree_Output, clock_src: PLLSRC) !void {
    const config = tree_out.config; // Use config, not clock
    // Disable the main PLL. */
    rcc.CR.modify_one("PLLON[0]", 0);
    try wait_for_flag(.PLLRDY, 0, @intFromFloat(config.HSE_Timout.?));

    // Set PLL source and divider (assuming you have similar mmio for PLLCKSELR)
    // config.DIVM1 is now ?f32 in Config_Output
    const divm1_val = @as(u6, @intCast(@as(u32, @intFromFloat(config.DIVM1.?))));
    rcc.PLLCKSELR.modify(.{ .PLLSRC = clock_src, .@"DIVM[0]" = @as(PLLM, @enumFromInt(divm1_val)) });

    // Set PLL1DIVR fields (microzig: PLLDIVR[0], generic PLLN/PLLP/PLLQ/PLLR)
    // In Config_Output: DIVN1, DIVQ1, DIVR1 are ?f32; DIVP1 is ?DIVP1List
    rcc.@"PLLDIVR[0]".modify(.{
        .PLLN = @as(PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN1.?)) - 1)),
        .PLLP = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVP1.?.get())) - 1)),
        .PLLQ = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVQ1.?)) - 1)),
        .PLLR = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVR1.?)) - 1)),
    });

    // Disable PLLFRACN . */
    rcc.PLLCFGR.modify_one("PLLFRACEN[0]", 0);

    // /* Configure PLL PLL1FRACN */
    rcc.@"PLLFRACR[0]".modify_one("FRACN", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLLFRACN.?)))));

    rcc.PLLCFGR.modify(.{
        .@"PLLRGE[0]" = @as(RCC.PLLRGE, @enumFromInt(2)), // RCC_PLL1VCIRANGE_2
        .@"PLLVCOSEL[0]" = @as(RCC.PLLVCOSEL, @enumFromInt(0)), // RCC_PLL1VCOWIDE
    });

    rcc.PLLCFGR.modify(.{
        .@"DIVPEN[0]" = 1, // Enable PLL System Clock output. */
        .@"DIVQEN[0]" = 1, // Enable PLL1Q Clock output. */
        .@"DIVREN[0]" = 1, // Enable PLL1R  Clock output. */
    });

    // Enable PLL1FRACN
    rcc.PLLCFGR.modify_one("PLLFRACEN[0]", 1);
    // Enable the main PLL
    rcc.CR.modify_one("PLLON[0]", 1);

    try wait_for_flag(.PLLRDY, 1, @intFromFloat(config.HSE_Timout.?));
}

fn pll2_config(comptime tree_out: ClockTree.Tree_Output, comptime divider: DivUpdate) !void {
    const config = tree_out.config;

    if (rcc.PLLCKSELR.read().PLLSRC == .DISABLE) {
        return error.PllError;
    }

    // Disable  PLL2. */
    rcc.CR.modify_one("PLLON[1]", 0);
    try wait_for_flag(.PLL2RDY, 0, PLLTimeout);

    // Configure the PLL2 multiplication and division factors. */
    const divm2: RCC.PLLM = @enumFromInt(@as(u32, @intFromFloat(config.DIVM2.?)));
    rcc.PLLCKSELR.modify_one("DIVM[1]", divm2);

    rcc.@"PLLDIVR[1]".modify(.{
        .PLLN = @as(RCC.PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN2.?)) - 1)),
        .PLLP = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVP2.?)) - 1)),
        .PLLQ = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVQ2.?)) - 1)),
        .PLLR = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVR2.?)) - 1)),
    });

    // PLL2 VCI range: 16MHz/1 = 16MHz → Range 3 (8-16MHz) = RCC_PLL2VCIRANGE_3
    rcc.PLLCFGR.modify(.{
        .@"PLLRGE[1]" = @as(RCC.PLLRGE, @enumFromInt(2)),
        .@"PLLVCOSEL[1]" = @as(RCC.PLLVCOSEL, @enumFromInt(0)),
    });

    // Disable PLL2FRACN.
    rcc.PLLCFGR.modify_one("PLLFRACEN[1]", 0);

    // Configures PLL2 clock Fractional Part Of The Multiplication Factor */
    rcc.@"PLLFRACR[1]".modify_one("FRACN", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLL2FRACN.?)))));
    //
    // Enable PLL2FRACN . */
    rcc.PLLCFGR.modify_one("PLLFRACEN[1]", 1);
    // Enable the PLL2 clock output */

    const div_name = switch (divider) {
        .DivP => "DIVPEN[1]",
        .DivQ => "DIVQEN[1]",
        .DivR => "DIVREN[1]",
    };

    rcc.PLLCFGR.modify_one(div_name, 1);
    // Enable  PLL2. */
    rcc.CR.modify_one("PLLON[1]", 1);

    // Wait till PLL2 is ready */
    try wait_for_flag(.PLL2RDY, 1, PLLTimeout);
}

fn pll3_config(comptime tree_out: ClockTree.Tree_Output, comptime divider: DivUpdate) !void {
    const config = tree_out.config;

    if (rcc.PLLCKSELR.read().PLLSRC == .DISABLE) {
        return error.PllError;
    }

    // Disable  PLL3. */
    rcc.CR.modify_one("PLLON[2]", 0);
    try wait_for_flag(.PLL3RDY, 0, PLLTimeout);

    // Configure the PLL3 multiplication and division factors. */
    const divm3: RCC.PLLM = @enumFromInt(@as(u32, @intFromFloat(config.DIVM3.?)));
    rcc.PLLCKSELR.modify_one("DIVM[2]", divm3);
    rcc.@"PLLDIVR[2]".modify(.{
        .PLLN = @as(RCC.PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN3.?)) - 1)),
        .PLLP = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVP3.?)) - 1)),
        .PLLQ = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVQ3.?)) - 1)),
        .PLLR = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVR3.?)) - 1)),
    });

    // PLL3 VCI range: 16MHz/6 = 2.67MHz → Range 1 (2-4MHz) = RCC_PLL3VCIRANGE_1
    rcc.PLLCFGR.modify(.{
        .@"PLLRGE[2]" = @as(RCC.PLLRGE, @enumFromInt(1)),
        .@"PLLVCOSEL[2]" = @as(RCC.PLLVCOSEL, @enumFromInt(0)),
    });

    // Disable PLL3FRACN.
    rcc.PLLCFGR.modify_one("PLLFRACEN[2]", 0);

    // Configures PLL3 clock Fractional Part Of The Multiplication Factor */
    rcc.@"PLLFRACR[2]".modify_one("FRACN", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLL3FRACN.?)))));
    // Enable PLL3FRACN
    rcc.PLLCFGR.modify_one("PLLFRACEN[2]", 1);
    // Enable the PLL3 clock output */

    const div_name = switch (divider) {
        .DivP => "DIVPEN[2]",
        .DivQ => "DIVQEN[2]",
        .DivR => "DIVREN[2]",
    };

    rcc.PLLCFGR.modify_one(div_name, 1);

    // rcc.PLLCFGR.modify(.{
    //     .DIVP3EN = 1, // Enable PLL System Clock output. */
    //     .DIVQ3EN = 1, // Enable PLL1Q Clock output. */
    //     .DIVR3EN = 1, // Enable PLL1R  Clock output. */
    // });
    // Enable  PLL3. */
    rcc.CR.modify_one("PLLON[2]", 1);

    // Wait till PLL3 is ready */
    try wait_for_flag(.PLL3RDY, 1, PLLTimeout);
}

//force HSI Clock and clear any clock configs
fn secure_enable() void {
    rcc.CR.modify(.{ .HSION = 1 });
    while (rcc.CR.read().HSIRDY != 1) {
        asm volatile ("" ::: .{ .memory = true });
    }

    rcc.BDCR.raw = 0;
    rcc.CFGR.raw = 0;
    while (rcc.CFGR.read().SWS != .HSI) {
        asm volatile ("" ::: .{ .memory = true });
    }

    rcc.CR.modify(.{
        .PLL1ON = 0,
        .PLL2ON = 0,
        .PLL3ON = 0,

        .HSEBYP = 0,
        .HSEON = 0,
        .HSECSSON = 0,
    });
}

fn config_HSI(value: usize) void {
    //secure_enable has already started the HSE
    const trim: u5 = @truncate(value);
    rcc.CR.modify(.{ .HSITRIM = trim });

    //wait for the HSI to stabilize
    for (0..16) |_| {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_LSI() void {
    rcc.CSR.modify(.{ .LSION = 1 });
    while (rcc.CSR.read().LSIRDY == 0) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_HSE(comptime config: ClockTree.Config_Output) ClockInitError!void {
    rcc.CR.modify(.{ .HSEON = 1 });

    // config.HSE_Timout is now ?f32
    try wait_for_flag(.HSERDY, 1, @intFromFloat(config.HSE_Timout.?));
}

fn config_HSI48(comptime config: ClockTree.Config_Output) ClockInitError!void {
    rcc.CR.modify(.{ .HSI48ON = 1 });

    // config.HSE_Timout is now ?f32
    try wait_for_flag(.HSI48RDY, 1, @intFromFloat(config.HSE_Timout.?));
}

fn config_LSE(comptime config: ClockTree.Config_Output) ClockInitError!void {
    // config.LSE_Timeout is now ?f32
    const max_wait: u32 = if (config.LSE_Timeout) |val| @intFromFloat(val) else std.math.maxInt(u32);
    var ticks: usize = 0;
    rcc.BDCR.modify(.{ .LSEON = 1 });
    while (rcc.BDCR.read().LSERDY == 0) {
        if (ticks == max_wait - 1) return error.LSETimeout;
        ticks += 1;
        asm volatile ("" ::: .{ .memory = true });
    }
}

pub const PLL3Clocks = struct {
    p: u32,
    q: u32,
    r: u32,
};

pub fn getPLL3Clocks() PLL3Clocks {
    const pllsource = @intFromEnum(rcc.PLLCKSELR.read().PLLSRC);
    const pll3m_raw: f32 = @floatFromInt(@intFromEnum(rcc.PLLCKSELR.read().@"DIVM[2]"));
    const pll3m: f32 = if (pll3m_raw != 0) pll3m_raw else 1.0; // avoid div0

    const pll3fracen = rcc.PLLCFGR.read().@"PLLFRACEN[2]";
    const fracn3_raw = (rcc.@"PLLFRACR[2]".read().FRACN) >> 3;
    const fracn3: f32 = if (pll3fracen == 1) @floatFromInt(fracn3_raw) else 0.0;

    // Base clock source
    const hse: f32 = 16_000_000.0;
    const hsi: f32 = 64_000_000.0;
    const csi: f32 = 4_000_000.0;

    var pll_input: f32 = 0.0;
    switch (pllsource) {
        0 => pll_input = hsi, // HSI
        1 => pll_input = csi, // CSI
        2 => pll_input = hse, // HSE
        else => pll_input = csi,
    }

    const n: f32 = @floatFromInt(@intFromEnum(rcc.@"PLLDIVR[2]".read().PLLN));
    const nfloat: f32 = n + 1.0 + fracn3 / 8192.0;

    const pll3vco: f32 = (pll_input / pll3m) * nfloat;

    // divisors
    const pdiv: f32 = @floatFromInt(@intFromEnum(rcc.@"PLLDIVR[2]".read().PLLP) + 1);
    const qdiv: f32 = @floatFromInt(@intFromEnum(rcc.@"PLLDIVR[2]".read().PLLQ) + 1);
    const rdiv: f32 = @floatFromInt(@intFromEnum(rcc.@"PLLDIVR[2]".read().PLLR) + 1);

    return PLL3Clocks{
        .p = @intFromFloat(pll3vco / pdiv),
        .q = @intFromFloat(pll3vco / qdiv),
        .r = @intFromFloat(pll3vco / rdiv),
    };
}

fn config_peripherals(comptime tree_out: ClockTree.Tree_Output) !void {
    const config = tree_out.config;

    //---------------------------- SAI1 configuration -------------------------------*/
    if (config.SAI1CLockSelection) |clk| {
        switch (clk) {
            .RCC_SAI1CLKSOURCE_PLL3 => try pll3_config(tree_out, .DivP),
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP1R.modify_one("SAI1SEL", @enumFromInt(clk.get()));
    }

    //---------------------------- SAI2/3 configuration -------------------------------*/
    if (config.SAI23CLockSelection) |clk| {
        switch (clk) {
            .RCC_SAI23CLKSOURCE_PLL3 => try pll3_config(tree_out, .DivP),
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP1R.modify_one("SAI23SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //---------------------------- QSPI configuration -------------------------------*/
    if (config.QSPICLockSelection) |clk| {
        switch (clk) {
            .RCC_QSPICLKSOURCE_D1HCLK => {},
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("QUADSPISEL", @enumFromInt(@intFromEnum(clk)));
    }

    //---------------------------- SPI1/2/3 configuration -------------------------------*/
    if (config.SPI123CLockSelection) |clk| {
        switch (clk) {
            .RCC_SPI123CLKSOURCE_PLL2 => try pll2_config(tree_out, .DivP),
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP1R.modify_one("SPI123SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //---------------------------- FMC configuration -------------------------------*/
    if (config.FMCCLockSelection) |clk| {
        switch (clk) {
            .RCC_FMCCLKSOURCE_PLL2 => try pll2_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("FMCSEL", @enumFromInt(@intFromEnum(clk)));
    }

    //-------------------------- USART1/6 configuration --------------------------*/
    if (config.USART16CLockSelection) |clk| {
        switch (clk) {
            .RCC_USART16CLKSOURCE_D2PCLK2 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USART16910SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //-------------------------- USART2/3/4/5/7/8 Configuration --------------------------*/
    if (config.USART234578CLockSelection) |clk| {
        switch (clk) {
            .RCC_USART234578CLKSOURCE_D2PCLK1 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USART234578SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //------------------------------ I2C1/2/3/5* Configuration ------------------------*/
    if (config.I2C123CLockSelection) |clk| {
        switch (clk) {
            .RCC_I2C123CLKSOURCE_D2PCLK1 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("I2C1235SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //------------------------------ I2C4 Configuration ------------------------*/
    if (config.I2C4CLockSelection) |clk| {
        switch (clk) {
            .RCC_I2C4CLKSOURCE_PLL3 => try pll3_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D3CCIPR.modify_one("I2C4SEL", @enumFromInt(@intFromEnum(clk)));
    }

    //---------------------------- ADC configuration -------------------------------*/
    if (config.ADCCLockSelection) |clk| {
        switch (clk) {
            .RCC_ADCCLKSOURCE_PLL3 => try pll3_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D3CCIPR.modify_one("ADCSEL", @enumFromInt(@intFromEnum(clk)));
    }

    //------------------------------ USB Configuration -------------------------*/
    if (config.USBCLockSelection) |clk| {
        switch (clk) {
            .RCC_USBCLKSOURCE_HSI48 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USBSEL", @enumFromInt(@intFromEnum(clk)));
    }

    //------------------------------------- SDMMC Configuration ------------------------------------*/
    if (config.SDMMC1CLockSelection) |clk| {
        switch (clk) {
            .RCC_SDMMCCLKSOURCE_PLL2 => try pll2_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("SDMMCSEL", @enumFromInt(@intFromEnum(clk)));
    }

    //------------------------------ RNG Configuration -------------------------*/
    // if (config.RNGCLockSelection) |clk| {
    //     switch (clk) {
    //         .RCC_RNGCLKSOURCE_PLL => {}, // __HAL_RCC_PLLCLKOUT_ENABLE(RCC_PLL1_DIVQ);
    //         else => @panic("Not implemented!"),
    //     }
    //     rcc.D2CCIP2R.modify_one("RNGSRC", @as(u2, @intCast(@intFromEnum(clk))));
    // }

    //---------------------------- SPDIFRX configuration -------------------------------
    // if (config.SPDIFCLockSelection) |val| {
    //     _ = val;
    //     @panic("SPDIF not supported");
    // }

    ////---------------------------- SAI4A configuration -------------------------------*/
    //if (config.SAI4ACLockSelection) |clk| {
    //    switch (clk) {
    //        else => @panic("Not implemented!"),
    //    }
    //    rcc.D3CCIPR.modify_one("SAI4ASRC", @as(u3, @intCast(@intFromEnum(clk))));
    //}
    //
    ////---------------------------- SAI4B configuration -------------------------------*/
    //if (config.SAI4BCLockSelection) |clk| {
    //    switch (clk) {
    //        else => @panic("Not implemented!"),
    //    }
    //    rcc.D3CCIPR.modify_one("SAI4BSRC", @as(u3, @intCast(@intFromEnum(clk))));
    //}
    //
    ////---------------------------- SPI4/5 configuration -------------------------------*/
    //if (config.SPI45CLockSelection) |clk| {
    //    switch (clk) {
    //        else => @panic("Not implemented!"),
    //    }
    //    rcc.D2CCIP1R.modify_one("SPI45SRC", @as(u3, @intCast(@intFromEnum(clk))));
    //}
    //
    ////---------------------------- SPI6 configuration -------------------------------*/
    //if (config.SPI6CLockSelection) |clk| {
    //    switch (clk) {
    //        else => @panic("Not implemented!"),
    //    }
    //    rcc.D3CCIPR.modify_one("SPI6SRC", @as(u3, @intCast(@intFromEnum(clk))));
    //}
    //
    ////---------------------------- RTC configuration -------------------------------*/
    //if (config.RTCClkSource) |clk| {
    //    switch (clk) {
    //        else => @panic("Not implemented!"),
    //    }
    //}
}

fn init_pll() void {
    rcc.CR.modify(.{ .PLLON = 1 });
    while (rcc.CR.read().PLLRDY == 0) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_MCO(comptime config: ClockTree.Config) void {
    if (config.MCO1Mult) |src| {
        const mco: MCO1SEL = switch (src) {
            .RCC_MCO1SOURCE_HSI => .HSI,
            .RCC_MCO1SOURCE_LSE => .LSE,
            .RCC_MCO1SOURCE_HSE => .HSE,
            .RCC_MCO1SOURCE_PLL1QCLK => .PLL1_Q,
            .RCC_MCO1SOURCE_HSI48 => .HSQI48,
        };
        rcc.CFGR.modify(.{ .MCO1SEL = mco });
    }

    if (config.MCO2Mult) |src| {
        const mco: MCO2SEL = switch (src) {
            .RCC_MCO2SOURCE_SYSCLK => .SYS,
            .RCC_MCO2SOURCE_PLL2PCLK => .PLL2_P,
            .RCC_MCO2SOURCE_HSE => .HSE,
            .RCC_MCO2SOURCE_PLLCLK => .PLL1_P,
            .RCC_MCO2SOURCE_CSICLK => .CSI,
            .RCC_MCO2SOURCE_LSICLK => .LSI,
        };
        rcc.CFGR.modify(.{ .MCO1SEL = mco });
    }
}

pub fn set_clock(peri: RccPeriferals, state: u1) void {
    switch (peri) {
        .DMA1 => rcc.AHB1ENR.modify(.{ .DMA1EN = state }),
        .DMA2 => rcc.AHB1ENR.modify(.{ .DMA2EN = state }),
        .ADC1 => rcc.AHB1ENR.modify(.{ .ADC12EN = state }),
        .ADC2 => rcc.AHB1ENR.modify(.{ .ADC12EN = state }),

        // APB2ENR (APB2 peripherals)
        .TIM1 => rcc.APB2ENR.modify(.{ .TIM1EN = state }),
        .SPI1 => rcc.APB2ENR.modify(.{ .SPI1EN = state }),
        .USART1 => rcc.APB2ENR.modify(.{ .USART1EN = state }),
        .SAI1 => rcc.APB2ENR.modify(.{ .SAI1EN = state }),

        .TIM2 => rcc.APB1LENR.modify(.{ .TIM2EN = state }),
        .TIM3 => rcc.APB1LENR.modify(.{ .TIM3EN = state }),
        .TIM4 => rcc.APB1LENR.modify(.{ .TIM4EN = state }),
        .TIM5 => rcc.APB1LENR.modify(.{ .TIM5EN = state }), //F103xE
        .TIM6 => rcc.APB1LENR.modify(.{ .TIM6EN = state }), //F103xE
        .TIM7 => rcc.APB1LENR.modify(.{ .TIM7EN = state }), //F103xE
        .SPI2 => rcc.APB1LENR.modify(.{ .SPI2EN = state }),
        .SPI3 => rcc.APB1LENR.modify(.{ .SPI3EN = state }), //F103xD/E
        .USART2 => rcc.APB1LENR.modify(.{ .USART2EN = state }),
        .USART3 => rcc.APB1LENR.modify(.{ .USART3EN = state }),
        .UART4 => rcc.APB1LENR.modify(.{ .UART4EN = state }), //F103xC/D/E
        .UART5 => rcc.APB1LENR.modify(.{ .UART5EN = state }), //F103xC/D/E
        .I2C1 => rcc.APB1LENR.modify(.{ .I2C1EN = state }),
        .I2C2 => rcc.APB1LENR.modify(.{ .I2C2EN = state }),
        .I2C3 => rcc.APB1LENR.modify(.{ .I2C3EN = state }),

        .WWDG1 => rcc.APB3ENR.modify(.{ .WWDG1EN = state }),

        .I2C4 => rcc.APB4ENR.modify(.{ .I2C4EN = state }),
        .GPIOA => rcc.AHB4ENR.modify(.{ .GPIOAEN = state }),
        .GPIOB => rcc.AHB4ENR.modify(.{ .GPIOBEN = state }),
        .GPIOC => rcc.AHB4ENR.modify(.{ .GPIOCEN = state }),
        .GPIOD => rcc.AHB4ENR.modify(.{ .GPIODEN = state }),
        .GPIOE => rcc.AHB4ENR.modify(.{ .GPIOEEN = state }),
        .GPIOF => rcc.AHB4ENR.modify(.{ .GPIOFEN = state }), //F103xE
        .GPIOG => rcc.AHB4ENR.modify(.{ .GPIOGEN = state }), //F103xE

        else => @panic("TEST"),
    }

    // STM32H7: after setting a peripheral's RCC clock-enable bit there is a
    // ~2 clock-cycle delay before its registers are accessible. ST's
    // __HAL_RCC_*_CLK_ENABLE() macros insert a dummy readback of the ENR to
    // cover this. Without it, touching the peripheral too soon raises an AHB
    // bus fault — a timing race that only bites when code runs fast enough
    // (e.g. with D-cache enabled). Read all the ENRs we write here so the
    // just-enabled clock is guaranteed stable before the driver proceeds.
    _ = rcc.AHB1ENR.read();
    _ = rcc.AHB4ENR.read();
    _ = rcc.APB1LENR.read();
    _ = rcc.APB2ENR.read();
    _ = rcc.APB3ENR.read();
    _ = rcc.APB4ENR.read();
}

pub fn enable_clock(peri: RccPeriferals) void {
    set_clock(peri, 1);
}

//NOTE: should we panic on invalid clocks?
//errors at comptime appear for peripherals manually configured like USB.
///if requests the clock of an unconfigured peripheral, 0 means error, != 0 means ok
pub fn get_clock(comptime source: RccPeriferals) u32 {
    const peri_name = @tagName(source);

    if (comptime util.match_name(peri_name, &.{
        "TIM",
    })) {
        return @intFromFloat(@field(current_clocks.clock, peri_name ++ "out"));
    }
    if (comptime util.match_name(peri_name, &.{
        "USART",
        "UART",
        "RTC",
    })) {
        return @intFromFloat(@field(current_clocks.clock, peri_name ++ "Output"));
    }

    if (comptime util.match_name(peri_name, &.{
        "I2C",
    })) {
        return @intFromFloat(@field(current_clocks.clock, "I2C123output"));
    }

    if (comptime util.match_name(peri_name, &.{
        "DMA",
        "FLASH",
        "CRC",
        "GPIO",
    })) {
        return @intFromFloat(current_clocks.clock.AHBOutput);
    }
    if (comptime util.match_name(peri_name, &.{
        "ADC1",
        "ADC2",
    })) {
        return @intFromFloat(current_clocks.clock.ADC12output);
    }
    if (comptime util.match_name(peri_name, &.{
        "ADC3",
        "ADC4",
    })) {
        return @intFromFloat(current_clocks.clock.ADC34output);
    }
    if (comptime util.match_name(peri_name, &.{
        "SPI1",
        "SPI4",
        "SPI5",
    })) {
        return @intFromFloat(current_clocks.clock.APB2Prescaler);
    }
    if (comptime util.match_name(peri_name, &.{
        "SPI2",
        "SPI3",
        "DAC",
        "CAN",
        "WWDG",
        "IWDG",
    })) {
        return @intFromFloat(current_clocks.clock.APB1Prescaler);
    }
    if (comptime util.match_name(peri_name, &.{
        "SPI6",
    })) {
        return @intFromFloat(current_clocks.clock.APB4Prescaler);
    }
    if (comptime util.match_name(peri_name, &.{
        "USB",
    })) {
        return @intFromFloat(current_clocks.clock.USBoutput);
    }

    @panic("Unknown clock for peripheral");
}

pub inline fn get_sys_clk() u32 {
    return clock_outputs.SYS;
}

/// Verifies that all enabled peripheral clocks have non-zero output values
///
/// This compile-time function checks that for every XClockSelection field that is non-null
/// in the config, the corresponding Xoutput field in the clock tree output is non-zero.
pub fn verify_peripheral_clocks(comptime config: ClockTree.Config, comptime tree_out: ClockTree.Clock_Output) void {
    // Map clock selection fields to their corresponding output fields
    const clock_mappings = .{
        .{ "SAI1CLockSelection", "SAI1output" },
        .{ "SAI23CLockSelection", "SAI23output" },
        .{ "SAI4ACLockSelection", "SAI4Aoutput" },
        .{ "SAI4BCLockSelection", "SAI4Boutput" },
        .{ "SPI123CLockSelection", "SPI123output" },
        .{ "SPI6CLockSelection", "SPI6output" },
        .{ "Spi45ClockSelection", "SPI45output" },
        .{ "RNGCLockSelection", "RNGoutput" },
        .{ "I2C123CLockSelection", "I2C123output" },
        .{ "I2C4CLockSelection", "I2C4output" },
        .{ "SPDIFCLockSelection", "SPDIFoutput" },
        .{ "QSPICLockSelection", "QSPIoutput" },
        .{ "FMCCLockSelection", "FMCoutput" },
        .{ "SWPCLockSelection", "SWPoutput" },
        .{ "SDMMC1CLockSelection", "SDMMCoutput" },
        .{ "DFSDMCLockSelection", "DFSDMoutput" },
        .{ "USART16CLockSelection", "USART16output" },
        .{ "USART234578CLockSelection", "USART234578output" },
        .{ "LPUART1CLockSelection", "LPUART1output" },
        .{ "LPTIM1CLockSelection", "LPTIM1output" },
        .{ "LPTIM345CLockSelection", "LPTIM345output" },
        .{ "LPTIM2CLockSelection", "LPTIM2output" },
        .{ "USBCLockSelection", "USBoutput" },
        .{ "FDCANCLockSelection", "FDCANoutput" },
        .{ "ADCCLockSelection", "ADCoutput" },
        .{ "CECCLockSelection", "CECoutput" },
        .{ "HRTIMCLockSelection", "HRTIMoutput" },
        .{ "RTCClockSelection", "RTCOutput" },
        .{ "DSICLockSelection", "DSIoutput" },
    };

    inline for (clock_mappings) |mapping| {
        const selection_field = mapping[0];
        const output_field = mapping[1];

        if (@hasField(ClockTree.Config, selection_field) and @hasField(ClockTree.Clock_Output, output_field)) {
            const selection_value = @field(config, selection_field);
            if (selection_value != null) {
                const output_value = @field(tree_out, output_field);
                if (output_value == 0) {
                    @compileError("Clock selection '" ++ selection_field ++ "' is set but output '" ++ output_field ++ "' is 0. Check your clock configuration.");
                }
            }
        }
    }
}
