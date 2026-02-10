//NOTE: this file is only valid for densities: Low, Medium, High, and XL. Connectivity line devices are not supported in this version.
//TODO: Add support for 105/107
const std = @import("std");
const microzig = @import("microzig");
const comptimePrint = std.fmt.comptimePrint;

const daisy = @import("daisy.zig");
const hal = @import("hal.zig");
const hal_power = @import("power.zig");
const clock = @import("clock.zig");

pub const ClockTree = @import("ClockTree").get_mcu_tree(microzig.config.chip_name);
pub const Config = ClockTree.Config;
pub var clock_outputs = daisy.clock_outputs;

const flash = microzig.chip.peripherals.FLASH;
const rcc = microzig.chip.peripherals.RCC;
const pwr = microzig.chip.peripherals.PWR;

const perih_types = microzig.chip.types.peripherals;
const RCC = perih_types.RCC;
const PWR = perih_types.PWR;
const FLASH = perih_types.Flash;

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

const PLLXTPRE = RCC.PLLXTPRE;
const ADCPRE = RCC.ADCPRE;
const USBPRE = RCC.USBPRE;

const ClockSwitchTimeout: u32 = 5000; // 5 sec
const PLLTimeout: u32 = 10; // 2ms in C

const ClockInitError = error{
    HSETimeout,
    LSETimeout,
    FlashError,
    SysClkTimeout,
    ClockNotReady,
    ClockSetupError,
    PllError,
};

pub const DivUpdate = enum(u3) {
    DivP = 0,
    DivQ = 1,
    DivR = 2,
};

const RccPeriferals = enum {
    SRAM,
    FLASH,
    FSMC, //F103xE
    SDIO, //F103xC/D/E

    // APB1ENR
    ADC1,
    ADC2,

    TIM2,
    TIM3,
    TIM4,
    TIM5, //F103xE
    TIM6, //F103xE
    TIM7, //F103xE
    WWDG,
    SPI2,
    SPI3, //F103xD/E
    USART2,
    USART3,
    UART4, //F103xC/D/E
    UART5, //F103xC/D/E
    USB,
    CAN,
    BKP,
    PWR,
    DAC, //F103xE

    DMA1,
    DMA2,
    ETH,

    // APB2ENR
    AFIO,
    TIM1,
    SPI1,
    USART1,

    CRYP,
    DCMI,
    DFSDM1,
    HASH,
    HRTIM1,
    RND,
    SAI1,
    SAI2,
    SAI3,

    //AHB3ENR
    DMA2D,
    FMC,
    LTDC,
    MDMA,
    QUADSPI,
    SDMMC1,

    //AHB4ENR
    ADC3,
    BDMA,
    CRC,
    GPIOA,
    GPIOB,
    GPIOC,
    GPIOD,
    GPIOE,
    GPIOF,
    GPIOG,
    GPIOH,
    GPIOI,
    GPIOJ,
    GPIOK,
    HSEM,
    I2C4,
    LPTIM2,
    LPTIM3,
    LPTIM4,
    LPTIM5,
    LPUART1,
    RTC,
    SAI4,

    // APB1LENR
    CEC,
    DAC1,
    I2C1,
    I2C2,
    I2C3,
    LPTIM1,

    // APB1HENR
    CRS,
    FDCAN1,
    MDIOS,
    OPAMP1,
    OPAMP2,
};

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
    USB: u32 = 0,

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
    var ticks: usize = clock.get_tick();
    while (get_flag(flag) != expected) {
        if (ticks == max_wait - 1) return error.HSETimeout;
        ticks = clock.get_tick();
        asm volatile ("" ::: .{ .memory = true });
    }
}

