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
const daisy = hal.daisy;
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
const led = hal.gpio.OutputGPIO(led_pin);

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    count += 1;
    if (count == 1_000) {
        led.toggle();
    } else if (count == 1100) {
        led.toggle();
    } else if (count == 1200) {
        led.toggle();
    } else if (count == 1300) {
        led.toggle();
        count = 0;
    }
}

pub fn init() void {
    hal.init_vector_table();
}

// Configure LED on PC7 using custom GPIO API
const led_pin = hal.gpio.Pin.init("C", "7", .{
    .mode = .output,
    .pull = .Floating,
    .otype = .PushPull,
    .speed = .LowSpeed,
});

var sine = osc.SineOsc.init(110, 48000, 0.9);
var square = osc.SquareOsc.init(220.0, 48000, 0.9);

var buff: [600]u32 = undefined;

pub fn main() !void {
    try daisy.init();

    // Configure LED pin as output
    const RCC_peri = chip.peripherals.RCC;
    RCC_peri.AHB4ENR.modify(.{ .GPIOCEN = 1 }); // Enable GPIOC clock
    led_pin.configure();

    // Test toggle
    led.toggle();

    var sai = SaiDriver.init(.{
        .sample_rate = .@"48khz",
        .bit_depth = .@"24bit",
        .a_sync = .master,
        .b_sync = .slave,
        .a_dir = .transmit,
        .b_dir = .receive,
    });

    try sai.setup();
    try sai.startAudio(myAudioCallback);

    // var freq: f32 = 32.7;
    // sine.setFreq(freq);
    // while (true) {
    //     cpu.wfi();
    //     hal.clock.delay(4000);
    //     freq *= 2;
    //     if (freq > 1800) {
    //         freq = 110.0;
    //     }
    //     sine.setFreq(freq);
    // }

    while (true) {
        cpu.wfi();
    }
}

var samps: u32 = 0;
var c: u32 = 0;
fn myAudioCallback(input: []const u32, output: []u32) void {
    _ = input;
    var i: u32 = 0;
    while (i < output.len) : (i += 2) {
        const samp = ssai.fto24(sine.nextSample());
        output[i] = samp;
        output[i + 1] = samp;
    }
}
