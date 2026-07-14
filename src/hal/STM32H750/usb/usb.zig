//! USB device HAL: TinyUSB board glue for the STM32H750 dwc2 OTG core.
//! One controller active, chosen at comptime (see `Controller`).

const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const interrupt = microzig.cpu.interrupt;

const gpio = @import("../gpio.zig");
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
    /// urgency) than the SAI audio-DMA ISR. Default `.lowest`.
    irq_priority: interrupt.Priority = .lowest,
};

const Descriptor = struct {
    rhport: u8,
    dm: gpio.AltPin,
    dp: gpio.AltPin,
    rcc_field: []const u8,
    irq: @TypeOf(.enum_literal),
};

fn descriptor(c: Controller) Descriptor {
    return switch (c) {
        .internal_fs => .{
            .rhport = 0,
            .dm = .{ .port = "A", .num = "11", .af = .af10 },
            .dp = .{ .port = "A", .num = "12", .af = .af10 },
            .rcc_field = "USB_OTG_FSEN",
            .irq = .OTG_FS,
        },
        .external_hs => .{
            .rhport = 1,
            .dm = .{ .port = "B", .num = "14", .af = .af12 },
            .dp = .{ .port = "B", .num = "15", .af = .af12 },
            .rcc_field = "USB_OTG_HSEN",
            .irq = .OTG_HS,
        },
    };
}

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
