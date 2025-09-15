const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;
const rcc = chip.peripherals.RCC;

const chip_peri = chip.types.peripherals;
const FLASH = chip_peri.Flash;
const PWR = chip_peri.PWR;

const hal = @import("hal.zig");
const stm32 = hal;
const rcc_hal = stm32.rcc;

const h7clock = @import("clocks/clock_stm32h750.zig");
const Clock = h7clock.ClockTree.init_comptime(clk_config);

const plln_val = 200; //boost or 200 for default

pub const SystemConfig = struct {
    pub const SysFreq = enum {
        default,
        boost,
    };

    use_dcache: bool = true,
    use_icache: bool = true,
    skip_clocks: bool = false,
    freq: SysFreq = .default,
};

// const SysConfig = SystemConfig{ .freq = .default };
const SysConfig = SystemConfig{ .freq = .boost };

pub const clk_config = stm32.rcc.Config{
    .HSE_Timout = @enumFromInt(5000),
    .HSEOSC = @enumFromInt(16_000_000), // Daisy uses 16Mhz external OSC

    .PLLSource = .RCC_PLLSOURCE_HSE,

    // Values from libdaisy src
    .DIVN1 = if (SysConfig.freq == .boost) @enumFromInt(240) else @enumFromInt(200),
    .DIVM1 = @enumFromInt(4),
    .DIVP1 = .@"2",
    .DIVQ1 = @enumFromInt(5),
    .DIVR1 = @enumFromInt(2),
    .PLLFRACN = @enumFromInt(0),

    .SysClkSource = .RCC_SYSCLKSOURCE_PLLCLK,
    .D1CPRE = .RCC_SYSCLK_DIV1,
    .HPRE = .RCC_HCLK_DIV2,
    .D1PPRE = .RCC_APB3_DIV2,
    .D2PPRE1 = .RCC_APB1_DIV2,
    .D2PPRE2 = .RCC_APB2_DIV2,
    .D3PPRE = .RCC_APB4_DIV2,

    // NOTE: Below is calculated based on HSE frequency
    // RCC_OscInitStruct.PLL.PLLRGE    = RCC_PLL1VCIRANGE_2;
    // RCC_OscInitStruct.PLL.PLLVCOSEL = RCC_PLL1VCOWIDE;
    // | Parameter             | Formula                      | Config Range | Datasheet Constraint |
    // | --------------------- | ---------------------------- | ------------ | -------------------- |
    // | **VCI (PLL1 input)**  | `PLL Source / DIVM1`         | DIVM1: 1–63  | 1–16 MHz             |
    // | **VCO (PLL1 output)** | `VCI × (DIVN1 + FRACN/8192)` | DIVN1: 4–512 | 192–836 MHz          |

    // PeriphClkInitStruct.PeriphClockSelection
    //     = RCC_PERIPHCLK_USART1 | RCC_PERIPHCLK_USART6
    //       | RCC_PERIPHCLK_USART234578 | RCC_PERIPHCLK_LPUART1
    //       | RCC_PERIPHCLK_RNG | RCC_PERIPHCLK_SPI1 | RCC_PERIPHCLK_SAI2
    //       | RCC_PERIPHCLK_SAI1 | RCC_PERIPHCLK_SDMMC | RCC_PERIPHCLK_I2C2
    //       | RCC_PERIPHCLK_ADC | RCC_PERIPHCLK_I2C1 | RCC_PERIPHCLK_USB
    //       | RCC_PERIPHCLK_QSPI | RCC_PERIPHCLK_FMC;

    .DIVN2 = @enumFromInt(12), // Max supported freq of FMC
    .DIVM2 = @enumFromInt(1),
    .DIVP2 = @enumFromInt(8),
    .DIVQ2 = @enumFromInt(2),
    .DIVR2 = @enumFromInt(1),
    .PLL2FRACN = @enumFromInt(4096),

    // PeriphClkInitStruct.PLL2.PLL2RGE    = RCC_PLL2VCIRANGE_2;
    // PeriphClkInitStruct.PLL2.PLL2VCOSEL = RCC_PLL2VCOWIDE;

    // PLL 3
    .DIVM3 = @enumFromInt(6),
    .DIVN3 = @enumFromInt(295),
    .DIVP3 = @enumFromInt(16),
    .DIVQ3 = @enumFromInt(4),
    .DIVR3 = @enumFromInt(32),
    .PLL3FRACN = @enumFromInt(0),

    // PeriphClkInitStruct.PLL3.PLL3RGE       = RCC_PLL3VCIRANGE_1;
    // PeriphClkInitStruct.PLL3.PLL3VCOSEL    = RCC_PLL3VCOWIDE;

    .FMCMult = .RCC_FMCCLKSOURCE_PLL2,
    .QSPIMult = .RCC_QSPICLKSOURCE_D1HCLK,
    .SDMMCMult = .RCC_SDMMCCLKSOURCE_PLL2,
    .SAI1Mult = .RCC_SAI1CLKSOURCE_PLL3,
    .SAI23Mult = .RCC_SAI23CLKSOURCE_PLL3,
    .SPI123Mult = .RCC_SPI123CLKSOURCE_PLL2,
    .USART234578Mult = .RCC_USART234578CLKSOURCE_D2PCLK1,
    .USART16Mult = .RCC_USART16CLKSOURCE_D2PCLK2,
    .I2C123Mult = .RCC_I2C123CLKSOURCE_D2PCLK1,
    .I2C4Mult = .RCC_I2C4CLKSOURCE_PLL3,
    .USBMult = .RCC_USBCLKSOURCE_HSI48,
    .ADCMult = .RCC_ADCCLKSOURCE_PLL3,
};