// NOTE: procedural style or loop through all elements of the struct?
///Configures the system clocks
/// NOTE: to configure the backup domain clocks (RTC) it is necessary to enable it through the power
///register before configuring the clocks
pub fn apply_clock(comptime tree_out: ClockTree.Tree_Output, flash_latency: FLASH.LATENCY) ClockInitError!void {
    hal_power.set_voltage_scalling(.Scale1);
    if (clock_outputs.SysCLKOutput == 400_000_000) {
        hal_power.set_voltage_scalling(.Scale1);
    } else if (clock_outputs.SysCLKOutput == 480_000_000) {
        hal_power.set_voltage_scalling(.Scale1);
    } else {
        @panic("invalid sysclock?");
    }

    while (!hal_power.get_flag(.VOSRDY)) {
        microzig.cpu.nop();
    }

    // #define __HAL_RCC_PLL_PLLSOURCE_CONFIG(__PLLSOURCE__) MODIFY_REG(RCC->PLLCKSELR, RCC_PLLCKSELR_PLLSRC, (__PLLSOURCE__))

    rcc.PLLCKSELR.modify_one("PLLSRC", @as(PLLSRC, @enumFromInt(tree_out.config.PLLSource.?.get())));

    //rest all clock configs
    // secure_enable();
    // if (config.HSICalibrationValue) |val| {
    //     config_HSI(@intFromEnum(val));
    // }

    try osc_config(tree_out);

    // NOTE: this is needed to propagate the changes?
    clock.delay(100);

    try config_clocks(tree_out, flash_latency);

    try config_peripherals(tree_out);
    config_usb();
    // config_MCO(config);

    // const rcc = @intToPtr(*volatile RCC_TypeDef, 0x58024400); // base address
    // std.debug.print("CR={x}\nCFGR={x}\nPLLCKSELR={x}\nPLL1DIVR={x}\nD1CFGR={x}\nD2CFGR={x}\nD3CFGR={x}\n",
    //     .{ rcc.CR.read(), rcc.CFGR.read(), rcc.PLLCKSELR.read(),
    //        rcc.PLL1DIVR.read(), rcc.D1CFGR.read(), rcc.D2CFGR.read(), rcc.D3CFGR.read() });

    const cr = rcc.CR.read();
    const cfgr = rcc.CFGR.read();
    const pllckselr = rcc.PLLCKSELR.read();
    const pll1divr = rcc.PLL1DIVR.read();
    const d1cfgr = rcc.D1CFGR.read();
    const d2cfgr = rcc.D2CFGR.read();
    const d3cfgr = rcc.D3CFGR.read();
    const divm1 = rcc.PLLCKSELR.read().DIVM1;
    const divn1 = rcc.PLL1DIVR.read().DIVN1;
    const divp1 = rcc.PLL1DIVR.read().DIVP1;
    const divr1 = rcc.PLL1DIVR.read().DIVR1;
    const divq1 = rcc.PLL1DIVR.read().DIVQ1;
    _ = divm1;
    _ = divn1;
    _ = divp1;
    _ = divr1;
    _ = divq1;
    _ = cr;
    _ = cfgr;
    _ = pllckselr;
    _ = pll1divr;
    _ = d1cfgr;
    _ = d2cfgr;
    _ = d3cfgr;
}

