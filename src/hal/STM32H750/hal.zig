const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;
const RCC = chip.peripherals.RCC;
const scb = cpu.peripherals.scb;

pub const rcc = @import("rcc.zig");
pub const pins = @import("pins.zig");
pub const gpio = @import("gpio.zig");
// pub const exti = @import("exti.zig");
pub const uart = @import("uart.zig");
// pub const i2c = @import("i2c.zig");
// pub const spi = @import("spi.zig");
// pub const drivers = @import("drivers.zig");
// pub const timer = @import("timer.zig");
// pub const usb = @import("usb.zig");
// pub const adc = @import("adc.zig");
// pub const crc = @import("crc.zig");
pub const power = @import("power.zig");
// pub const backup = @import("backup.zig");
// pub const rtc = @import("rtc.zig");
// pub const dma = @import("DMA.zig");
pub const clock = @import("clock.zig");
pub const mpu = @import("mpu.zig");
pub const time = @import("time.zig");
pub const dma = @import("dma.zig");

pub const utils = @import("util.zig");
pub const errors = @import("errors.zig");

pub fn init_vector_table() void {
    // SCB base address (System Control Block)
    // const SCB_CPACR: *volatile u32 = @ptrFromInt(0xE000ED88);
    // SCB_CPACR.* |= 0xF << 20;

    const fpu = microzig.chip.peripherals.FPU_CPACR;
    // Set CP10 and CP11 to full access
    fpu.CPACR.modify_one("CP", 0xF);

    // Data & Instruction Synchronization Barriers
    cpu.dmb();
    cpu.isb();

    // Reset RCC clock configuration to default state
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

    //* in case of initialized data in D2 SRAM (AHB SRAM) , enable the D2 SRAM clock ((AHB SRAM clock) */
    RCC.AHB2ENR.modify(.{
        .SRAM1EN = 1,
        .SRAM2EN = 1,
        .SRAM3EN = 1,
    });

    const tmpreg = RCC.AHB2ENR.read();
    _ = tmpreg;

    errors.delay(1000);

    // STM32H7 revY workaround
    // Change  the switch matrix read issuing capability to 1 for the AXI SRAM target (Target 7) */
    if ((chip.peripherals.DBGMCU.IDC.raw & 0xFFFF0000) < 0x20000000) {
        // AXI_TARG7_FN_MOD
        const mysctic_ptr: *volatile u32 = @ptrFromInt(0x51008108);
        mysctic_ptr.* = 0x00000001;
        // @ptrCast(*volatile u32, @intToPtr(0x51008108)).* = 0x00000001;
    }

    scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}
