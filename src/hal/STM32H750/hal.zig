//! HAL implementation for STM32H750 microcontroller
//! This HAL is designed for the Daisy Seed audio platform and follows microzig standards.
//!
//! This HAL uses microzig STM32 common implementations where possible,
//! and provides custom or extended implementations for Daisy-specific features.

const std = @import("std");
const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;
const RCC = chip.peripherals.RCC;
const scb = cpu.peripherals.scb;

// Import STM32 common module (provided by build system)
const stm32_common = @import("stm32_common");

// microzig STM32 common implementations (standard peripherals)
pub const spi = stm32_common.spi_v2;
pub const timer = stm32_common.timer_v1;
pub const systick = stm32_common.systick;

// I2C implementation with Daisy-specific configuration
pub const i2c = @import("i2c.zig");

// Custom implementations: GPIO/Pins incompatible with gpio_v2 (H7 uses AFRL/AFRH not AFR[2])
pub const gpio = @import("gpio.zig");
pub const pins = @import("pins.zig");

// Custom implementations (Daisy-specific or have custom extensions)
pub const rcc = @import("rcc.zig");
pub const uart = @import("uart_custom_backup.zig"); // Has custom log() function
pub const dma = @import("dma_custom_backup.zig"); // Has custom audio API
pub const power = @import("power.zig");
pub const clock = @import("clock.zig");
pub const mpu = @import("mpu.zig");
pub const time = @import("time.zig");
pub const cache = @import("cache.zig");

// Daisy-specific modules
pub const daisy = @import("daisy.zig");
pub const sai = @import("sai.zig");

// Utilities
pub const utils = @import("util.zig");
pub const errors = @import("errors.zig");

/// HAL configuration options
pub const HAL_Options = struct {
    /// RCC clock configuration (applied during initialization)
    rcc_clock_config: rcc.Config = .{},
};

/// Get system clock frequency in Hz
/// Required for microzig systick integration
pub fn get_sys_clk() u32 {
    return clock.get_sys_clock();
}

/// Get SysTick clock frequency in Hz
/// Required for microzig systick integration
pub fn get_systick_clk() u32 {
    return clock.get_sys_clock() / 8;
}

/// Initialize CPU and peripheral configuration
/// This should be called early in the startup process
pub fn init_vector_table() void {
    init_fpu();
    reset_rcc();
    enable_sram_clocks();
    apply_h7_workarounds();
    configure_vector_table();
}

/// Enable FPU (Floating Point Unit) with full access to CP10 and CP11
fn init_fpu() void {
    const fpu = microzig.chip.peripherals.FPU_CPACR;
    fpu.CPACR.modify_one("CP", 0xF);

    // Data & Instruction Synchronization Barriers
    cpu.dmb();
    cpu.isb();
}

/// Reset RCC (Reset and Clock Control) to default state
fn reset_rcc() void {
    RCC.CR.modify_one("HSION", 0);
    RCC.CFGR.raw = 0x00000000;
    RCC.CR.raw &= 0xEAF6ED7F;
    RCC.D1CFGR.raw = 0x00000000;
    RCC.D2CFGR.raw = 0x00000000;
    RCC.D3CFGR.raw = 0x00000000;
    RCC.PLLCKSELR.raw = 0x00000000;
    RCC.PLLCFGR.raw = 0x00000000;
    RCC.PLL1DIVR.raw = 0x00000000;
    RCC.PLL1FRACR.raw = 0x00000000;
    RCC.PLL2DIVR.raw = 0x00000000;
    RCC.PLL2FRACR.raw = 0x00000000;
    RCC.PLL3DIVR.raw = 0x00000000;
    RCC.PLL3FRACR.raw = 0x00000000;
    RCC.CR.raw &= 0xFFFBFFFF;
    RCC.CIER.raw = 0x00000000;
}

/// Enable SRAM clocks for D2 domain
fn enable_sram_clocks() void {
    RCC.AHB2ENR.modify(.{
        .SRAM1EN = 1,
        .SRAM2EN = 1,
        .SRAM3EN = 1,
    });

    // Read-back to ensure write is complete
    _ = RCC.AHB2ENR.read();

    errors.delay(1000);
}

/// Apply STM32H7 silicon revision Y workarounds
fn apply_h7_workarounds() void {
    // Change the switch matrix read issuing capability to 1 for AXI SRAM target (Target 7)
    // Only needed for revision Y silicon (DBGMCU.IDC rev < 0x2000)
    if ((chip.peripherals.DBGMCU.IDC.raw & 0xFFFF0000) < 0x20000000) {
        const axi_targ7_fn_mod: *volatile u32 = @ptrFromInt(0x51008108);
        axi_targ7_fn_mod.* = 0x00000001;
    }
}

/// Configure the vector table offset register
fn configure_vector_table() void {
    // scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}