pub fn config_usb() void {

    // /* Enable the USB voltage detector */
    pwr.PWR_CR3.modify_one("USB33DEN", 1);
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
pub fn config_clocks(comptime tree_out: ClockTree.Tree_Output, flash_latency: FLASH.LATENCY) ClockInitError!void {
    const cfg_out = tree_out.config; // configuration selections

    // To correctly read data from FLASH memory, the number of wait states (LATENCY)
    // must be correctly programmed according to the frequency of the CPU clock
    // (HCLK) and the supply voltage of the device.

    // Increasing the CPU frequency
    if (@intFromEnum(flash_latency) > @intFromEnum(flash.ACR.read().LATENCY)) {
        // Program the new number of wait states to the LATENCY bits in the FLASH_ACR register
        flash.ACR.modify_one("LATENCY", flash_latency);

        // Check that the new number of wait states is taken into account to access the Flash memory by reading the FLASH_ACR register
        if (flash.ACR.read().LATENCY != flash_latency) {
            return error.FlashError;
        }
    }

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
    if (@intFromEnum(flash_latency) < @intFromEnum(flash.ACR.read().LATENCY)) {
        // Program the new number of wait states to the LATENCY bits in the FLASH_ACR register
        flash.ACR.modify_one("LATENCY", flash_latency);

        // Check that the new number of wait states is taken into account to access the Flash memory by reading the FLASH_ACR register
        if (flash.ACR.read().LATENCY != flash_latency) {
            return error.FlashError;
        }
    }

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
    rcc.CR.modify_one("PLL1ON", 0);
    try wait_for_flag(.PLLRDY, 0, @intFromFloat(config.HSE_Timout.?));

    // Set PLL source and divider (assuming you have similar mmio for PLLCKSELR)
    // config.DIVM1 is now ?f32 in Config_Output
    const divm1_val = @as(u6, @intCast(@as(u32, @intFromFloat(config.DIVM1.?))));
    rcc.PLLCKSELR.modify(.{ .PLLSRC = clock_src, .DIVM1 = @as(PLLM, @enumFromInt(divm1_val)) });

    // Set PLL1DIVR fields
    // In Config_Output: DIVN1, DIVQ1, DIVR1 are ?f32; DIVP1 is ?DIVP1List
    rcc.PLL1DIVR.modify(.{
        .DIVN1 = @as(PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN1.?)) - 1)),
        .DIVP1 = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVP1.?.get())) - 1)),
        .DIVQ1 = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVQ1.?)) - 1)),
        .DIVR1 = @as(PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVR1.?)) - 1)),
    });

    // Disable PLLFRACN . */
    rcc.PLLCFGR.modify_one("PLL1FRACEN", 0);

    // /* Configure PLL PLL1FRACN */
    rcc.PLL1FRACR.modify_one("FRACN1", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLLFRACN.?)))));

    rcc.PLLCFGR.modify(.{
        // .PLL1RGE = @intFromEnum(config.PLL1_VCI_Range.?), // 2, // RCC_PLL1VCIRANGE_2
        // .PLL1VCOSEL = @intFromEnum(config.PLL1_VCO_SEL.?), // 0, //RCC_PLL1VCOWIDE

        .PLL1RGE = 2, // 2, // RCC_PLL1VCIRANGE_2
        .PLL1VCOSEL = 0, // 0, //RCC_PLL1VCOWIDE
    });

    // rcc.PLLCFGR.modify_one("PLL1RGE", 2);
    // rcc.PLLCFGR.modify_one("PLL1VCOSEL", 0);

    rcc.PLLCFGR.modify(.{
        .DIVP1EN = 1, // Enable PLL System Clock output. */
        .DIVQ1EN = 1, // Enable PLL1Q Clock output. */
        .DIVR1EN = 1, // Enable PLL1R  Clock output. */
    });

    // Enable PLL1FRACN
    rcc.PLLCFGR.modify_one("PLL1FRACEN", 1);
    // Enable the main PLL
    rcc.CR.modify_one("PLL1ON", 1);

    try wait_for_flag(.PLLRDY, 1, @intFromFloat(config.HSE_Timout.?));
}

