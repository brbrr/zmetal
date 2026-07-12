const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;
const rcc = chip.peripherals.RCC;

const chip_peri = chip.types.peripherals;
const FLASH = chip_peri.flash_h7;
const PWR = chip_peri.pwr_h7rm0433;

const hal = @import("hal.zig");
const stm32 = hal;
const rcc_hal = stm32.rcc;

pub const SystemConfig = struct {
    pub const SysFreq = enum(u16) {
        default = 200,
        boost = 240,
    };

    use_dcache: bool = true,
    use_icache: bool = true,
    skip_clocks: bool = false,
    freq: SysFreq = .default,
};

// pub const SysConfig = SystemConfig{ .freq = .default };
pub const SysConfig = SystemConfig{ .freq = .boost };

const ClockTree = hal.rcc.ClockTree;

pub const clk_config = ClockTree.Config{
    .HSE_VALUE = stm32.clock.HSE_VALUE,

    .PLLSource = .RCC_PLLSOURCE_HSE,

    // Values from libdaisy src
    .DIVN1 = @intFromEnum(SysConfig.freq),
    .DIVM1 = 4,
    .DIVP1 = .@"2",
    .DIVQ1 = 5,
    .DIVR1 = 2,
    .PLLFRACN = 0,

    .SYSCLKSource = .RCC_SYSCLKSOURCE_PLLCLK, // Use PLL1 as system clock
    .D1CPRE = .RCC_SYSCLK_DIV1,
    .HPRE = .RCC_HCLK_DIV2,
    .D1PPRE = .RCC_APB3_DIV2,
    .D2PPRE1 = .RCC_APB1_DIV2,
    .D2PPRE2 = .RCC_APB2_DIV2,
    .D3PPRE = .RCC_APB4_DIV2,

    // PeriphClkInitStruct.PeriphClockSelection
    //     = RCC_PERIPHCLK_USART1 | RCC_PERIPHCLK_USART6
    //       | RCC_PERIPHCLK_USART234578 | RCC_PERIPHCLK_LPUART1
    //       | RCC_PERIPHCLK_RNG | RCC_PERIPHCLK_SPI1 | RCC_PERIPHCLK_SAI2
    //       | RCC_PERIPHCLK_SAI1 | RCC_PERIPHCLK_SDMMC | RCC_PERIPHCLK_I2C2
    //       | RCC_PERIPHCLK_ADC | RCC_PERIPHCLK_I2C1 | RCC_PERIPHCLK_USB
    //       | RCC_PERIPHCLK_QSPI | RCC_PERIPHCLK_FMC;

    .DIVN2 = 12, // libdaisy: PLL2N = 12 for FMC @ 100MHz
    .DIVM2 = 1,
    .DIVP2 = 2, // libdaisy 8
    .DIVQ2 = 2,
    .DIVR2 = 1,
    .PLL2FRACN = 4096,

    // PeriphClkInitStruct.PLL2.PLL2RGE    = RCC_PLL2VCIRANGE_2;
    // PeriphClkInitStruct.PLL2.PLL2VCOSEL = RCC_PLL2VCOWIDE;

    // PLL 3
    .DIVM3 = 6,
    .DIVN3 = 295,
    .DIVP3 = 16,
    .DIVQ3 = 4,
    .DIVR3 = 32,
    .PLL3FRACN = 0,

    // PeriphClkInitStruct.PLL3.PLL3RGE       = RCC_PLL3VCIRANGE_1;
    // PeriphClkInitStruct.PLL3.PLL3VCOSEL    = RCC_PLL3VCOWIDE;

    .FMCCLockSelection = .RCC_FMCCLKSOURCE_PLL2,
    .QSPICLockSelection = .RCC_QSPICLKSOURCE_D1HCLK,
    .SDMMC1CLockSelection = .RCC_SDMMCCLKSOURCE_PLL2,
    .SAI1CLockSelection = .RCC_SAI1CLKSOURCE_PLL3,
    .SAI23CLockSelection = .RCC_SAI23CLKSOURCE_PLL3,
    .SPI123CLockSelection = .RCC_SPI123CLKSOURCE_PLL2,
    .USART234578CLockSelection = .RCC_USART234578CLKSOURCE_D2PCLK1,
    .USART16CLockSelection = .RCC_USART16CLKSOURCE_D2PCLK2,
    .I2C123CLockSelection = .RCC_I2C123CLKSOURCE_D2PCLK1,
    .I2C4CLockSelection = .RCC_I2C4CLKSOURCE_PLL3,
    .USBCLockSelection = .RCC_USBCLKSOURCE_HSI48,
    .ADCCLockSelection = .RCC_ADCCLKSOURCE_PLL3,

    .flags = .{
        // SAI peripherals
        .SAI1_SAIAUsed_ForRCC = true, // Enable SAI1 block A
        .SAI1_SAIBUsed_ForRCC = true, // Enable SAI1 block B
        .SAI2_SAIAUsed_ForRCC = true, // Enable SAI2 block A (SAI23CLockSelection)
        .SAI2_SAIBUsed_ForRCC = true, // Enable SAI2 block B (SAI23CLockSelection)

        // SPI peripherals
        .SPI1Used_ForRCC = true, // SPI1 (SPI123CLockSelection)
        .SPI2Used_ForRCC = true, // SPI2 (SPI123CLockSelection)
        .SPI3Used_ForRCC = true, // SPI3 (SPI123CLockSelection)

        // Memory interfaces
        .FMCUsed_ForRCC = true, // FMC (FMCCLockSelection)
        .QUADSPIUsed_ForRCC = true, // QSPI (QSPICLockSelection)
        .SDMMC1Used_ForRCC = true, // SDMMC (SDMMC1CLockSelection)

        // I2C peripherals
        .I2C1Used_ForRCC = true, // I2C1 (I2C123CLockSelection)
        .I2C2Used_ForRCC = true, // I2C2 (I2C123CLockSelection)
        .I2C3Used_ForRCC = true, // I2C3 (I2C123CLockSelection)
        .I2C4Used_ForRCC = true, // I2C4 (I2C4CLockSelection)

        // UART/USART peripherals
        .USART1Used_ForRCC = true, // USART1 (USART16CLockSelection)
        .USART6Used_ForRCC = true, // USART6 (USART16CLockSelection)
        .USART2Used_ForRCC = true, // USART2 (USART234578CLockSelection)
        .USART3Used_ForRCC = true, // USART3 (USART234578CLockSelection)
        .UART4Used_ForRCC = true, // UART4 (USART234578CLockSelection)
        .UART5Used_ForRCC = true, // UART5 (USART234578CLockSelection)
        .UART7Used_ForRCC = true, // UART7 (USART234578CLockSelection)
        .UART8Used_ForRCC = true, // UART8 (USART234578CLockSelection)

        // USB and ADC
        .USB_OTG_HSUsed_ForRCC = true, // USB (USBCLockSelection)
        .USE_ADC1 = true, // ADC (ADCCLockSelection)
        .USE_ADC2 = true, // ADC (ADCCLockSelection)
        .USE_ADC3 = true, // ADC (ADCCLockSelection)
        .ADC1UsedAsynchronousCLK_ForRCC = true,
        .ADC2UsedAsynchronousCLK_ForRCC = true,
        .ADC3UsedAsynchronousCLK_ForRCC = true,
    },

    .extra = .{
        .HSE_Timout = 5000,
        .PLL1_VCO_SEL = .RCC_PLL1VCOWIDE,
        .PLL2_VCO_SEL = .RCC_PLL2VCOWIDE,
        .PLL3_VCO_SEL = .RCC_PLL3VCOWIDE,
    },
};

