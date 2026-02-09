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
const time = microzig.drivers.time;

// Import the HAL from microzig.hal (now provided by build system)
pub const hal = microzig.hal;
const errors = hal.errors;
pub const panic = errors.panic;

// Daisy board support
const ssai = hal.sai;
const SaiDriver = ssai.SaiDriver;

const osc = @import("dsp/osc.zig");

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
        .HardFault = .{ .c = hw_handler },
        .NMI = .{ .c = nmi_handler },
        .MemManageFault = .{ .c = mem_manage_fault_handler },
        .BusFault = .{ .c = bus_fault_handler },
        .UsageFault = .{ .c = usage_fault_handler },
        .SVCall = .{ .c = sv_call_handler },
        .PendSV = .{ .c = hw_handler },

        .DMA1_STR0 = .{ .c = ssai.dma1_0_handler },
        .DMA1_STR1 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR2 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR3 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR4 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR5 = .{ .c = ssai.dma1_1_handler },
        // .DMA1_STR6 = .{ .c = ssai.dma1_1_handler },
    },

    .logFn = hal.uart.log,
};

fn hw_handler() callconv(.c) void {
    @breakpoint();
    @panic("HardFault");
}
fn nmi_handler() callconv(.c) void {
    @breakpoint();
    @panic("NMI");
}
fn mem_manage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("MemManageFault");
}
fn bus_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("BusFault");
}
fn usage_fault_handler() callconv(.c) void {
    @breakpoint();
    @panic("UsageFault");
}
fn sv_call_handler() callconv(.c) void {
    @breakpoint();
    @panic("SVCall");
}

var count: u32 = 1;

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    count += 1;
    if (count == 1_000) {
        hw.led.toggle();
    } else if (count == 1100) {
        hw.led.toggle();
    } else if (count == 1200) {
        hw.led.toggle();
    } else if (count == 1300) {
        hw.led.toggle();
        count = 0;
    }
}

pub fn init() void {
    // FIXME: For SRAM build, no need to call below
    // hal.init_vector_table();
}

var hw: hal.daisy.Daisy = undefined;

var sine = osc.SineOsc.init(440, 48000, 0.02);
var square = osc.SquareOsc.init(440.0, 48000, 0.02);

pub fn main() !void {
    hw = try hal.daisy.Daisy.init();

    // Configure LED pin as output
    const RCC_peri = chip.peripherals.RCC;
    RCC_peri.AHB4ENR.modify(.{ .GPIOCEN = 1 }); // Enable GPIOC clock

    // Test toggle

    try hw.startAudio(myAudioCallback);

    while (true) {
        cpu.wfi();
    }
}

fn myAudioCallback(input: []const f32, output: []f32, size: u16) void {
    _ = input;
    var i: u32 = 0;
    while (i < size) : (i += 2) {
        const samp = sine.nextSample();
        output[i] = samp;
        output[i + 1] = samp;
    }
}