fn pll2_config(comptime tree_out: ClockTree.Tree_Output, comptime divider: DivUpdate) !void {
    const config = tree_out.config;

    if (rcc.PLLCKSELR.read().PLLSRC == .DISABLE) {
        return error.PllError;
    }

    // Disable  PLL2. */
    rcc.CR.modify_one("PLL2ON", 0);
    try wait_for_flag(.PLL2RDY, 0, PLLTimeout);

    // Configure the PLL2 multiplication and division factors. */
    const divm2: RCC.PLLM = @enumFromInt(@as(u32, @intFromFloat(config.DIVM2.?)));
    rcc.PLLCKSELR.modify_one("DIVM2", divm2);

    rcc.PLL2DIVR.modify(.{
        .DIVN2 = @as(RCC.PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN2.?)) - 1)),
        .DIVP2 = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVP2.?)) - 1)),
        .DIVQ2 = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVQ2.?)) - 1)),
        .DIVR2 = @as(RCC.PLLDIV, @enumFromInt(@as(u7, @intFromFloat(config.DIVR2.?)) - 1)),
    });

    // PLL2 VCI range: 16MHz/1 = 16MHz → Range 3 (8-16MHz) = RCC_PLL2VCIRANGE_3
    rcc.PLLCFGR.modify(.{
        .PLL2RGE = @intFromEnum(config.PLL2_VCI_Range.?),
        .PLL2VCOSEL = @intFromEnum(config.PLL2_VCO_SEL.?),
        // .PLL2RGE = config.PLL2_VCI_Range, // RCC_PLL2VCIRANGE_3 for 16MHz VCI
        // .PLL2VCOSEL = config.PLL2_VCO_SEL, // RCC_PLL2VCOWIDE
    });

    // Disable PLL2FRACN.
    rcc.PLLCFGR.modify_one("PLL2FRACEN", 0);

    // Configures PLL2 clock Fractional Part Of The Multiplication Factor */
    rcc.PLL2FRACR.modify_one("FRACN2", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLL2FRACN.?)))));
    //
    // Enable PLL2FRACN . */
    rcc.PLLCFGR.modify_one("PLL2FRACEN", 1);
    // Enable the PLL2 clock output */

    const div_name = switch (divider) {
        .DivP => "DIVP2EN",
        .DivQ => "DIVQ2EN",
        .DivR => "DIVR2EN",
    };

    rcc.PLLCFGR.modify_one(div_name, 1);
    // Enable  PLL2. */
    rcc.CR.modify_one("PLL2ON", 1);

    // Wait till PLL2 is ready */
    try wait_for_flag(.PLL2RDY, 1, PLLTimeout);
}

fn pll3_config(comptime tree_out: ClockTree.Tree_Output, comptime divider: DivUpdate) !void {
    const config = tree_out.config;

    if (rcc.PLLCKSELR.read().PLLSRC == .DISABLE) {
        return error.PllError;
    }

    // Disable  PLL3. */
    rcc.CR.modify_one("PLL3ON", 0);
    try wait_for_flag(.PLL3RDY, 0, PLLTimeout);

    // Configure the PLL3 multiplication and division factors. */
    const divm3: RCC.PLLM = @enumFromInt(@as(u32, @intFromFloat(config.DIVM3.?)));
    rcc.PLLCKSELR.modify_one("DIVM3", divm3);
    rcc.PLL3DIVR.modify(.{
        .DIVN3 = @as(RCC.PLLN, @enumFromInt(@as(u32, @intFromFloat(config.DIVN3.?)) - 1)),
        .DIVP3 = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVP3.?)) - 1)),
        .DIVQ3 = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVQ3.?)) - 1)),
        .DIVR3 = @as(RCC.PLLDIV, @enumFromInt(@as(u32, @intFromFloat(config.DIVR3.?)) - 1)),
    });

    // PLL3 VCI range: 16MHz/6 = 2.67MHz → Range 1 (2-4MHz) = RCC_PLL3VCIRANGE_1
    rcc.PLLCFGR.modify(.{
        // .PLL3RGE = config.PLL3_VCI_Range, // RCC_PLL2VCIRANGE_3 for 16MHz VCI
        // .PLL3VCOSEL = config.PLL3_VCO_SEL, // RCC_PLL2VCOWIDE

        .PLL3RGE = @intFromEnum(config.PLL3_VCI_Range.?),
        .PLL3VCOSEL = @intFromEnum(config.PLL3_VCO_SEL.?),
    });

    // Disable PLL3FRACN.
    rcc.PLLCFGR.modify_one("PLL3FRACEN", 0);

    // Configures PLL3 clock Fractional Part Of The Multiplication Factor */
    rcc.PLL3FRACR.modify_one("FRACN3", @as(u13, @intCast(@as(u32, @intFromFloat(config.PLL3FRACN.?)))));
    // Enable PLL3FRACN
    rcc.PLLCFGR.modify_one("PLL3FRACEN", 1);
    // Enable the PLL3 clock output */

    const div_name = switch (divider) {
        .DivP => "DIVP3EN",
        .DivQ => "DIVQ3EN",
        .DivR => "DIVR3EN",
    };

    rcc.PLLCFGR.modify_one(div_name, 1);

    rcc.PLLCFGR.modify(.{
        .DIVP3EN = 1, // Enable PLL System Clock output. */
        .DIVQ3EN = 1, // Enable PLL1Q Clock output. */
        .DIVR3EN = 1, // Enable PLL1R  Clock output. */
    });
    // Enable  PLL3. */
    rcc.CR.modify_one("PLL3ON", 1);

    // Wait till PLL3 is ready */
    try wait_for_flag(.PLL3RDY, 1, PLLTimeout);
}