pub const clock_outputs = clocktree_outputs.clock;
pub const clocktree_outputs: ClockTree.Tree_Output = ClockTree.get_clocks(clk_config) catch unreachable;

const NVICPriorityGroup = enum(u3) {
    Group0 = 7,
    Group1 = 6,
    Group2 = 5,
    Group3 = 4,
    Group4 = 3,
};

pub fn set_priority_grouping(priority_group: NVICPriorityGroup) void {
    scb.AIRCR.modify(.{
        .VECTKEY = 0x05FA,
        .PRIGROUP = @intFromEnum(priority_group),
    });
}

pub fn hal_init() !void {
    //  Set Interrupt Group Priority */
    set_priority_grouping(.Group4);

    hal.clock.update_system_core_clock();

    hal.clock.hal_init_tick(hal.clock.uwTickPrio) catch {
        return error.ClockSetupError;
    };
}

pub fn configure_clocks() !void {
    // hal.rcc.verify_peripheral_clocks(clk_config, clocktree_outputs.clock);

    if (!hal.power.config_ext_power_supply(.LDO)) {
        return error.PowerError;
    }

    // microzig's flash ACR.LATENCY is a plain u3 wait-state count (no enum).
    const flash_latency: u3 =
        switch (SysConfig.freq) {
            .boost => 4, // Four wait states (480 MHz, VOS0)
            .default => 2, // Two wait states (400 MHz, VOS1)
        };

    try hal.rcc.apply_clock(clocktree_outputs, flash_latency);
}

