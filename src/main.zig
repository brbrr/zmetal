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
const errors = @import("hal/STM32H750/errors.zig");
pub const panic = errors.panic;
const ssai = @import("hal/STM32H750/sai.zig");
const SaiDriver = ssai.SaiDriver;
const osc = @import("dsp/osc.zig");

// INTERNAL_ADDRESS = 0x08000000
// FLASH_ADDRESS ?= $(INTERNAL_ADDRESS)
// dfu-util -a 0 -s 0x08000000:leave -D zig-out/firmware/blinky.bin -d ,0483:df11
// openocd -s /usr/local/share/openocd/scripts -f interface/stlink.cfg -f target/stm32h7x.cfg -c "program ./zig-out/firmware/blinky.elf verify reset exit"

const systick = cpu.peripherals.systick;
const scb = cpu.peripherals.scb;

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
    if ((chip_peri.DBGMCU.IDC.raw & 0xFFFF0000) < 0x20000000) {
        const mysctic_ptr: *volatile u32 = @ptrFromInt(0x51008108);
        mysctic_ptr.* = 0x00000001;
        // @ptrCast(*volatile u32, @intToPtr(0x51008108)).* = 0x00000001;
    }

    scb.VTOR = @intCast(@intFromPtr(&cpu.startup_logic._vector_table));
}

pub fn init() void {
    init_vector_table();
}

const led = hal.gpio.Pin.init("C", "7", .{});

const sai_p_cfg = hal.gpio.PinConfig{
    .mode = .{ .Alternate = .af6 },
    .otype = .PushPull,
    .speed = .HighSpeed,
    .pull = .PullUp,
};
const mclk = hal.gpio.Pin.init("E", "2", sai_p_cfg);
const sb = hal.gpio.Pin.init("E", "3", sai_p_cfg);
const fs = hal.gpio.Pin.init("E", "4", sai_p_cfg);
const sck = hal.gpio.Pin.init("E", "5", sai_p_cfg);
const sa = hal.gpio.Pin.init("E", "6", sai_p_cfg);
const codec_reset = hal.gpio.Pin.init("B", "11", .{ .mode = .Output, .pull = .Floating });

var sine = osc.SineOsc.init(220.0, 48000, 0.9);
var square = osc.SquareOsc.init(220.0, 48000, 0.9);

var buff: [6000]u32 = undefined;

pub fn main() !void {
    init_vector_table();

    daisy.init() catch {
        errors.error_handler();
    };
    led.configure();
    led.toggle();

    fs.configure();
    mclk.configure();
    sck.configure();
    sa.configure();
    sb.configure();
    codec_reset.configure();

    var sai = SaiDriver.init(.{
        .sample_rate = .@"48khz",
        .bit_depth = .@"24bit",
        .a_sync = .master,
        .b_sync = .slave,
        .a_dir = .transmit,
        .b_dir = .receive,
    });

    try sai.setup();

    // try sai.startAudio(myAudioCallback);

    try sai.enable();
    const samps = generateFreq(220, 48000);
    // try sai.transmitSquareForever(220.0);
    while (true) {
        var i: u32 = 0;
        while (i < samps) {
            const v = buff[i];
            while (chip_peri.SAI1.SAI_ASR.read().FLVL > 5) {} // Keep at least 2 slots free
            chip_peri.SAI1.SAI_ADR.raw = v;
            chip_peri.SAI1.SAI_ADR.raw = v;
            i += 1;
        }
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

var c: u32 = 0;
fn myAudioCallback(input: []const u32, output: []u32) void {
    _ = input;
    var i: u32 = 0;
    while (i < output.len) : (i += 2) {
        // output[i] = (c & 0xFFFFFF) << 8;
        // c += 100;
        // if (c > 4800) {
        //     c = 0;
        // }
        output[i] = ssai.fto24(sine.nextSample());
        // output[i] = ssai.fto24(square.nextSample());
        output[i + 1] = output[i];
    }
}
