//! Standalone on-hardware self-test for the USB CDC+MIDI device.
//!
//! This is a dedicated test firmware (its own root / entry point), separate from
//! the synth example. It brings up only the board + USB (no audio,
//! display, SD, or keyboard) so USB can be exercised in isolation.
//!
//! Build & flash (ReleaseSafe fits the 128 KB internal flash):
//!     zig build usb_loopback -Doptimize=safe
//!     openocd -f interface/stlink.cfg -f target/stm32h7x.cfg \
//!       -c "reset_config srst_only srst_nogate connect_assert_srst" \
//!       -c "init" -c "reset halt" \
//!       -c "program zig-out/firmware/usb_loopback.elf verify" -c "reset run" -c "exit"
//!
//! Acceptance (plug the Daisy's on-board micro-USB into a host):
//!   1. Enumerates as a composite "Daisy CDC+MIDI" device (VID 0xCafe/PID 0x4001)
//!      with a /dev/tty.usbmodem* CDC node and a MIDI port.
//!   2. CDC echo: bytes sent to the serial port are echoed back.
//!   3. USB-MIDI echo: MIDI sent to the device is echoed back (raw byte loopback
//!      on cable 0).
//!   4. PC7 (Daisy user LED) tracks mount state: on when enumerated, off when not.

const microzig = @import("microzig");
const zmetal = @import("zmetal");
const hal = zmetal.hal;
const usb = hal.usb;

// microzig requires the root source to export the startup logic.
comptime {
    _ = microzig.export_startup();
}

pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

// SysTick, fault and USB interrupt handlers come from hal.default_interrupts.
pub const microzig_options: microzig.Options = .{};

var seed: zmetal.Seed = .{};

pub fn main() !void {
    try seed.init(.{ .sdram = false, .qspi = false });

    // OTG IRQ priority = .lowest (usb.init default); no audio here, but it keeps
    // the same relationship the real firmware relies on.
    usb.init(.{});

    var buf: [64]u8 = undefined;
    var midi_buf: [64]u8 = undefined;
    var cdc: usb.CdcStream = .{};
    var ms: usb.MidiStream = .{};
    while (true) {
        usb.task();
        seed.setLed(usb.mounted());

        // CDC loopback: echo received bytes straight back.
        const n = cdc.read(&buf) catch 0;
        if (n > 0) _ = cdc.write(buf[0..n]) catch {};

        // USB-MIDI loopback: echo received MIDI bytes back on cable 0.
        while (true) {
            const m = ms.read(&midi_buf) catch 0;
            if (m == 0) break;
            _ = ms.write(midi_buf[0..m]) catch {};
        }
    }
}