fn configure_mpu() !void {
    hal.mpu.disable();

    // Configure RAM D2 (SRAM1) as non cacheable
    // RAM_D2_DMA is 192KB (0x30000000-0x30030000), use 256KB MPU region
    try hal.mpu.config_region(.{
        .enable = .Enabled,
        .BaseAddress = 0x30000000,
        .Size = .Size256KB,
        .AccessPermission = .FullAccess,
        .bufferable = .Disabled,
        .cacheable = .Disabled,
        .Shareable = .Enabled,
        .number = 0,
        .TypeExtField = .Level1,
        .SubRegionDisable = 0,
        .DisableExec = .Enable,
    });

    try hal.mpu.config_region(.{
        .enable = .Enabled,
        .AccessPermission = .FullAccess,
        .DisableExec = .Enable,
        .SubRegionDisable = 0,

        .bufferable = .Enabled,
        .cacheable = .Enabled,
        .Shareable = .Disabled,
        .number = 1,
        .TypeExtField = .Level0,
        .Size = .Size64MB,
        .BaseAddress = 0xC0000000,
    });

    // Configure the backup SRAM region as non-cacheable
    try hal.mpu.config_region(.{
        .enable = .Enabled,
        .AccessPermission = .FullAccess,
        .DisableExec = .Enable,
        .SubRegionDisable = 0,

        .cacheable = .Disabled,
        .bufferable = .Disabled,
        .Shareable = .Disabled,
        .number = 2,
        .TypeExtField = .Level1,
        .Size = .Size4KB,
        .BaseAddress = 0x38800000,
    });

    hal.mpu.enable();
}

fn dma_init() !void {
    // DMA controller clock enable
    rcc.AHB1ENR.modify_one("DMA1EN", 1);
    _ = rcc.AHB1ENR.read().DMA1EN;

    rcc.AHB1ENR.modify_one("DMA2EN", 1);
    _ = rcc.AHB1ENR.read().DMA2EN;

    // DMA interrupt init
    // DMA1_Stream0_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA1_Stream0, .highest);
    cpu.interrupt.enable(.DMA1_Stream0);
    // DMA1_Stream1_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA1_Stream1, .highest);
    cpu.interrupt.enable(.DMA1_Stream1);
    // DMA1_Stream2_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA1_Stream2, .highest);
    cpu.interrupt.enable(.DMA1_Stream2);
    // DMA1_Stream3_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA1_Stream3, .highest);
    cpu.interrupt.enable(.DMA1_Stream3);
    // DMA1_Stream4_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA1_Stream4, .highest);
    cpu.interrupt.enable(.DMA1_Stream4);
    // DMA1_Stream5_IRQn and DMA2_Stream4_IRQn interrupt configuration for uart rx and tx
    cpu.interrupt.set_priority(.DMA1_Stream5, .highest);
    cpu.interrupt.enable(.DMA1_Stream5);
    // DMA1_Stream6_IRQn interrupt configuration for I2C
    cpu.interrupt.set_priority(.DMA1_Stream6, .highest);
    cpu.interrupt.enable(.DMA1_Stream6);

    // DMA2_Stream0_IRQn, interrupt configuration for DAC Ch1
    cpu.interrupt.set_priority(.DMA2_Stream0, .highest);
    cpu.interrupt.enable(.DMA2_Stream0);
    // DMA2_Stream1_IRQn, interrupt configuration for DAC Ch2
    cpu.interrupt.set_priority(.DMA2_Stream1, .highest);
    cpu.interrupt.enable(.DMA2_Stream1);
    // DMA2_Stream2_IRQn and DMA2_Stream3_IRQn interrupt configuration for SPI
    cpu.interrupt.set_priority(.DMA2_Stream2, .highest);
    cpu.interrupt.enable(.DMA2_Stream2);
    cpu.interrupt.set_priority(.DMA2_Stream3, .highest);
    cpu.interrupt.enable(.DMA2_Stream3);
    cpu.interrupt.set_priority(.DMA2_Stream4, .highest);
    cpu.interrupt.enable(.DMA2_Stream4);
}

