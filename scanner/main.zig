//! The v3 panel scanner, STM32C031K6: a 7x7 key matrix and four encoders
//! sampled at 8 kHz, served to the Daisy over I2C as the 16-byte frame of
//! `panel_proto` (`zig build scanner`). The logic is the host-tested
//! `panel_scanner` and `panel_link`; `hal/` is the register layer under
//! them. The start follows "Never unflashable" in the panel scanner plan:
//! S0 in `hal/start.zig` (the reset path), then here, in order, S1, S2, S3.
//!
//! Interrupts: SysTick (8 kHz) ticks the scanner and drives INT; I2C1 runs
//! the link. Both have one priority, so neither preempts the other; the
//! main loop takes what it shares with them with interrupts masked.

const std = @import("std");
const microzig = @import("microzig");
const panel = @import("panel");
const config = @import("scanner_config");

const start = @import("hal/start.zig");
const clock = @import("hal/clock.zig");
const pins = @import("hal/pins.zig");
const i2c_target = @import("hal/i2c_target.zig");
const uncommit = @import("hal/uncommit.zig");

const proto = panel.panel_proto;
const Scanner = panel.panel_scanner.Scanner(pins.Io);
const Link = panel.panel_link.Link;

comptime {
    start.exportVectorTable(onSysTick, onI2c1, onFault);
}

/// No stack traces, no messages: a panic stops the scanner where it is
/// (see `halt`).
pub const panic = std.debug.FullPanic(panicHalt);

var scanner: Scanner = Scanner.init(.{}, config.fw);
var link: Link = .{};
/// Ticks since start, 8 kHz, wrapping; written by `onSysTick` only.
var ticks: u32 = 0;
/// Commands the link completed, for the main loop; set by `onI2c1`.
var want_clear_booted: bool = false;
var want_bootloader: bool = false;

pub fn main() noreturn {
    start.normalise(); // S1
    if (start.strapHeld()) uncommit.run(); // S2
    const committed = start.committed(); // S3
    if (committed) start.clearEmptyFlag() else start.setEmptyFlag();
    scanner.setTrial(!committed);

    clock.init();
    pins.init();
    i2c_target.init(clock.priority);
    clock.startTick();
    microzig.cpu.interrupt.enable_interrupts();

    var led_on = false;
    var last_toggle: u32 = 0;
    while (true) {
        const cs = microzig.interrupt.enter_critical_section();
        const now = @as(*volatile u32, &ticks).*;
        const clear_booted = want_clear_booted;
        const bootloader = want_bootloader;
        want_clear_booted = false;
        if (clear_booted) scanner.clearBooted(); // `tick` changes `seq` too
        cs.leave();

        // Only after the STOP of its write: `onStop` gave the command.
        if (bootloader) {
            i2c_target.stop();
            uncommit.run();
        }

        // 1 Hz, 4 Hz while running an uncommitted image.
        const half_period: u32 = if (scanner.state.trial) clock.tick_hz / 8 else clock.tick_hz / 2;
        if (now -% last_toggle >= half_period) {
            last_toggle +%= half_period;
            led_on = !led_on;
            pins.setLed(led_on);
        }
    }
}

/// The state as of the last tick, taken with SysTick masked so a tick
/// cannot change it half-way through the copy.
fn frameNow() proto.Frame {
    const cs = microzig.interrupt.enter_critical_section();
    defer cs.leave();
    return scanner.frame();
}

fn onSysTick() callconv(.c) void {
    scanner.tick();
    pins.setInt(link.intAsserted(scanner.state.seq));
    ticks +%= 1;
}

fn onI2c1() callconv(.c) void {
    const command = i2c_target.service(&link, frameNow) orelse return;
    switch (command) {
        .clear_booted => want_clear_booted = true,
        .enter_bootloader => want_bootloader = true,
        .ack => {}, // the link recorded it; `onSysTick` releases INT
    }
}

/// NMI and HardFault.
fn onFault() callconv(.c) void {
    halt();
}

fn panicHalt(_: []const u8, _: ?usize) noreturn {
    halt();
}

/// Stops with interrupts masked and I2C1 held in reset, so a stopped
/// scanner never holds the Daisy's bus (an address match with nobody to
/// answer it would stretch SCL for good). The Daisy gets it back with NRST,
/// and with the strap from there.
fn halt() noreturn {
    microzig.cpu.interrupt.disable_interrupts();
    microzig.chip.peripherals.RCC.APBRSTR1.modify(.{ .I2C1RST = 1 });
    while (true) {
        asm volatile ("" ::: .{ .memory = true });
    }
}
