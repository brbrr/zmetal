/* Non-inline forwarders that expose TinyUSB's static-inline / macro
 * convenience APIs (cdc_device.h, midi_device.h, tud_task/tud_init/
 * tud_int_handler/tud_ready) as linkable C symbols callable from Zig.
 * These helpers have no ABI symbol of their own; each wrapper below gives
 * one a real symbol. */
#include "tusb.h"

void     zt_task(void)                  { tud_task(); }
bool     zt_device_init(uint8_t rhport) { return tud_init(rhport); }
void     zt_int_handler(uint8_t rhport) { tud_int_handler(rhport); }
bool     zt_mounted(void)               { return tud_mounted(); }
bool     zt_ready(void)                 { return tud_ready(); }

uint32_t zt_cdc_available(void)                             { return tud_cdc_available(); }
uint32_t zt_cdc_read(void* buffer, uint32_t bufsize)        { return tud_cdc_read(buffer, bufsize); }
uint32_t zt_cdc_write(void const* buffer, uint32_t bufsize) { return tud_cdc_write(buffer, bufsize); }
uint32_t zt_cdc_write_flush(void)                           { return tud_cdc_write_flush(); }
bool     zt_cdc_connected(void)                             { return tud_cdc_connected(); }

uint32_t zt_midi_available(void)                             { return tud_midi_available(); }
uint32_t zt_midi_stream_read(void* buffer, uint32_t bufsize) { return tud_midi_stream_read(buffer, bufsize); }
uint32_t zt_midi_stream_write(uint8_t cable, uint8_t const* buffer, uint32_t bufsize) { return tud_midi_stream_write(cable, buffer, bufsize); }
