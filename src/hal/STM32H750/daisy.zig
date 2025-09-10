const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;
const RCC = chip.peripherals.RCC;

const hal = @import("hal.zig");
const stm32 = hal;
const rcc_hal = stm32.rcc;

const h7clock = @import("clocks/clock_stm32h750.zig");
// const clock_cfg = h7clock.Config{};
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

const SysConfig = SystemConfig{ .freq = .boost };

pub const clk_config = stm32.rcc.Config{
    .HSE_Timout = @enumFromInt(5000),
    .HSEOSC = @enumFromInt(16_000_000), // Daisy uses 16Mhz external OSC

    .PLLSource = .RCC_PLLSOURCE_HSE,

    // Values from libdaisy src
    .DIVM1 = @enumFromInt(4),
    .DIVN1 = if (SysConfig.freq == .boost) @enumFromInt(240) else @enumFromInt(200),
    .DIVQ1 = @enumFromInt(5),
    .DIVR1 = @enumFromInt(2),
    .PLLFRACN = @enumFromInt(0),

    // NOTE: Below is calculated based on HSE frequency
    // RCC_OscInitStruct.PLL.PLLRGE    = RCC_PLL1VCIRANGE_2;
    // RCC_OscInitStruct.PLL.PLLVCOSEL = RCC_PLL1VCOWIDE;
    // | Parameter             | Formula                      | Config Range | Datasheet Constraint |
    // | --------------------- | ---------------------------- | ------------ | -------------------- |
    // | **VCI (PLL1 input)**  | `PLL Source / DIVM1`         | DIVM1: 1–63  | 1–16 MHz             |
    // | **VCO (PLL1 output)** | `VCI × (DIVN1 + FRACN/8192)` | DIVN1: 4–512 | 192–836 MHz          |

    .SysClkSource = .RCC_SYSCLKSOURCE_PLLCLK,
    // RCC_ClkInitStruct.ClockType
    // = RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_PCLK1
    //       | RCC_CLOCKTYPE_PCLK2 | RCC_CLOCKTYPE_D3PCLK1 | RCC_CLOCKTYPE_D1PCLK1;
    .D1CPRE = .RCC_SYSCLK_DIV1,
    .HPRE = .RCC_HCLK_DIV2,
    .D1PPRE = .RCC_APB3_DIV2,
    .D2PPRE1 = .RCC_APB1_DIV2,
    .D2PPRE2 = .RCC_APB2_DIV2,
    .D3PPRE = .RCC_APB4_DIV2,
};

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

const D1CorePrescTable: [16]u8 = [_]u8{ 0, 0, 0, 0, 1, 2, 3, 4, 1, 2, 3, 4, 6, 7, 8, 9 };
pub fn hal_init() !bool {
    //  Set Interrupt Group Priority */
    set_priority_grouping(.Group4);

    // Update the SystemCoreClock global variable
    const clk_tmp = hal.clock.get_sys_clock_freq();
    const d1cpre = chip.peripherals.RCC.D1CFGR.read().D1CPRE;
    const shift = D1CorePrescTable[@intFromEnum(d1cpre)] & 0x1F;
    const common_system_clock: u32 = clk_tmp >> @intCast(shift);
    hal.clock.SystemCoreClock = common_system_clock;

    // Update the SystemD2Clock global variable
    const d1_hpre_index = @intFromEnum(chip.peripherals.RCC.D1CFGR.read().HPRE);
    const shift_2 = D1CorePrescTable[d1_hpre_index] & 0x1F;
    hal.clock.SystemD2Clock = common_system_clock >> @intCast(shift_2);

    try hal.clock.hal_init_tick(.highest);
    // //* Init the low level hardware */
    // HAL_MspInit();

    //* Return function status */
    return true;
}

const PWR = microzig.chip.types.peripherals.PWR;

pub fn configure_clocks() !void {
    const sys_cfg = SystemConfig{};
    if (!hal.power.config_ext_power_supply(.LDO)) {
        return error.PowerError;
    }

    var flash_latency: PWR.VOS = undefined;
    switch (sys_cfg.freq) {
        .boost => {
            flash_latency = @enumFromInt(4);
        },
        .default => {
            flash_latency = .Scale2;
        },
    }

    try hal.rcc.apply_clock(clk_config);
}

pub fn init() !void {
    _ = try hal_init();
    try configure_clocks();
}