pub const clock_outputs = hal.rcc.validate_clocks(clk_config);

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

    try hal.clock.hal_init_tick(.highest);
    // Init the low level hardware
    // HAL_MspInit();
}

pub fn configure_clocks() !void {
    if (!hal.power.config_ext_power_supply(.LDO)) {
        return error.PowerError;
    }

    var flash_latency: FLASH.LATENCY = undefined;
    switch (SysConfig.freq) {
        .boost => {
            flash_latency = .WS4;
        },
        .default => {
            flash_latency = .WS2;
        },
    }

    try hal.rcc.apply_clock(clk_config, flash_latency);
}

fn configure_mpu() !void {
    hal.mpu.disable();

    // Configure RAM D2 (SRAM1) as non cacheable
    try hal.mpu.config_region(.{
        .enable = .Enabled,
        .BaseAddress = 0x30000000,
        .Size = .Size32KB,
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
    cpu.interrupt.set_priority(.DMA_STR0, .highest);
    cpu.interrupt.enable(.DMA_STR0);
    // DMA1_Stream1_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA_STR1, .highest);
    cpu.interrupt.enable(.DMA_STR1);
    // DMA1_Stream2_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA_STR2, .highest);
    cpu.interrupt.enable(.DMA_STR2);
    // DMA1_Stream3_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA_STR3, .highest);
    cpu.interrupt.enable(.DMA_STR3);
    // DMA1_Stream4_IRQn interrupt configuration
    cpu.interrupt.set_priority(.DMA_STR4, .highest);
    cpu.interrupt.enable(.DMA_STR4);
    // DMA1_Stream5_IRQn and DMA2_Stream4_IRQn interrupt configuration for uart rx and tx
    cpu.interrupt.set_priority(.DMA_STR5, .highest);
    cpu.interrupt.enable(.DMA_STR5);
    cpu.interrupt.set_priority(.DMA2_STR4, .highest);
    cpu.interrupt.enable(.DMA2_STR4);
    // DMA1_Stream6_IRQn interrupt configuration for I2C
    cpu.interrupt.set_priority(.DMA_STR6, .highest);
    cpu.interrupt.enable(.DMA_STR6);
    // DMA2_Stream0_IRQn, interrupt configuration for DAC Ch1
    cpu.interrupt.set_priority(.DMA2_STR0, .highest);
    cpu.interrupt.enable(.DMA2_STR0);
    // DMA2_Stream1_IRQn, interrupt configuration for DAC Ch2
    cpu.interrupt.set_priority(.DMA2_STR1, .highest);
    cpu.interrupt.enable(.DMA2_STR1);

    // DMA2_Stream2_IRQn and DMA2_Stream3_IRQn interrupt configuration for SPI
    cpu.interrupt.set_priority(.DMA2_STR2, .highest);
    cpu.interrupt.enable(.DMA2_STR2);
    cpu.interrupt.set_priority(.DMA2_STR3, .highest);
    cpu.interrupt.enable(.DMA2_STR3);
}

fn i2c_init() !void {
    //
}

fn spi_init() !void {
    //
}

fn uart_init() !void {
    //
}

pub fn init() !void {
    try hal_init();
    try configure_clocks();
    try configure_mpu();

    try dma_init();
    try i2c_init();
    try spi_init();
    try uart_init();
}
