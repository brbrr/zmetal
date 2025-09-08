//NOTE: this file is only valid for densities: Low, Medium, High, and XL. Connectivity line devices are not supported in this version.
//TODO: Add support for 105/107
const std = @import("std");
const microzig = @import("microzig");

// const find_clocktree = @import("util.zig").find_clock_tree;
// const ClockTree = find_clocktree(microzig.config.chip_name);
const H750Clock = @import("clocks/clock_stm32h750.zig");
const ClockTree = H750Clock;
const power = @import("power.zig");

//expose only the configuration structs
pub const Config = ClockTree.Config;
pub const ConfigWithRef = ClockTree.ConfigWithRef;

const flash = microzig.chip.peripherals.FLASH;
const rcc = microzig.chip.peripherals.RCC;
const perih_types = microzig.chip.types.peripherals;
const RCC = perih_types.rcc_h7rm0433;

const flash_v1 = perih_types.flash_h7;
const PLLMUL = RCC.PLLM;
const PLLSRC = RCC.PLLSRC;
const PLLXTPRE = RCC.PLLXTPRE;
const PPRE = RCC.PPRE;
const HPRE = RCC.HPRE;
const ADCPRE = RCC.ADCPRE;
const USBPRE = RCC.USBPRE;
const RTCSEL = RCC.RTCSEL;
const MCO1SEL = RCC.MCO1SEL;
const MCO2SEL = RCC.MCO2SEL;
const SW = RCC.SW;

const ClockInitError = error{
    HSETimeout,
    LSETimeout,
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

    //Peripheral clocks
    FSMC: u32 = 0,
    SDIO: u32 = 0,
    TimAPB1: u32 = 0,
    TimAPB2: u32 = 0,
    ADC: u32 = 0,
    USB: u32 = 0,
};

pub const Bus = enum {
    // AHB, //AHB cannot be reset by software
    APB1,
    APB2,
};

pub const FlashLatency = enum(u3) {
    Latency0 = 0, // FLASH Zero Latency cycle
    Latency1 = 1, // FLASH One Latency cycle
    Latency2 = 2, // FLASH Two Latency cycles
    Latency3 = 3, // FLASH Three Latency cycles
    Latency4 = 4, // FLASH Four Latency cycles
    Latency5 = 5, // FLASH Five Latency cycles
    Latency6 = 6, // FLASH Six Latency cycles
    Latency7 = 7, // FLASH Seven Latency cycles
    // Legacy stuff
    // Latency8 = 8,  // FLASH Eight Latency cycle
    // Latency9 = 9,  // FLASH Nine Latency cycle
    // Latency10 = 10, // FLASH Ten Latency cycles
    // Latency11 = 11, // FLASH Eleven Latency cycles
    // Latency12 = 12, // FLASH Twelve Latency cycles
    // Latency13 = 13, // FLASH Thirteen Latency cycles
    // Latency14 = 14, // FLASH Fourteen Latency cycles
    // Latency15 = 15, // FLASH Fifteen Latency cycles
};

//default clock config
var corrent_clocks: ClockOutputs = validate_clocks(.{});

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
        1 => RCC.CR.raw,
        2 => RCC.BDCR.raw,
        3 => RCC.CSR.raw,
        4 => RCC.RSR.raw,
        else => RCC.CIFR.raw,
    };

    return if ((reg_val & (1 << bit_pos)) != 0) 1 else 0;
}

//NOTE: procedural style or loop through all elements of the struct?
///Configures the system clocks
///NOTE: to configure the backup domain clocks (RTC) it is necessary to enable it through the power
///register before configuring the clocks
pub fn apply_clock(comptime config: ClockTree.Config) ClockInitError!void {
    const clck = comptime validate_clocks(config);

    set_flash(clck.SYS);

    //rest all clock configs
    secure_enable();
    if (config.HSICalibrationValue) |val| {
        config_HSI(@intFromEnum(val));
    }

    try config_PLL(config);
    config_peripherals(config);
    try config_RTC(config);
    try config_system_clock(config);
    config_MCO(config);
    corrent_clocks = clck;
}

