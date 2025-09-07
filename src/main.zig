// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");
const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

const chip_peri = chip.peripherals;

const daisy = @import("hal/STM32H750/daisy.zig");

const hal = @import("hal/STM32H750/hal.zig");
const stm32 = hal;
const rcc = stm32.rcc;
const errors = @import("hal/STM32H750/errors.zig");
pub const panic = errors.panic;

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;

pub fn init_systick(tick_limit: u24) void {
    cpu.interrupt.enable_interrupts();
    cpu.interrupt.exception.set_priority(.SysTick, .highest);
    // Disable SysTick first
    systick.CTRL.modify(.{
        .ENABLE = 0,
        .TICKINT = 0,
        .CLKSOURCE = 0,
    });
    systick.LOAD.modify(.{ .RELOAD = tick_limit });
    systick.VAL.modify(.{ .CURRENT = 0 });
    systick.CTRL.modify(.{
        .ENABLE = 1,
        .TICKINT = 1,
        .CLKSOURCE = 1,
    });
}

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
    },
};

const led = hal.gpio.Pin.init("C", "7");
var count: u32 = 1;

pub fn sys_tick_handler() callconv(.c) void {
    count = count + 1;
    if (count >= 1000) {
        led.toggle();
        count = 0;
    }
}

pub fn init_vector_table() void {
    scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}

pub fn main() !void {
    init_vector_table();
    rcc.apply_clock(daisy.clk_config) catch errors.error_handler();
    // Use a more conservative clock assumption
    // Most STM32H750 run at 64MHz by default, not 400MHz
    const system_clock_hz = 64_000_000; // Adjust based on your clock config
    const ticks_per_ms = system_clock_hz / 1000;
    init_systick(ticks_per_ms - 1);
    led.configure();
    led.toggle();

    while (true) {
        cpu.wfi();
    }
}