//check clocks and return all used outputs
pub fn validate_clocks(comptime config: ClockTree.Config) ClockOutputs {
    const tree_values = ClockTree.ClockTree.init_comptime(config);
    var outputs: ClockOutputs = .{};

    //checks if the clocks of the used peripherals are valid
    outputs.SYS = @intFromFloat(tree_values.SysCLKOutput.get_comptime());

    outputs.AHB = @intFromFloat(tree_values.AHBOutput.get_comptime());
    outputs.APB1 = @intFromFloat(tree_values.APB1Output.get_comptime());
    outputs.APB2 = @intFromFloat(tree_values.APB2Output.get_comptime());
    outputs.APB3 = @intFromFloat(tree_values.APB3Output.get_comptime());
    outputs.APB4 = @intFromFloat(tree_values.APB4Output.get_comptime());
    outputs.TimAPB1 = @intFromFloat(tree_values.Tim1Output.get_comptime());
    outputs.TimAPB2 = @intFromFloat(tree_values.Tim1Output.get_comptime());
    outputs.USART234578 = @intFromFloat(tree_values.USART234578output.get_comptime());
    outputs.USART16 = @intFromFloat(tree_values.USART16output.get_comptime());
    outputs.SAI1 = @intFromFloat(tree_values.SAI1output.get_comptime());

    if (config.MCO1Mult) |_| {
        _ = tree_values.MCOoutput.get_comptime();
    }

    if (config.USBMult) |_| {
        outputs.USB = @intFromFloat(tree_values.USBoutput.get_comptime());
    }

    if (config.ADCMult) |_| {
        outputs.ADC = @intFromFloat(tree_values.ADCoutput.get_comptime());
    }

    return outputs;
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
    rcc.CR.modify(.{ .RC48ON = 1 });

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
    const pll3m_raw: f32 = @floatFromInt(@intFromEnum(rcc.PLLCKSELR.read().DIVM3));
    const pll3m: f32 = if (pll3m_raw != 0) pll3m_raw else 1.0; // avoid div0

    const pll3fracen = rcc.PLLCFGR.read().PLL3FRACEN;
    const fracn3_raw = (rcc.PLL3FRACR.read().FRACN3) >> 3;
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

    const n: f32 = @floatFromInt(@intFromEnum(rcc.PLL3DIVR.read().DIVN3));
    const nfloat: f32 = n + 1.0 + fracn3 / 8192.0;

    const pll3vco: f32 = (pll_input / pll3m) * nfloat;

    // divisors
    const pdiv: f32 = @floatFromInt(@intFromEnum(rcc.PLL3DIVR.read().DIVP3) + 1);
    const qdiv: f32 = @floatFromInt(@intFromEnum(rcc.PLL3DIVR.read().DIVQ3) + 1);
    const rdiv: f32 = @floatFromInt(@intFromEnum(rcc.PLL3DIVR.read().DIVR3) + 1);

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
        rcc.D2CCIP1R.modify_one("SAI1SRC", @as(u3, @intCast(clk.get())));
    }

    //---------------------------- SAI2/3 configuration -------------------------------*/
    if (config.SAI23CLockSelection) |clk| {
        switch (clk) {
            .RCC_SAI23CLKSOURCE_PLL3 => try pll3_config(tree_out, .DivP),
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP1R.modify_one("SAI23SRC", @as(u3, @intCast(@intFromEnum(clk))));
    }

    //---------------------------- QSPI configuration -------------------------------*/
    if (config.QSPICLockSelection) |clk| {
        switch (clk) {
            .RCC_QSPICLKSOURCE_D1HCLK => {},
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("QSPISRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //---------------------------- SPI1/2/3 configuration -------------------------------*/
    if (config.SPI123CLockSelection) |clk| {
        switch (clk) {
            .RCC_SPI123CLKSOURCE_PLL2 => try pll2_config(tree_out, .DivP),
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP1R.modify_one("SPI123SRC", @as(u3, @intCast(@intFromEnum(clk))));
    }

    //---------------------------- FMC configuration -------------------------------*/
    if (config.FMCCLockSelection) |clk| {
        switch (clk) {
            .RCC_FMCCLKSOURCE_PLL2 => try pll2_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("FMCSRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //-------------------------- USART1/6 configuration --------------------------*/
    if (config.USART16CLockSelection) |clk| {
        switch (clk) {
            .RCC_USART16CLKSOURCE_D2PCLK2 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USART16SRC", @as(u3, @intCast(@intFromEnum(clk))));
    }

    //-------------------------- USART2/3/4/5/7/8 Configuration --------------------------*/
    if (config.USART234578CLockSelection) |clk| {
        switch (clk) {
            .RCC_USART234578CLKSOURCE_D2PCLK1 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USART234578SRC", @as(u3, @intCast(@intFromEnum(clk))));
    }

    //------------------------------ I2C1/2/3/5* Configuration ------------------------*/
    if (config.I2C123CLockSelection) |clk| {
        switch (clk) {
            .RCC_I2C123CLKSOURCE_D2PCLK1 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("I2C123SRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //------------------------------ I2C4 Configuration ------------------------*/
    if (config.I2C4CLockSelection) |clk| {
        switch (clk) {
            .RCC_I2C4CLKSOURCE_PLL3 => try pll3_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D3CCIPR.modify_one("I2C4SRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //---------------------------- ADC configuration -------------------------------*/
    if (config.ADCCLockSelection) |clk| {
        switch (clk) {
            .RCC_ADCCLKSOURCE_PLL3 => try pll3_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D3CCIPR.modify_one("ADCSRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //------------------------------ USB Configuration -------------------------*/
    if (config.USBCLockSelection) |clk| {
        switch (clk) {
            .RCC_USBCLKSOURCE_HSI48 => {},
            else => @panic("Not implemented!"),
        }
        rcc.D2CCIP2R.modify_one("USBSRC", @as(u2, @intCast(@intFromEnum(clk))));
    }

    //------------------------------------- SDMMC Configuration ------------------------------------*/
    if (config.SDMMC1CLockSelection) |clk| {
        switch (clk) {
            .RCC_SDMMCCLKSOURCE_PLL2 => try pll2_config(tree_out, .DivR),
            else => @panic("Not implemented!"),
        }
        rcc.D1CCIPR.modify_one("SDMMCSRC", @as(u1, @intCast(@intFromEnum(clk))));
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
        .SRAM => rcc.AHBENR.modify(.{ .SRAMEN = state }),
        .FLASH => rcc.AHBENR.modify(.{ .FLASHEN = state }),
        .CRC => rcc.AHBENR.modify(.{ .CRCEN = state }),
        .FSMC => rcc.AHBENR.modify(.{ .FSMCEN = state }), //F103xE
        .SDIO => rcc.AHBENR.modify(.{ .SDIOEN = state }), //F103xC/D/E

        // APB2ENR (APB2 peripherals)
        .AFIO => rcc.APB2ENR.modify(.{ .AFIOEN = state }),
        .GPIOA => rcc.APB2ENR.modify(.{ .GPIOAEN = state }),
        .GPIOB => rcc.APB2ENR.modify(.{ .GPIOBEN = state }),
        .GPIOC => rcc.APB2ENR.modify(.{ .GPIOCEN = state }),
        .GPIOD => rcc.APB2ENR.modify(.{ .GPIODEN = state }),
        .GPIOE => rcc.APB2ENR.modify(.{ .GPIOEEN = state }),
        .GPIOF => rcc.APB2ENR.modify(.{ .GPIOFEN = state }), //F103xE
        .GPIOG => rcc.APB2ENR.modify(.{ .GPIOGEN = state }), //F103xE
        .ADC1 => rcc.APB2ENR.modify(.{ .ADC1EN = state }),
        .ADC2 => rcc.APB2ENR.modify(.{ .ADC2EN = state }),
        .TIM1 => rcc.APB2ENR.modify(.{ .TIM1EN = state }),
        .SPI1 => rcc.APB2ENR.modify(.{ .SPI1EN = state }),
        .USART1 => rcc.APB2ENR.modify(.{ .USART1EN = state }),

        // APB1ENR (APB1 peripherals)
        .TIM2 => rcc.APB1ENR.modify(.{ .TIM2EN = state }),
        .TIM3 => rcc.APB1ENR.modify(.{ .TIM3EN = state }),
        .TIM4 => rcc.APB1ENR.modify(.{ .TIM4EN = state }),
        .TIM5 => rcc.APB1ENR.modify(.{ .TIM5EN = state }), //F103xE
        .TIM6 => rcc.APB1ENR.modify(.{ .TIM6EN = state }), //F103xE
        .TIM7 => rcc.APB1ENR.modify(.{ .TIM7EN = state }), //F103xE
        .WWDG => rcc.APB1ENR.modify(.{ .WWDGEN = state }),
        .SPI2 => rcc.APB1ENR.modify(.{ .SPI2EN = state }),
        .SPI3 => rcc.APB1ENR.modify(.{ .SPI3EN = state }), //F103xD/E
        .USART2 => rcc.APB1ENR.modify(.{ .USART2EN = state }),
        .USART3 => rcc.APB1ENR.modify(.{ .USART3EN = state }),
        .UART4 => rcc.APB1ENR.modify(.{ .UART4EN = state }), //F103xC/D/E
        .UART5 => rcc.APB1ENR.modify(.{ .UART5EN = state }), //F103xC/D/E
        .I2C1 => rcc.APB1ENR.modify(.{ .I2C1EN = state }),
        .I2C2 => rcc.APB1ENR.modify(.{ .I2C2EN = state }),
        .I2C3 => rcc.APB1ENR.modify(.{ .I2C3EN = state }),
        .I2C4 => rcc.APB4ENR.modify(.{ .I2C4EN = state }),
        .USB => rcc.APB1ENR.modify(.{ .USBEN = state }),
        .CAN => rcc.APB1ENR.modify(.{ .CANEN = state }),
        .BKP => rcc.APB1ENR.modify(.{ .BKPEN = state }),
        .PWR => rcc.APB1ENR.modify(.{ .PWREN = state }),
        .DAC => rcc.APB1ENR.modify(.{ .DACEN = state }), //F103xE
    }
}

pub fn enable_clock(peri: RccPeriferals) void {
    set_clock(peri, 1);
}

//NOTE: should we panic on invalid clocks?
//errors at comptime appear for peripherals manually configured like USB.
///if requests the clock of an unconfigured peripheral, 0 means error, != 0 means ok
pub fn get_clock(source: RccPeriferals) u32 {
    return switch (source) {
        // AHB peripherals
        .DMA1,
        .DMA2,
        .SRAM,
        .FLASH,
        .CRC,
        => clock_outputs.AHB,

        .FSMC => clock_outputs.FSMC,
        .SDIO => clock_outputs.SDIO,

        // APB2 peripherals
        .AFIO,
        .GPIOA,
        .GPIOB,
        .GPIOC,
        .GPIOD,
        .GPIOE,
        .GPIOF,
        .GPIOG,
        .SPI1,
        .USART1,
        => clock_outputs.APB2,

        .ADC1, .ADC2 => clock_outputs.ADC,

        .TIM1 => clock_outputs.TimAPB2,

        // APB1 peripherals
        .TIM2, .TIM3, .TIM4, .TIM5, .TIM6, .TIM7 => clock_outputs.TimAPB1,

        .DAC => clock_outputs.APB1,

        .WWDG,
        .SPI2,
        .SPI3,
        .USART2,
        .USART3,
        .UART4,
        .UART5,
        .I2C1,
        .I2C2,
        .I2C3,
        .CAN,
        .BKP,
        .PWR,
        => clock_outputs.APB1,

        .I2C4 => clock_outputs.APB4,
        
        .USB => clock_outputs.USB,
    };
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