//check clocks and return all used outputs
fn validate_clocks(comptime config: ClockTree.Config) ClockOutputs {
    const tree_values = ClockTree.ClockTree.init_comptime(config);
    var outputs: ClockOutputs = .{};

    //checks if the clocks of the used peripherals are valid
    outputs.SYS = @intFromFloat(tree_values.SysCLKOutput.get_comptime());

    outputs.AHB = @intFromFloat(tree_values.AHBOutput.get_comptime());
    outputs.APB1 = @intFromFloat(tree_values.APB1Output.get_comptime());
    outputs.APB2 = @intFromFloat(tree_values.APB2Output.get_comptime());
    outputs.TimAPB1 = @intFromFloat(tree_values.Tim1Output.get_comptime());
    outputs.TimAPB2 = @intFromFloat(tree_values.Tim1Output.get_comptime());

    if (config.MCO1Mult) |_| {
        _ = tree_values.MCOoutput.get_comptime();
    }

    if (config.USBMult) |_| {
        outputs.USB = @intFromFloat(tree_values.USBoutput.get_comptime());
        if (config.PLLSource) |src| {
            if (src == .RCC_PLLSOURCE_HSI_DIV2) {
                @compileError("USB clock is not stable when PLL source is HSI");
            }
        }
    }

    if (config.ADCMult) |_| {
        outputs.ADC = @intFromFloat(tree_values.ADCoutput.get_comptime());
    }

    return outputs;
}

