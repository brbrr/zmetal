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
const usb = hal.usb;

// Daisy board support
const ssai = hal.sai;
const SaiDriver = ssai.SaiDriver;

const keyboard = @import("hid/keyboard.zig");
const encoders_mod = @import("hid/encoders.zig");
const MidiPort = @import("hid/midi_port.zig").MidiPort;
const synth = @import("synth.zig");
const ui = @import("ui");
const fat = @import("fat.zig");
const build_config = @import("build_config");
const audio = @import("audio_interface.zig");
const program_mod = @import("program.zig");
const usb_audio = hal.usb_audio;

pub const microzig_options: microzig.Options = .{
    .interrupts = .{
        .SysTick = .{ .c = sys_tick_handler },
        .HardFault = .{ .naked = hal.fault.hard_fault },
        .NMI = .{ .c = hal.fault.nmi_handler },
        .MemManageFault = .{ .naked = hal.fault.mem_manage_fault },
        .BusFault = .{ .naked = hal.fault.bus_fault },
        .UsageFault = .{ .naked = hal.fault.usage_fault },
        .SVCall = .{ .c = hal.fault.sv_call_handler },
        .PendSV = .{ .c = hal.fault.hw_handler },

        .DMA1_Stream0 = .{ .c = ssai.dma1_0_handler },
        .DMA1_Stream1 = .{ .c = ssai.dma1_1_handler },
        .SAI1 = .{ .c = ssai.SaiDriver.sai1_irq_handler },

        .SPI1 = .{ .c = hal.spi.spi1_irq_handler },
        // SPI TX
        .DMA2_Stream3 = .{ .c = hal.spi.tx_dma_irq_handler },
        // SPI RX
        // .DMA2_Stream2 = .{ .c = hal.spi.dma1_str3_handler },
        // MIDI IN (USART1 RX / DIN)
        .USART1 = .{ .c = hal.usart.UartStream(.USART1).irqHandler },

        // USB OTG device. Only the active controller's NVIC line is enabled (by
        // usb.init), so the other handler never fires.
        .OTG_FS = .{ .c = hal.usb.otg_fs_irq_handler },
        .OTG_HS = .{ .c = hal.usb.otg_hs_irq_handler },
    },
};

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

// USB-audio (interface) mode: the audio engine drives a Program (the DSP brain).
// Module-level so `&audio_iface` is a comptime-known pointer for saiCallback.
var program: program_mod.SynthProgram = .{};
var audio_iface = audio.AudioInterface(program_mod.SynthProgram).init(&program);

// DIN MIDI IN: USART1 @ 31250 baud (PB6=TX/PB7=RX). The kernel clock is derived
// from the clock tree inside the UART driver — no app-level clock config.
const DIN_UART_CONFIG = hal.usart.Config{
    .baud_rate = 31250,
    .tx = .{ .port = "B", .pin = "6", .af = .af7 },
    .rx = .{ .port = "B", .pin = "7", .af = .af7 },
};

const DinMidi = MidiPort(.{ .Stream = hal.usart.UartStream(.USART1) });
const UsbMidi = MidiPort(.{ .Stream = hal.usb.MidiStream });
var din_midi: DinMidi = undefined;
var usb_midi: UsbMidi = undefined;

// Daisy Seed on-board user LED (PC7) — used here as a USB mount indicator.
const led_pin = hal.gpio.Pin.init("C", "7", .{ .mode = .output, .speed = .LowSpeed });
const Led = hal.gpio.OutputGPIO(led_pin);

pub fn main() !void {
    try hw.init();
    Led.configure();

    // In USB-audio mode the SAI callback is the audio interface driving the
    // Program (synth + USB in/out routed through the DSP seam); otherwise it is
    // the plain DSP synth. Selected at compile time via -Dusb-audio.
    if (build_config.usb_audio) {
        try hw.startAudio(@TypeOf(audio_iface).saiCallback(&audio_iface));
    } else {
        try hw.startAudio(&synth.audioCallback);
    }

    try ui.init();

    var kbd: keyboard.Keyboard = undefined;
    try kbd.init(hw.i2c.i2c_device());

    var encoders: encoders_mod.Encoders = undefined;
    try encoders.init(hw.i2c.i2c_device());

    // SD card: identify (4-bit + IDMA) and mount the FAT filesystem.
    try hal.sdmmc.init();
    try fat.mount();

    din_midi = DinMidi.init(hal.usart.UartStream(.USART1).init(DIN_UART_CONFIG));

    // Match the USB audio format to the SAI config (descriptor, reported clock
    // rate, conversion stride) before enumeration.
    if (build_config.usb_audio) usb_audio.configure(hw.audio);

    // USB device (CDC + MIDI) and DIN MIDI. USB runs at .lowest IRQ priority,
    // strictly below the audio DMA/SAI ISRs, so it never preempts audio.
    hal.usb.init(.{});
    usb_midi = UsbMidi.init(.{});

    // Peripheral polling is time-gated off the 1 kHz millisecond tick, so its
    // rate is fixed regardless of how fast the interrupt-woken loop spins.
    // (A loop-iteration counter floated with interrupt load: the keyboard
    // ended up scanning ~100×/s worth of blocking I2C per iteration, which
    // starved the display and roughly tripled frame time.)
    var last_kbd_ms: u32 = 0;
    var last_enc_ms: u32 = 0;
    while (true) {
        // Service the USB device stack (enumeration, CDC/MIDI transfers).
        hal.usb.task();
        // if (!hal.usb.mounted()) {
        //    continue;
        // }

        // Drain received MIDI (DIN + USB) and play it on the synth.
        while (din_midi.poll()) |msg| {
            switch (msg.kind) {
                .note_on => synth.midiNoteOn(msg.data1, msg.data2),
                .note_off => synth.midiNoteOff(msg.data1),
                else => {},
            }
        }
        while (usb_midi.poll()) |msg| {
            switch (msg.kind) {
                .note_on => synth.midiNoteOn(msg.data1, msg.data2),
                .note_off => synth.midiNoteOff(msg.data1),
                else => {},
            }
        }

        const now_ms = hal.clock.get_tick();

        // Scan the keyboard at 100 Hz (every 10 ms).
        if (now_ms -% last_kbd_ms >= 10) {
            last_kbd_ms = now_ms;
            if (kbd.process()) |events| {
                for (events.slice()) |evt| {
                    synth.handleKey(keyboard.logicalKey(evt.key), evt.event == .pressed);
                }
            } else |_| {
                // Ignore transient keyboard I2C errors.
            }
        }

        // Poll encoders every ~2 ms so detents aren't missed. ENC0 = volume
        // (interface-mode line-out trim), ENC1 = octave.
        if (now_ms -% last_enc_ms >= 2) {
            last_enc_ms = now_ms;
            if (encoders.poll()) {
                const vol = encoders.get(0).inc;
                if (vol != 0) {
                    if (build_config.usb_audio) program.adjustUsbGain(vol) else synth.adjustVolume(vol);
                }
                const oct = encoders.get(1).inc;
                if (oct != 0) synth.shiftOctave(oct);
            } else |_| {
                // Ignore transient encoder I2C errors.
            }
        }

        ui.service(&hw.load_meter);
        cpu.wfi();
    }
}
