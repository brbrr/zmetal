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

const daisy = @import("hal/STM32H750/daisy.zig");

pub const hal = @import("hal/STM32H750/hal.zig");
const errors = hal.errors;
pub const panic = errors.panic;
const ssai = @import("hal/STM32H750/sai.zig");
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
        led.toggle();
        // } else if (count == 1100) {
        //     led.toggle();
        // } else if (count == 1200) {
        //     led.toggle();
        // } else if (count == 1300) {
        //     led.toggle();
        count = 0;
    }
}

pub fn init() void {
    hal.init_vector_table();
}

const led = hal.gpio.Pin.init("C", "7", .{});

var sine = osc.SineOsc.init(220.0, 48000, 0.9);
var square = osc.SquareOsc.init(220.0, 48000, 0.9);

var buff: [600]u32 = undefined;

pub fn main() !void {
    daisy.init() catch {
        errors.error_handler();
    };
    led.configure();
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

    // samps = generateFreq(220, 48000);
    // try sai.startAudio(myAudioCallback);

    try sai.enable();
    try transmitSquareForever(220.0);
    while (true) {
        cpu.nop();
    }
}

fn generateFreq(freq: f32, sr: f32) u32 {
    const samples: u32 = @intFromFloat(sr / freq);

    var sq = osc.SquareOsc.init(freq, sr, 0.9);
    for (0..samples) |i| {
        buff[i] = ssai.fto24(sq.nextSample());
    }

    return samples;
}

var samps: u32 = 0;
var c: u32 = 0;
fn myAudioCallback(input: []const u32, output: []u32) void {
    _ = input;
    var i: u32 = 0;
    while (i < output.len) : (i += 2) {
        // output[i] = buff[c];
        output[i] = ssai.fto24(sine.nextSample());
        // output[i] = ssai.fto24(square.nextSample());
        output[i + 1] = output[i];
    }
}

fn transmitSquareForever(freq: f32) !void {
    // var o = osc.SquareOsc.init(freq, 48000, 0.9);
    const regs = chip_peri;
    var ff: f32 = 110;
    while (true) {
        const dc_val = ssai.fto24(0.0);
        var cnt: u32 = 0;
        while (cnt < 48000 * 2) {
            ssai.monitorSaiErrors();
            while (regs.SAI1.SAI_ASR.read().FLVL == 5) {} // Wait if FIFO full
            regs.SAI1.SAI_ADR.raw = dc_val;
            regs.SAI1.SAI_ADR.raw = dc_val;
            cnt += 1;
        }

        var o = osc.SineOsc.init(ff, 48000, 0.7);
        cnt = 0;
        while (cnt < 48000 * 2) {
            ssai.monitorSaiErrors();
            const sample = o.nextSample();
            const samp = ssai.fto24(sample);
            while (regs.SAI1.SAI_ASR.read().FLVL == 5) {} // Wait if FIFO full
            regs.SAI1.SAI_ADR.modify_one("DATA", samp);
            regs.SAI1.SAI_ADR.modify_one("DATA", samp);
            cnt += 1;
        }
        _ = freq;
        ff *= 2;
        if (ff > 1000) {
            ff = 110;
        }
    }
}