fn set_flash(clock: u32) void {
    var latency: FlashLatency = .Latency7;
    power.set_volage_scalling(.Scale1);
    if (clock <= 400_000_000) {
        power.set_volage_scalling(.Scale1);
        latency = .Latency2;
    } else if (clock <= 480_000_000) {
        power.set_volage_scalling(@enumFromInt(0));
        latency = .Latency4;
    } else {
        @breakpoint();
        unreachable;
        // @compileError("invalid sysclock?");
    }

    flash.ACR.modify_one("LATENCY", @intFromEnum(latency));
    while (!power.get_flag(.VOSRDY)) {
        microzig.cpu.nop();
    }
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
        .@"PLLON[0]" = 0,
        .@"PLLON[1]" = 0,
        .@"PLLON[2]" = 0,

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

fn config_HSE(comptime config: ClockTree.Config) ClockInitError!void {
    rcc.CR.modify(.{ .HSEON = 1 });

    const max_wait: u32 = if (config.HSE_Timout) |val| @intFromEnum(val) else std.math.maxInt(u32);
    var ticks: usize = 0;
    while (rcc.CR.read().HSERDY == 0) {
        if (ticks == max_wait - 1) return error.HSETimeout;
        ticks += 1;
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_LSE(comptime config: ClockTree.Config) ClockInitError!void {
    const max_wait: u32 = if (config.LSE_Timeout) |val| @intFromEnum(val) else std.math.maxInt(u32);
    var ticks: usize = 0;
    rcc.BDCR.modify(.{ .LSEON = 1 });
    while (rcc.BDCR.read().LSERDY == 0) {
        if (ticks == max_wait - 1) return error.LSETimeout;
        ticks += 1;
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_PLL(comptime config: ClockTree.Config) ClockInitError!void {
    if (config.PLLSource) |src| {
        const s: u2 = @intFromEnum(src);
        const val: PLLSRC = @enumFromInt(s);
        rcc.PLLCKSELR.modify(.{ .PLLSRC = val });
        if (val == .HSE) {
            try config_HSE(config);
        }
    }

    // if (config.HSEDivPLL) |pre| {
    //     const p: u1 = @intFromEnum(pre);
    //     const val: PLLXTPRE = @enumFromInt(p);
    //     rcc.CFGR.modify(.{ .PLLXTPRE = val });
    // }
    //
    // if (config.PLLMUL) |pre| {
    //     const p: u32 = @intFromEnum(pre);
    //     const val: PLLMUL = @enumFromInt(p);
    //     rcc.CFGR.modify(.{ .PLLMUL = val });
    // }
}

//TODO: Add STM32F105/7 devices peri
fn config_peripherals(comptime config: ClockTree.Config) void {
    _ = config;
    // if (config.APB1Prescaler) |pre| {
    //     const p: u32 = @intFromEnum(pre);
    //     const val: PPRE = @enumFromInt(p);
    //     rcc.D2CFGR.modify(.{ .D2PPRE1 = val });
    // }
    //
    // if (config.APB2Prescaler) |pre| {
    //     const p: u32 = @intFromEnum(pre);
    //     const val: PPRE = @enumFromInt(p);
    //     rcc.D2CFGR.modify(.{ .D2PPRE2 = val });
    // }
    //
    // if (config.AHBPrescaler) |pre| {
    //     const p: u32 = @intFromEnum(pre);
    //     const val: HPRE = @enumFromInt(p);
    //     rcc.D1CFGR.modify(.{ .HPRE = val });
    // }
    //
    // if (config.ADCprescaler) |pre| {
    //     const p: u32 = @intFromEnum(pre);
    //     const val: ADCPRE = @enumFromInt(p);
    //     rcc.D3CFGR.modify(.{ .D3PPRE = val });
    // }
    //
    // if (config.USBPrescaler) |pre| {
    //     const p: u1 = switch (pre) {
    //         .RCC_USBCLKSOURCE_PLL_DIV1_5 => 0,
    //         .RCC_USBCLKSOURCE_PLL => 1,
    //     };
    //     const val: USBPRE = @enumFromInt(p);
    //     rcc.CFGR.modify(.{ .USBPRE = val });
    // }
}

fn config_system_clock(comptime config: ClockTree.Config) ClockInitError!void {
    if (config.SysClkSource) |src| {
        const val: u2 = @intFromEnum(src);
        const e_val: SW = @enumFromInt(val);
        switch (val) {
            1 => try config_HSE(config),
            2 => init_pll(),
            else => {},
        }

        rcc.CFGR.modify(.{ .SW = e_val });
        while (true) {
            const sws = rcc.CFGR.read().SWS;
            if (sws == e_val) break;
            asm volatile ("" ::: .{ .memory = true });
        }
    }
}

fn init_pll() void {
    rcc.CR.modify(.{ .PLLON = 1 });
    while (rcc.CR.read().PLLRDY == 0) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

fn config_RTC(comptime config: ClockTree.Config) ClockInitError!void {
    if (config.RTCClkSource) |src| {
        //enable backup domain
        enable_clock(.PWR);
        enable_clock(.BKP);
        power.backup_domain_protection(false);

        var rtcs: RTCSEL = .DISABLE;
        switch (src) {
            .RCC_RTCCLKSOURCE_HSE_DIV128 => {
                rtcs = .HSE;
                try config_HSE(config);
            },
            .RCC_RTCCLKSOURCE_LSE => {
                rtcs = .LSE;
                try config_LSE(config);
            },
            .RCC_RTCCLKSOURCE_LSI => {
                rtcs = .LSI;
                config_LSI();
            },
        }

        rcc.BDCR.modify(.{ .RTCSEL = rtcs });
        power.backup_domain_protection(true);

        // Disable and reset clocks to avoid potential conflicts with the main application
        disable_clock(.BKP);
        reset_clock(.BKP);
        disable_clock(.PWR);
        reset_clock(.PWR);
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

///after the reset, the BDRD becomes read_only until access is released by the power register
///this function can also be called from `backup.reset()`
pub fn reset_backup_domain() void {
    rcc.BDCR.modify(.{ .BDRST = 1 });
    for (0..5) |i| {
        std.mem.doNotOptimizeAway(i);
    }
    rcc.BDCR.modify(.{ .BDRST = 0 });
}

///configure the power and clock registers before enabling the RTC
///this function also can be called from `rtc.enable()`
pub fn enable_RTC(on: bool) void {
    rcc.BDCR.modify(.{ .RTCEN = @intFromBool(on) });
}

///backup domain is not reset with the rest of the system
///so this function can be used to check if the RTC is already running.
pub fn rtc_running() bool {
    return rcc.BDCR.read().RTCEN != 0;
}

///This function is called internally by the HAL, the RESET value should only be read after the RESET
///read the Reset value through the global variable hal.RESET
pub fn get_reset_reason() ResetReason {
    const flags = rcc.RSR.read();
    // comptime {
    //     const info = @typeInfo(@TypeOf(flags));
    //     for (info.@"struct".fields) |field| {
    //         @compileLog("Field: {s}, Type: {s}\n", .{ field.name, @typeName(field.type) });
    //     }
    // }

    const rst: ResetReason = blk: {
        if (flags.PINRSTF == 1) break :blk ResetReason.NRST;
        if (flags.PORRSTF == 1) break :blk ResetReason.POR_or_PDR;
        if (flags.SFTRSTF == 1) break :blk ResetReason.low_power;
        if (flags.IWDG1RSTF == 1) break :blk ResetReason.independent_watchdog;
        if (flags.WWDG1RSTF == 1) break :blk ResetReason.window_watchdog;
        if (flags.LPWRRSTF == 1) break :blk ResetReason.low_power;
        break :blk ResetReason.POR_or_PDR;
    };

    rcc.RSR.modify(.{ .RMVF = 1 });
    return rst;
}

///reset the selected peripheral to they default state.
///this is useful to get the peripheral out of a deadlock state or
///to put the peripheral in a known state before configuring it.
///
///NOTE: this function does not effect the ENR (clock enable) registers.
pub fn reset_clock(peri: RccPeriferals) void {

    //set the selected peripheral reset bit
    switch (peri) {
        // APB2RSTR (APB2 peripherals)
        .AFIO => rcc.APB2RSTR.modify(.{ .AFIORST = 1 }),
        .GPIOA => rcc.APB2RSTR.modify(.{ .GPIOARST = 1 }),
        .GPIOB => rcc.APB2RSTR.modify(.{ .GPIOBRST = 1 }),
        .GPIOC => rcc.APB2RSTR.modify(.{ .GPIOCRST = 1 }),
        .GPIOD => rcc.APB2RSTR.modify(.{ .GPIODRST = 1 }),
        .GPIOE => rcc.APB2RSTR.modify(.{ .GPIOERST = 1 }),
        .GPIOF => rcc.APB2RSTR.modify(.{ .GPIOFRST = 1 }), //F103xE
        .GPIOG => rcc.APB2RSTR.modify(.{ .GPIOGRST = 1 }), //F103xE
        .ADC1 => rcc.APB2RSTR.modify(.{ .ADC1RST = 1 }),
        .ADC2 => rcc.APB2RSTR.modify(.{ .ADC2RST = 1 }),
        .TIM1 => rcc.APB2RSTR.modify(.{ .TIM1RST = 1 }),
        .SPI1 => rcc.APB2RSTR.modify(.{ .SPI1RST = 1 }),
        .USART1 => rcc.APB2RSTR.modify(.{ .USART1RST = 1 }),

        // APB1RSTR (APB1 peripherals)
        .TIM2 => rcc.APB1RSTR.modify(.{ .TIM2RST = 1 }),
        .TIM3 => rcc.APB1RSTR.modify(.{ .TIM3RST = 1 }),
        .TIM4 => rcc.APB1RSTR.modify(.{ .TIM4RST = 1 }),
        .TIM5 => rcc.APB1RSTR.modify(.{ .TIM5RST = 1 }), //F103xE
        .TIM6 => rcc.APB1RSTR.modify(.{ .TIM6RST = 1 }), //F103xE
        .TIM7 => rcc.APB1RSTR.modify(.{ .TIM7RST = 1 }), //F103xE
        .WWDG => rcc.APB1RSTR.modify(.{ .WWDGRST = 1 }),
        .SPI2 => rcc.APB1RSTR.modify(.{ .SPI2RST = 1 }),
        .SPI3 => rcc.APB1RSTR.modify(.{ .SPI3RST = 1 }), //F103xD/E
        .USART2 => rcc.APB1RSTR.modify(.{ .USART2RST = 1 }),
        .USART3 => rcc.APB1RSTR.modify(.{ .USART3RST = 1 }),
        .UART4 => rcc.APB1RSTR.modify(.{ .UART4RST = 1 }), //F103xC/D/E
        .UART5 => rcc.APB1RSTR.modify(.{ .UART5RST = 1 }), //F103xC/D/E
        .I2C1 => rcc.APB1RSTR.modify(.{ .I2C1RST = 1 }),
        .I2C2 => rcc.APB1RSTR.modify(.{ .I2C2RST = 1 }),
        .USB => rcc.APB1RSTR.modify(.{ .USBRST = 1 }),
        .CAN => rcc.APB1RSTR.modify(.{ .CANRST = 1 }),
        .BKP => rcc.APB1RSTR.modify(.{ .BKPRST = 1 }),
        .PWR => rcc.APB1RSTR.modify(.{ .PWRRST = 1 }),
        .DAC => rcc.APB1RSTR.modify(.{ .DACRST = 1 }), //F103xE
        else => {},
    }
    //release the reset, this is necessary because the reset bits are not self-clearing
    //write 0 to all bits is safe becuse 0 does nothing (other than releasing the reset)
    rcc.APB2RSTR.raw = 0;
    rcc.APB1RSTR.raw = 0;
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

pub fn disable_clock(peri: RccPeriferals) void {
    set_clock(peri, 0);
}

pub fn enable_all_clocks() void {
    //enable all clocks
    rcc.AHBENR.raw = std.math.maxInt(u32);
    rcc.APB1ENR.raw = std.math.maxInt(u32);
    rcc.APB2ENR.raw = std.math.maxInt(u32);
}

pub fn disable_all_clocks() void {
    //disable all clocks
    rcc.AHBENR.raw = 0;
    rcc.APB1ENR.raw = 0;
    rcc.APB2ENR.raw = 0;
}

///Reset all periferals of the specified bus to they default state.
///NOTE: this function does not effect the ENR registers.
pub fn reset_bus(bus: Bus) void {
    //first write 1 to all bits to reset them
    //then write 0 to all bits to release the reset
    //this is necessary because the reset bits are not self-clearing
    switch (bus) {
        .APB1 => {
            rcc.APB1RSTR.raw = std.math.maxInt(u32);
            rcc.APB1RSTR.raw = 0;
        },
        .APB2 => {
            rcc.APB2RSTR.raw = std.math.maxInt(u32);
            rcc.APB2RSTR.raw = 0;
        },
    }
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
        => corrent_clocks.AHB,

        .FSMC => corrent_clocks.FSMC,
        .SDIO => corrent_clocks.SDIO,

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
        => corrent_clocks.APB2,

        .ADC1, .ADC2 => corrent_clocks.ADC,

        .TIM1 => corrent_clocks.TimAPB2,

        // APB1 peripherals
        .TIM2, .TIM3, .TIM4, .TIM5, .TIM6, .TIM7 => corrent_clocks.TimAPB1,

        .DAC => corrent_clocks.APB1,

        .WWDG,
        .SPI2,
        .SPI3,
        .USART2,
        .USART3,
        .UART4,
        .UART5,
        .I2C1,
        .I2C2,
        .CAN,
        .BKP,
        .PWR,
        => corrent_clocks.APB1,

        .USB => corrent_clocks.USB,
    };
}

pub inline fn get_sys_clk() u32 {
    return corrent_clocks.SYS;
}
