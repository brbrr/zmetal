//! Raw TinyUSB C ABI declarations and the app-provided descriptor callbacks.
//! Descriptor callbacks live in descriptors.zig (real composite CDC+MIDI
//! descriptors, added in Task 4).

comptime {
    _ = @import("descriptors.zig"); // pulls in the real tud_descriptor_*_cb exports
}

// --- Core ---
// NOTE on TinyUSB 0.18.0 vs. the brief's assumed API shape: `tud_task`,
// `tud_init`, `tud_int_handler`, and `tud_ready` are `static inline`
// wrappers or macros declared in tusb.h/usbd.h and never emit a linkable
// C symbol, so `extern fn` cannot bind to them directly. Likewise all
// `tud_cdc_*` / `tud_midi_*` convenience APIs are `static inline` in
// cdc_device.h / midi_device.h. `lib/tinyusb_shim/usb_glue.c` re-exports
// each of these as a real, linkable C symbol (the `zt_*` names below);
// the `pub fn` wrappers here just forward to the glue under the original
// friendly names so callers elsewhere in the usb HAL don't need to change.

// Linkable forwarders defined in lib/tinyusb_shim/usb_glue.c
extern fn zt_task() void;
extern fn zt_device_init(rhport: u8) bool;
extern fn zt_int_handler(rhport: u8) void;
extern fn zt_mounted() bool;
extern fn zt_ready() bool;
extern fn zt_cdc_available() u32;
extern fn zt_cdc_read(buffer: [*]u8, bufsize: u32) u32;
extern fn zt_cdc_write(buffer: [*]const u8, bufsize: u32) u32;
extern fn zt_cdc_write_flush() u32;
extern fn zt_cdc_connected() bool;
extern fn zt_midi_available() u32;
extern fn zt_midi_stream_read(buffer: [*]u8, bufsize: u32) u32;
extern fn zt_midi_stream_write(cable_num: u8, buffer: [*]const u8, bufsize: u32) u32;

// Audio FIFO forwarders + alt-setting flags (lib/tinyusb_shim/usb_audio_glue.c).
pub extern fn zt_audio_read(buf: [*]u8, n: u16) u16;
pub extern fn zt_audio_write(buf: [*]const u8, n: u16) u16;
pub extern fn zt_audio_out_available() u32;
pub extern fn zt_audio_out_active() bool;
pub extern fn zt_audio_in_active() bool;
pub extern fn zt_audio_set_sample_rate(rate: u32) void;

// Friendly names used across the usb HAL (thin wrappers over the glue).
pub fn tud_task() void {
    zt_task();
}
pub fn tud_init(rhport: u8) bool {
    return zt_device_init(rhport);
}
pub fn tud_int_handler(rhport: u8) void {
    zt_int_handler(rhport);
}
pub fn tud_mounted() bool {
    return zt_mounted();
}
pub fn tud_ready() bool {
    return zt_ready();
}
pub fn tud_cdc_available() u32 {
    return zt_cdc_available();
}
pub fn tud_cdc_read(buffer: [*]u8, bufsize: u32) u32 {
    return zt_cdc_read(buffer, bufsize);
}
pub fn tud_cdc_write(buffer: [*]const u8, bufsize: u32) u32 {
    return zt_cdc_write(buffer, bufsize);
}
pub fn tud_cdc_write_flush() u32 {
    return zt_cdc_write_flush();
}
pub fn tud_cdc_connected() bool {
    return zt_cdc_connected();
}
pub fn tud_midi_available() u32 {
    return zt_midi_available();
}
pub fn tud_midi_stream_read(buffer: [*]u8, bufsize: u32) u32 {
    return zt_midi_stream_read(buffer, bufsize);
}
pub fn tud_midi_stream_write(cable_num: u8, buffer: [*]const u8, bufsize: u32) u32 {
    return zt_midi_stream_write(cable_num, buffer, bufsize);
}