fn i2c_init() !void {
    // cpu.interrupt.set_priority(.I2C1_EV, .highest);
    // cpu.interrupt.enable(.I2C1_EV);

    // Reset I2C1 peripheral via RCC to clear any stuck BUSY state
    // This is necessary if the I2C bus was in a bad state from previous power cycle
    const rcc_regs = chip.peripherals.RCC;
    rcc_regs.APB1LRSTR.modify(.{ .I2C1RST = 1 });
    var i2c_reset_delay: u32 = 0;
    while (i2c_reset_delay < 200) : (i2c_reset_delay += 1) {
        asm volatile ("nop");
    }
    rcc_regs.APB1LRSTR.modify(.{ .I2C1RST = 0 });
    i2c_reset_delay = 0;
    while (i2c_reset_delay < 200) : (i2c_reset_delay += 1) {
        asm volatile ("nop");
    }
}

fn sai_init() !void {
    // SAI1 global interrupt for error handling (OVRUDR, AFSDET, LFSDET, WCKCFG)
    cpu.interrupt.enable(.SAI1);
    cpu.interrupt.set_priority(.SAI1, .highest);
}

fn spi_init() !void {
    microzig.cpu.interrupt.enable(.SPI1);
    microzig.cpu.interrupt.set_priority(.SPI1, .highest);
}

fn uart_init() !void {
    //
}

pub const Daisy = struct {
    sai: hal.sai.SaiDriver,
    i2c: hal.i2c.I2C_Device,

    comptime led: hal.gpio.Pin = hal.gpio.Pin.init("C", "7", .{
        .mode = .output,
        .pull = .Floating,
        .otype = .PushPull,
        .speed = .LowSpeed,
    }),

    pub fn create() !Daisy {
        return Daisy{
            .sai = undefined,
            .i2c = undefined,
        };
    }

    pub fn init(self: *Daisy) !void {
        microzig.interrupt.enable_interrupts();

        try hal_init();
        try configure_clocks();

        try configure_mpu();

        try dma_init();
        try sai_init();
        try i2c_init();
        try spi_init();
        try uart_init();

        hal.cache.enableDCache();
        hal.cache.enableICache();

        self.led.configure();

        // Initialize SAI after clocks and interrupts are ready
        self.sai = hal.sai.SaiDriver.init(.{});

        // Bring up I2C1 (MCP23017 keyboard expander). i2c_init() above only
        // resets the peripheral; init() enables the clock + configures pins and
        // apply() sets TIMINGR and PE=1. Without this self.i2c stays undefined
        // and the first transfer faults on a garbage register pointer.
        self.i2c = try hal.i2c.I2C_Device.init(.I2C1, .{ .speed = .I2C_400KHZ });
        self.i2c.apply();
    }

    pub fn startAudio(self: *Daisy, callback: *const hal.sai.AudioCallback) !void {
        try self.sai.start(callback);
    }
};
