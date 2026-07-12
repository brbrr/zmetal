//! Application entry point for the Daisy Seed (STM32H750) audio platform.
//!
//! Wires the board bring-up (`hal.daisy`), the audio engine (`synth`), the
//! display scene (`ui`), and the matrix keyboard (`hid.keyboard`) together, and
//! owns the microzig root config (panic/std_options/interrupt vector table).

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
const encoders_mod = @import("hid/encoders.zig");
const midi_input = @import("hid/midi_input.zig");
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

        // MIDI IN (USART1 RX)
        .USART1 = .{ .c = midi_input.usart1_irq_handler },
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

    var encoders: encoders_mod.Encoders = undefined;
    try encoders.init(hw.i2c.i2c_device());

    midi_input.init();

    // SD card bring-up (Phase 1: identify). Non-fatal so init_stage/card can be
    // inspected over the debugger even if a later step fails.
    try hal.sdmmc.init();

    var tick_count: u32 = 0;
    while (true) {
        // Drain received MIDI (interrupt-buffered) and play it on the synth.
        while (midi_input.poll()) |msg| {
            switch (msg.kind) {
                .note_on => synth.midiNoteOn(msg.data1, msg.data2),
                .note_off => synth.midiNoteOff(msg.data1),
                else => {},
            }
        }

        // Process keyboard every 10ms (100Hz scan rate).
        if (tick_count % 10 == 0) {
            if (kbd.process()) |events| {
                for (events.slice()) |evt| {
                    synth.handleKey(keyboard.logicalKey(evt.key), evt.event == .pressed);
                }
            } else |_| {
                // Ignore transient keyboard I2C errors.
            }
        }

        // Poll encoders every ~2ms so detents aren't missed. ENC0 = volume,
        // ENC1 = octave; ENC2/ENC3 and all switches are decoded but unmapped.
        if (tick_count % 2 == 0) {
            if (encoders.poll()) |_| {
                const vol = encoders.get(0).inc;
                if (vol != 0) synth.adjustVolume(vol);
                const oct = encoders.get(1).inc;
                if (oct != 0) synth.shiftOctave(oct);
            } else |_| {
                // Ignore transient encoder I2C errors.
            }
        }

        tick_count += 1;

        ui.service();
        cpu.wfi();
    }
}
