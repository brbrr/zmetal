//! USB device HAL: TinyUSB board glue for the STM32H750 dwc2 OTG core.
//! One controller active, chosen at comptime (see `Controller`).

const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const interrupt = microzig.cpu.interrupt;

const gpio = @import("../gpio.zig");
const power = @import("../power.zig");
const clock = @import("../clock.zig");
const tusb = @import("tinyusb.zig");

const StreamDevice = microzig.drivers.base.StreamDevice;

// ---- CDC-ACM as a byte stream ----
/// Non-blocking CDC-ACM byte stream. TinyUSB owns all state, so this is a
/// zero-sized handle — safe to value-construct anywhere (`CdcStream{}`).
pub const CdcStream = struct {
    pub fn read(_: CdcStream, buf: []u8) StreamDevice.ReadError!usize {
        if (tusb.tud_cdc_available() == 0) return 0;
        return tusb.tud_cdc_read(buf.ptr, @intCast(buf.len));
    }
    pub fn write(_: CdcStream, bytes: []const u8) StreamDevice.WriteError!usize {
        if (!tusb.tud_ready()) return error.NotConnected;
        const n = tusb.tud_cdc_write(bytes.ptr, @intCast(bytes.len));
        _ = tusb.tud_cdc_write_flush();
        return n;
    }
    // Erased-interface glue (StreamDevice.VTable).
    fn writev(_: *anyopaque, vecs: []const []const u8) StreamDevice.WriteError!usize {
        var total: usize = 0;
        for (vecs) |v| total += try (CdcStream{}).write(v);
        return total;
    }
    fn readv(_: *anyopaque, vecs: [][]u8) StreamDevice.ReadError!usize {
        var total: usize = 0;
        for (vecs) |v| total += try (CdcStream{}).read(v);
        return total;
    }
    const vtable = StreamDevice.VTable{ .connect_fn = null, .disconnect_fn = null, .writev_fn = writev, .readv_fn = readv };
};

/// Erased byte stream for the CDC port (e.g. for `.writer(buf)`-style logging).
pub fn cdc_stream() StreamDevice {
    return .{ .ptr = undefined, .vtable = &CdcStream.vtable };
}

// ---- USB-MIDI as a byte stream (raw MIDI bytes; USB packet framing handled by TinyUSB) ----
/// Non-blocking USB-MIDI byte stream (cable 0). Zero-sized handle, same as
/// `CdcStream`.
pub const MidiStream = struct {
    pub fn read(_: MidiStream, buf: []u8) StreamDevice.ReadError!usize {
        if (tusb.tud_midi_available() == 0) return 0;
        return tusb.tud_midi_stream_read(buf.ptr, @intCast(buf.len));
    }
    pub fn write(_: MidiStream, bytes: []const u8) StreamDevice.WriteError!usize {
        if (!tusb.tud_mounted()) return error.NotConnected;
        return tusb.tud_midi_stream_write(0, bytes.ptr, @intCast(bytes.len));
    }
    fn writev(_: *anyopaque, vecs: []const []const u8) StreamDevice.WriteError!usize {
        var total: usize = 0;
        for (vecs) |v| total += try (MidiStream{}).write(v);
        return total;
    }
    fn readv(_: *anyopaque, vecs: [][]u8) StreamDevice.ReadError!usize {
        var total: usize = 0;
        for (vecs) |v| total += try (MidiStream{}).read(v);
        return total;
    }
    const vtable = StreamDevice.VTable{ .connect_fn = null, .disconnect_fn = null, .writev_fn = writev, .readv_fn = readv };
};

/// Erased byte stream for the USB-MIDI port.
pub fn midi_stream() StreamDevice {
    return .{ .ptr = undefined, .vtable = &MidiStream.vtable };
}

pub const Controller = enum { internal_fs, external_hs };

pub const Config = struct {
    controller: Controller = .internal_fs,
    /// NVIC priority for the OTG IRQ. MUST be numerically greater (lower
    /// urgency) than the SAI audio-DMA ISR (`.highest`/0 in daisy.zig) so a USB
    /// ISR can never delay an audio-DMA refill. Default `.lowest` (15).
    irq_priority: interrupt.Priority = .lowest,
};

const Descriptor = struct {
    rhport: u8,
    dm: gpio.AltPin,
    dp: gpio.AltPin,
    /// RCC.AHB1ENR field: run-mode peripheral clock enable.
    rcc_field: []const u8,
    /// RCC.AHB1LPENR field: keep the clock during CPU sleep (CSLEEP/`wfi`).
    lp_field: []const u8,
    /// RCC.AHB1LPENR ULPI-clock field. Reset-default 1; MUST be cleared for the
    /// embedded FS PHY or the OTG core stalls in CSLEEP (see init()).
    ulpi_lp_field: []const u8,
    irq: @TypeOf(.enum_literal),
    /// OTG core register block base (for pre-powering the PHY before tud_init).
    base: usize,
};

