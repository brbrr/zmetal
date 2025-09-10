// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const chip_peri = chip.peripherals;
const RCC = chip_peri.RCC;

const daisy = @import("hal/STM32H750/daisy.zig");

const hal = @import("hal/STM32H750/hal.zig");
const stm32 = hal;
const errors = @import("hal/STM32H750/errors.zig");
pub const panic = errors.panic;

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
    },
};

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    count = count + 1;
    if (count >= 1000) {
        led.toggle();
        count = 0;
    }
}

const led = hal.gpio.Pin.init("C", "7");
var count: u32 = 1;

pub fn init_vector_table() void {
    // Set CP10 and CP11 Full Access
    scb.CPACR |= (3 << (10 * 2)) | (3 << (11 * 2));

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

    // STM32H7 revY workaround
    // Change  the switch matrix read issuing capability to 1 for the AXI SRAM target (Target 7) */
    if ((chip_peri.DBGMCU.IDC.raw & 0xFFFF0000) < 0x20000000) {
        const mysctic_ptr: *volatile u32 = @ptrFromInt(0x51008108);
        mysctic_ptr.* = 0x00000001;
        // @ptrCast(*volatile u32, @intToPtr(0x51008108)).* = 0x00000001;
    }

    scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}

pub fn main() !void {
    init_vector_table();
    daisy.init() catch {
        errors.error_handler();
    };

    led.configure();
    led.toggle();

    while (true) {
        cpu.wfi();
    }
}
