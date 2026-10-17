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

/// Seed header pin names (D0..D32, A0..A13, LED).
pub const seed = @import("seed_pins.zig");

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
        .BaseAddress = 0xC0000000,
        .AccessPermission = .FullAccess,
        .DisableExec = .Enable,
        .SubRegionDisable = 0,

        .bufferable = .Enabled,
        .cacheable = .Enabled,
        .Shareable = .Disabled,
        .number = 1,
        .TypeExtField = .Level0,
        .Size = .Size64MB,
    });

    // Configure the backup SRAM region as non-cacheable
    try hal.mpu.config_region(.{
        .enable = .Enabled,
        .BaseAddress = 0x38800000,
        .AccessPermission = .FullAccess,
        .DisableExec = .Enable,
        .SubRegionDisable = 0,

        .cacheable = .Disabled,
        .bufferable = .Disabled,
        .Shareable = .Disabled,
        .number = 2,
        .TypeExtField = .Level1,
        .Size = .Size4KB,
    });

    hal.mpu.enable();
}

fn dma_init() !void {
    // DMA controller clock enable
    rcc.AHB1ENR.modify_one("DMA1EN", 1);
    _ = rcc.AHB1ENR.read().DMA1EN;

    rcc.AHB1ENR.modify_one("DMA2EN", 1);
    _ = rcc.AHB1ENR.read().DMA2EN;

    // DMA interrupt init. Only streams with a handler in hal.default_interrupts
    // may be enabled: a stray IRQ on any other stream would hit microzig's
    // "unhandled interrupt" panic.
    // SAI1 block A/B (audio).
    cpu.interrupt.set_priority(.DMA1_Stream0, .highest);
    cpu.interrupt.enable(.DMA1_Stream0);
    cpu.interrupt.set_priority(.DMA1_Stream1, .highest);
    cpu.interrupt.enable(.DMA1_Stream1);
    // SPI1 TX (display). One level below the audio, which may preempt it:
    // the display's completion interrupt starts the next tile, tens of µs.
    cpu.interrupt.set_priority(.DMA2_Stream3, display_priority);
    cpu.interrupt.enable(.DMA2_Stream3);
}

/// The display's SPI and DMA interrupts: one level below the audio's.
pub const display_priority: cpu.interrupt.Priority = @enumFromInt(1);

fn sai_init() !void {
    // SAI1 global interrupt for error handling (OVRUDR, AFSDET, LFSDET, WCKCFG)
    cpu.interrupt.enable(.SAI1);
    cpu.interrupt.set_priority(.SAI1, .highest);
}

fn uart_init() !void {
    //
}