fn descriptor(c: Controller) Descriptor {
    return switch (c) {
        .internal_fs => .{
            .rhport = 0,
            .dm = .{ .port = "A", .num = "11", .af = .af10 },
            .dp = .{ .port = "A", .num = "12", .af = .af10 },
            .rcc_field = "USB_OTG_FSEN",
            .lp_field = "USB_OTG_FSLPEN",
            .ulpi_lp_field = "USB_OTG_FS_ULPILPEN",
            .irq = .OTG_FS,
            .base = 0x4008_0000, // USB2_OTG_FS
        },
        .external_hs => .{
            .rhport = 1,
            .dm = .{ .port = "B", .num = "14", .af = .af12 },
            .dp = .{ .port = "B", .num = "15", .af = .af12 },
            .rcc_field = "USB_OTG_HSEN",
            .lp_field = "USB_OTG_HSLPEN",
            .ulpi_lp_field = "USB_OTG_HS_ULPILPEN",
            .irq = .OTG_HS,
            .base = 0x4004_0000, // USB1_OTG_HS
        },
    };
}

/// dwc2 GCCFG register offset + PWRDWN bit (STM32 embedded-PHY wrapper).
const GCCFG_OFFSET = 0x38;
const GCCFG_PWRDWN = 1 << 16;

pub fn init(comptime cfg: Config) void {
    const d = comptime descriptor(cfg.controller);

    // DP/DM pins: alternate function, very-high speed, no pull.
    gpio.configureAlternates(&.{ d.dm, d.dp });

    // Route HSI48 to the OTG kernel clock: D2CCIP2R.USBSEL = 0b11 (hsi48_ck).
    // The ClockHelper-generated clock config leaves USBSEL=0 (disabled) for the
    // HSI48 selection (its USBCLockSelection->USBSEL enum bridge yields 0), so
    // without this the dwc2 core has no 48 MHz clock and reset_core() spins
    // forever waiting for CSRST to self-clear. HSI48 itself is already enabled
    // and ready from the clock-tree bring-up (RCC.CR HSI48ON/HSI48RDY).
    peripherals.RCC.D2CCIP2R.modify_one("USBSEL", @enumFromInt(0b11));

    // Enable the OTG peripheral clock, then read back (RCC enable settle delay).
    peripherals.RCC.AHB1ENR.modify_one(d.rcc_field, 1);
    _ = peripherals.RCC.AHB1ENR.read();

    // Keep USB alive across CPU sleep (`cpu.wfi()` in the main loop enters
    // CSLEEP, where each AHB1 peripheral is clocked only if its AHB1LPENR bit is
    // set). Two bits matter for the embedded FS PHY, and the ULPI one is the
    // subtle killer:
    //   - <OTG>LPEN = 1: keep the OTG peripheral clock during CSLEEP.
    //   - <OTG>_ULPILPEN = 0: the ULPI-PHY clock defaults to 1 after reset, and
    //     with that default the H7 OTG core stalls in CSLEEP even though we use
    //     the *internal* FS PHY (no ULPI). This is why enabling <OTG>LPEN alone
    //     was not enough — USB still died under wfi. Clearing ULPILPEN is the
    //     documented fix (ST __HAL_RCC_USB2_OTG_FS_ULPI_CLK_SLEEP_DISABLE;
    //     ARMmbed/mbed-os PR #13780). DMA-driven peripherals tolerate CSLEEP
    //     gating (they resume on the next SysTick wake); USB, which must service
    //     the host autonomously in real time, does not.
    peripherals.RCC.AHB1LPENR.modify_one(d.lp_field, 1);
    peripherals.RCC.AHB1LPENR.modify_one(d.ulpi_lp_field, 0);
    _ = peripherals.RCC.AHB1LPENR.read();

    // Ensure the USB 3.3V supply is ready (config_usb enables PWR.CR3.USB33DEN
    // but doesn't wait). Bounded/best-effort — usually already set by now.
    var spins: u32 = 0;
    while (!power.get_flag(.USB33RDY) and spins < 1_000_000) : (spins += 1) {}

    // Pre-power the embedded FS PHY and let it settle BEFORE tud_init. dcd_init
    // sets GCCFG.PWRDWN (transceiver on) and then IMMEDIATELY asserts the core
    // soft reset (CSRST) with no PHY-settle delay; on a cold boot the PHY clock
    // isn't stable that fast, so CSRST occasionally never self-clears and
    // reset_core() spins forever (TinyUSB's reset loop has no timeout). Powering
    // the PHY here + a delay guarantees a stable PHY clock by the time the reset
    // runs. (ST's USB_CoreReset avoids the race by waiting AHB-idle first.)
    const gccfg: *volatile u32 = @ptrFromInt(d.base + GCCFG_OFFSET);
    gccfg.* |= GCCFG_PWRDWN;
    clock.delay_us(1000);

    // NVIC: priority BELOW the audio ISR, then enable.
    interrupt.set_priority(d.irq, cfg.irq_priority);
    interrupt.enable(d.irq);

    _ = tusb.tud_init(d.rhport);
}

pub fn task() void {
    tusb.tud_task();
}

pub fn mounted() bool {
    return tusb.tud_mounted();
}

pub fn otg_fs_irq_handler() callconv(.c) void {
    tusb.tud_int_handler(0); // rhport 0 = OTG_FS
}

pub fn otg_hs_irq_handler() callconv(.c) void {
    tusb.tud_int_handler(1); // rhport 1 = OTG_HS
}
