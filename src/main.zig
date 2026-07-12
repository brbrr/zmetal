// TODO:
// - test current code: play around with lower values of reload Reg
// - Test that val reg is incrementing correctly
// - test that COUNTFLAG is flipped at all

const std = @import("std");

const microzig = @import("microzig");
const cpu = microzig.cpu;
const chip = microzig.chip;

// microzig now requires the root source file to explicitly export the startup logic
// (defines the `microzig_main` symbol the reset handler jumps to).
comptime {
    _ = microzig.export_startup();
}

pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

const chip_peri = chip.peripherals;
const RCC = chip_peri.RCC;
const time = microzig.drivers.time;
pub const hal = microzig.hal;

// Daisy board support
const ssai = hal.sai;
const SaiDriver = ssai.SaiDriver;

const keyboard = @import("hid/keyboard.zig");
const synth = @import("synth.zig");
const ui = @import("ui.zig");

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
        .HardFault = .{ .naked = hal.fault.hard_fault },
        .NMI = .{ .c = nmi_handler },
        .MemManageFault = .{ .naked = hal.fault.mem_manage_fault },
        .BusFault = .{ .naked = hal.fault.bus_fault },
        .UsageFault = .{ .naked = hal.fault.usage_fault },
        .SVCall = .{ .c = sv_call_handler },
        .PendSV = .{ .c = hw_handler },

        .DMA1_Stream0 = .{ .c = ssai.dma1_0_handler },
        .DMA1_Stream1 = .{ .c = ssai.dma1_1_handler },
        .SAI1 = .{ .c = ssai.SaiDriver.sai1_irq_handler },

        .SPI1 = .{ .c = hal.spi.spi1_irq_handler },
        // SPI TX
        .DMA2_Stream3 = .{ .c = hal.spi.tx_dma_irq_handler },
        // SPI RX
        // .DMA2_Stream2 = .{ .c = hal.spi.dma1_str3_handler },
    },
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

var blink_ctr: u32 = 0;
fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
    blink_ctr +%= 1;
    if (blink_ctr >= 500) { // 1 kHz tick -> ~1 Hz blink
        blink_ctr = 0;
        // hw.led.toggle();
    }
}

pub fn init() void {
    // FIXME: For SRAM build, no need to call below
    hal.init_vector_table();
}

var hw: hal.daisy.Daisy = hal.daisy.Daisy.create() catch unreachable;

pub fn main() !void {
    try hw.init();
    try hw.startAudio(&synth.audioCallback);
    try ui.init();

    var kbd: keyboard.Keyboard = undefined;
    try kbd.init(hw.i2c.i2c_device());
    var tick_count: u32 = 0;
    while (true) {
        // Process keyboard every 10ms (100Hz scan rate)
        if (tick_count % 10 == 0) {
            if (kbd.process()) |events| {
                for (events.slice()) |evt| {
                    synth.handleKey(keyboard.logicalKey(evt.key), evt.event == .pressed);
                }
            } else |_| {
                // Ignore keyboard errors
            }
        }
        tick_count += 1;

        ui.service();
        cpu.wfi();
    }
}
