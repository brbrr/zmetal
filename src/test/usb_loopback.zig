//! Standalone on-hardware self-test for the USB CDC+MIDI device.
//!
//! This is a dedicated test firmware (its own root / entry point), separate from
//! the application `src/main.zig`. It brings up only the board + USB (no audio,
//! display, SD, or keyboard) so USB can be exercised in isolation.
//!
//! Build & flash (ReleaseSafe fits the 128 KB internal flash):
//!     zig build usb-hwtest -Doptimize=ReleaseSafe
//!     openocd -f interface/stlink.cfg -f target/stm32h7x.cfg \
//!       -c "reset_config srst_only srst_nogate connect_assert_srst" \
//!       -c "init" -c "reset halt" \
//!       -c "program zig-out/firmware/usb-hwtest.elf verify" -c "reset run" -c "exit"
//!
//! Acceptance (plug the Daisy's on-board micro-USB into a host):
//!   1. Enumerates as a composite "Daisy CDC+MIDI" device (VID 0xCafe/PID 0x4001)
//!      with a /dev/tty.usbmodem* CDC node and a MIDI port.
//!   2. CDC echo: bytes sent to the serial port are echoed back.
//!   3. USB-MIDI echo: MIDI sent to the device is echoed back (raw byte loopback
//!      on cable 0).
//!   4. PC7 (Daisy user LED) tracks mount state: on when enumerated, off when not.

const microzig = @import("microzig");
const hal = microzig.hal;
const usb = hal.usb;

// microzig requires the root source to export the startup logic.
comptime {
    _ = microzig.export_startup();
}

pub const panic = microzig.panic;
pub const std_options = microzig.std_options(.{});

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

        // USB OTG device. Only the active controller's NVIC line is enabled by
        // usb.init, so the other handler never fires.
        .OTG_FS = .{ .c = hal.usb.otg_fs_irq_handler },
        .OTG_HS = .{ .c = hal.usb.otg_hs_irq_handler },
    },
};

fn sys_tick_handler() callconv(.c) void {
    hal.clock.inc_tick();
}

// Daisy Seed on-board user LED (libdaisy: SEED_LED_PORT=PORTC, SEED_LED_PIN=7).
const led_pin = hal.gpio.Pin.init("C", "7", .{ .mode = .output, .speed = .LowSpeed });
const Led = hal.gpio.OutputGPIO(led_pin);

var hw: hal.daisy.Daisy = hal.daisy.Daisy.create() catch unreachable;

pub fn main() !void {
    try hw.init();

    // OTG IRQ priority = .lowest (usb.init default); no audio here, but it keeps
    // the same relationship the real firmware relies on.
    usb.init(.{});
    Led.configure();

    var buf: [64]u8 = undefined;
    var midi_buf: [64]u8 = undefined;
    var cdc: usb.CdcStream = .{};
    var ms: usb.MidiStream = .{};
    while (true) {
        usb.task();
        if (usb.mounted()) Led.set() else Led.clear();

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
