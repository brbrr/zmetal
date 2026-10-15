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
const hal = zmetal.hal;
const usb = hal.usb;

// Daisy board support
const ssai = hal.sai;
const SaiDriver = ssai.SaiDriver;

const zmetal = @import("zmetal");
const layout = @import("layout.zig");
const MidiPort = zmetal.hid.midi_port.MidiPort;
const synth = @import("synth.zig");
const ui = @import("ui.zig");
const fat = zmetal.fat;
const build_config = @import("build_config");
const audio = zmetal.audio;
const program_mod = @import("program.zig");

// SysTick, fault, audio (SAI/DMA), display (SPI1/DMA), MIDI (USART1) and USB
// interrupt handlers come from hal.default_interrupts; the HAL's `init` runs
// automatically before main.
pub const microzig_options: microzig.Options = .{};

var seed: zmetal.Seed = .{};

// I2C1 on D11/D12 (PB8 SCL / PB9 SDA): both MCP23017 expanders (keyboard 0x21,
// encoders 0x20). Module-level: the drivers keep pointers to it.
var i2c: hal.i2c.I2C_Device = undefined;

// USB-audio (interface) mode: the audio engine drives a Program (the DSP brain).
var program: program_mod.SynthProgram = .{};
const AudioIface = audio.AudioInterface(program_mod.SynthProgram, .{ .usb = true });
var audio_iface = AudioIface.init(&program);

// DIN MIDI IN: USART1 @ 31250 baud (D13/PB6 = TX, D14/PB7 = RX). The kernel clock is derived
// from the clock tree inside the UART driver — no app-level clock config.
const DIN_UART_CONFIG = hal.usart.Config{
    .baud_rate = 31250,
    .tx = .{ .pin = zmetal.pins.D13, .af = .af7 }, // PB6
    .rx = .{ .pin = zmetal.pins.D14, .af = .af7 }, // PB7
};

const DinMidi = MidiPort(.{ .Stream = hal.usart.UartStream(.USART1) });
const UsbMidi = MidiPort(.{ .Stream = hal.usb.MidiStream });
var din_midi: DinMidi = undefined;
var usb_midi: UsbMidi = undefined;

pub fn main() !void {
    try seed.init(.{});

    i2c = try hal.i2c.I2C_Device.init(.I2C1, .{ .speed = .I2C_400KHZ });
    i2c.apply();

    // In USB-audio mode the SAI callback is the audio interface driving the
    // Program (synth + USB in/out routed through the DSP seam); otherwise it is
    // the plain DSP synth. Selected at compile time via -Dusb-audio.
    if (build_config.usb_audio) {
        try seed.startAudioCtx(&audio_iface, AudioIface.render);
    } else {
        try seed.startAudio(synth.audioCallback);
    }

    try ui.init();

    var kbd: layout.Keyboard = undefined;
    try kbd.init(i2c.i2c_device());

    var encoders: layout.Encoders = undefined;
    try encoders.init(i2c.i2c_device());

    // SD card: identify (4-bit + IDMA) and mount the FAT filesystem.
    try hal.sdmmc.init();
    try fat.mount();

    din_midi = DinMidi.init(hal.usart.UartStream(.USART1).init(DIN_UART_CONFIG));


    // USB device (CDC + MIDI) and DIN MIDI. USB runs at .lowest IRQ priority,
    // strictly below the audio DMA/SAI ISRs, so it never preempts audio.
    // In USB-audio mode the audio format (descriptor, reported clock rate,
    // conversion stride) is matched to the codec before enumeration.
    if (build_config.usb_audio) hal.usb.initWithAudio(.{}, seed.audio) else hal.usb.init(.{});
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
                    synth.handleKey(layout.logicalKey(evt.key), evt.event == .pressed);
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

        ui.service(&seed);
        cpu.wfi();
    }
}
