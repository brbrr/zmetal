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
pub const timer = stm32_common.timer_v1;
pub const systick = stm32_common.systick;

// I2C and SPI implementations with Daisy-specific configuration
pub const i2c = @import("i2c.zig");
pub const spi = @import("spi.zig");

// GPIO: comptime pin driver (used by the peripheral drivers).
pub const gpio = @import("gpio.zig");

// Pin values (one Pin type for every driver) + runtime GPIO handle.
pub const pin_name = @import("pin_name.zig");
pub const Port = pin_name.Port;
pub const Pin = pin_name.Pin;
pub const Gpio = @import("gpio_rt.zig").Gpio;

/// Comptime pin by name, e.g. `hal.pin("PC7")`.
pub fn pin(comptime name: []const u8) Pin {
    return comptime pin_name.parse(name) catch @compileError("bad pin name: " ++ name);
}

// Custom implementations (Daisy-specific or have custom extensions)
pub const rcc = @import("rcc.zig");
pub const usart = @import("uart.zig"); // uart_v3-based driver (RX interrupt for MIDI)
pub const sdmmc = @import("sdmmc.zig"); // SDMMC1 + SD-card block driver
pub const sdram = @import("sdram.zig"); // FMC SDRAM (64 MB @ 0xC0000000)
pub const qspi = @import("qspi.zig"); // QUADSPI NOR flash (8 MB @ 0x90000000, indirect mode)
pub const dma = @import("dma.zig"); // Has custom audio API
pub const power = @import("power.zig");
pub const clock = @import("clock.zig");
pub const mpu = @import("mpu.zig");
pub const time = @import("time.zig");
pub const cache = @import("cache.zig");
pub const fault = @import("fault.zig");
pub const tick_math = @import("tick_math.zig"); // pure SysTick µs math (zmetal.time)

// Daisy-specific modules
pub const daisy = @import("daisy.zig");
pub const sai = @import("sai.zig");
pub const audio = @import("audio.zig"); // runtime audio format config (SAI + USB)
pub const cpu_load = @import("cpu_load.zig"); // audio-ISR CPU load meter
pub const dwt = @import("dwt.zig"); // Cortex-M7 cycle counter (feeds cpu_load)
pub const usb = @import("usb/usb.zig");
pub const usb_audio = @import("usb/usb_audio.zig"); // UAC2 <-> SAI bridge callback

const options = @import("zmetal_options");

/// Interrupt handlers the HAL owns. microzig merges these into the vector
/// table; an app that also lists one gets a compile error unless it sets
/// `overwrite_hal_interrupts`. Apps list only their own IRQs.
pub const default_interrupts: microzig.cpu.InterruptOptions = blk: {
    var t: microzig.cpu.InterruptOptions = .{
        .SysTick = .{ .c = clock.sys_tick_handler },
        .HardFault = .{ .naked = fault.hard_fault },
        .NMI = .{ .c = fault.nmi_handler },
        .MemManageFault = .{ .naked = fault.mem_manage_fault },
        .BusFault = .{ .naked = fault.bus_fault },
        .UsageFault = .{ .naked = fault.usage_fault },
        .SVCall = .{ .c = fault.sv_call_handler },
        .PendSV = .{ .c = fault.hw_handler },
        // Audio: SAI1 block A/B DMA + SAI1 error IRQ.
        .DMA1_Stream0 = .{ .c = sai.dma1_0_handler },
        .DMA1_Stream1 = .{ .c = sai.dma1_1_handler },
        .SAI1 = .{ .c = sai.SaiDriver.sai1_irq_handler },
        // Display SPI1 + its TX DMA stream.
        .SPI1 = .{ .c = spi.spi1_irq_handler },
        .DMA2_Stream3 = .{ .c = spi.tx_dma_irq_handler },
        // MIDI IN (USART1 RX).
        .USART1 = .{ .c = usart.UartStream(.USART1).irqHandler },
    };
    if (options.usb) {
        // Only the active controller's NVIC line is enabled (by usb.init).
        t.OTG_FS = .{ .c = usb.otg_fs_irq_handler };
        t.OTG_HS = .{ .c = usb.otg_hs_irq_handler };
    }
    break :blk t;
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

/// Early chip init: RCC reset, D2 SRAM clocks, silicon-revision workarounds.
/// Runs automatically before `main` (microzig calls `hal.init`); an app-level
/// `pub fn init` in the root file replaces it.
pub fn init() void {
    reset_rcc();
    enable_sram_clocks();
    apply_h7_workarounds();
}

/// Reset RCC (Reset and Clock Control) to default state
fn reset_rcc() void {
    // Match libdaisy reset behavior: keep HSI running during RCC reset.
    RCC.CR.modify_one("HSION", 1);
    while (RCC.CR.read().HSIRDY != 1) {}
    RCC.CFGR.raw = 0x00000000;
    RCC.CR.raw &= 0xEAF6ED7F;
    RCC.D1CFGR.raw = 0x00000000;
    RCC.D2CFGR.raw = 0x00000000;
    RCC.D3CFGR.raw = 0x00000000;
    RCC.PLLCKSELR.raw = 0x00000000;
    RCC.PLLCFGR.raw = 0x00000000;
    RCC.@"PLLDIVR[0]".raw = 0x00000000;
    RCC.@"PLLFRACR[0]".raw = 0x00000000;
    RCC.@"PLLDIVR[1]".raw = 0x00000000;
    RCC.@"PLLFRACR[1]".raw = 0x00000000;
    RCC.@"PLLDIVR[2]".raw = 0x00000000;
    RCC.@"PLLFRACR[2]".raw = 0x00000000;
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