/// The Daisy Seed board (libdaisy `DaisySeed`). Declare one at module scope
/// (`var seed: zmetal.Seed = .{};`) — the audio DMA keeps pointers into it, so
/// it must not move after `init`.
pub const Daisy = struct {
    pub const Config = struct {
        /// Codec + USB audio format (sample rate, bit depth, block size).
        audio: hal.audio.AudioConfig = .{},
        /// Bring up the 64 MB FMC SDRAM at 0xC0000000.
        sdram: bool = true,
        /// Bring up the 8 MB QSPI NOR flash (indirect mode).
        qspi: bool = true,
    };

    sai: hal.sai.SaiDriver = undefined,
    /// Audio format in use (from `Config.audio`); read by USB audio.
    audio: hal.audio.AudioConfig = .{},
    /// Audio-ISR CPU load meter; see `cpuLoad`.
    load_meter: hal.cpu_load.CpuLoadMeter = .{},
    led: hal.Gpio = undefined,

    /// Bring up clocks, power, MPU, caches, DMA, the user LED, the codec + SAI,
    /// and (per `config`) SDRAM/QSPI. Peripherals on the header pins (I2C, SPI,
    /// UART, ...) are left to the application.
    pub fn init(self: *Daisy, config: Config) !void {
        self.audio = config.audio;
        microzig.interrupt.enable_interrupts();

        try hal_init();

        // Always configure clocks: correct for direct-from-flash boot and for a
        // modern (v6+) Daisy bootloader, where the app owns clock setup. (Only
        // legacy <v6 bootloaders pre-configured clocks; if ever targeted, gate
        // this on the bootloader-version stamp in backup SRAM — see libdaisy.)
        try configure_clocks();

        // hal_init() set up SysTick on the pre-PLL clock (it must be running for
        // configure_clocks' HSE/PLL-ready timeouts). Now that the PLL is applied
        // and SystemCoreClock reflects it, re-init the tick so its 1 ms period —
        // and therefore delay_ms — is accurate. Mirrors ST HAL_RCC_ClockConfig,
        // which re-calls HAL_InitTick after switching the system clock.
        hal.clock.hal_init_tick(hal.clock.uwTickPrio) catch return error.ClockSetupError;

        try configure_mpu();

        try dma_init();
        try sai_init();

        hal.cache.enableDCache();
        hal.cache.enableICache();

        self.led = hal.Gpio.init(seed.LED, .{});

        // SDRAM: the MPU region (configure_mpu) already marks 0xC0000000
        // cacheable + bufferable, and D-cache is enabled above — libdaisy order.
        if (config.sdram) hal.sdram.init();

        // QSPI NOR: usable afterwards via hal.qspi.read/write/eraseSector, or
        // enableMemoryMapped() for direct reads at hal.qspi.BASE (0x90000000).
        if (config.qspi) try hal.qspi.init();

        // SAI after clocks and interrupts are ready, from the audio config.
        self.sai = try hal.sai.SaiDriver.init(hal.sai.configFromAudio(self.audio));

        // CPU-load meter: enable the DWT cycle counter and size the meter to the
        // audio block (cycles/block = coreclk/rate * blocksize; block rate = rate/blocksize).
        hal.dwt.enableCycleCounter();
        self.load_meter = hal.cpu_load.CpuLoadMeter.init(
            (hal.clock.SystemCoreClock / self.audio.rateHz()) * self.audio.blocksize,
            @as(f32, @floatFromInt(self.audio.rateHz())) / @as(f32, @floatFromInt(self.audio.blocksize)),
        );
    }

    pub fn setLed(self: *Daisy, on: bool) void {
        self.led.write(on);
    }

    pub fn toggleLed(self: *Daisy) void {
        self.led.toggle();
    }

    /// Audio-callback CPU load (avg + peak, 0..1); resets the peak hold.
    pub fn cpuLoad(self: *Daisy) hal.cpu_load.Load {
        return self.load_meter.read();
    }

    /// Start audio with a plain callback: `fn (in, out) void`, interleaved
    /// stereo, `out` zeroed on entry. Runs in the audio DMA interrupt.
    pub fn startAudio(self: *Daisy, comptime callback: fn (in: []const f32, out: []f32) void) !void {
        try self.sai.start(.{ .ctx = null, .func = struct {
            fn call(_: ?*anyopaque, in: []const f32, out: []f32) void {
                callback(in, out);
            }
        }.call }, &self.load_meter);
    }

    /// Start audio with a context: `callback(ctx, in, out)`, e.g.
    /// `seed.startAudioCtx(&my_engine, Engine.process)`. `ctx` must outlive audio.
    pub fn startAudioCtx(self: *Daisy, ctx: anytype, comptime callback: fn (@TypeOf(ctx), []const f32, []f32) void) !void {
        const Ctx = @TypeOf(ctx);
        try self.sai.start(.{ .ctx = @ptrCast(ctx), .func = struct {
            fn call(c: ?*anyopaque, in: []const f32, out: []f32) void {
                callback(@as(Ctx, @ptrCast(@alignCast(c.?))), in, out);
            }
        }.call }, &self.load_meter);
    }
};
