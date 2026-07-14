/* Minimal <string.h> for the freestanding (no-libc) firmware build: only the
 * declarations the vendored TinyUSB C references. memcpy/memset are
 * implemented by Zig's compiler_rt; strlen is used by cdc_device.h's inline
 * tud_cdc_write_str() helper and is provided by lib/zfat_shim's shim.c
 * (already linked into every firmware variant for FatFs) — declare it here
 * too so it resolves without implicit-declaration warnings/errors when this
 * header is picked up ahead of a system <string.h>.
 * Mirrors lib/zfat_shim/string.h's convention for the same target gap. */
#ifndef ZMETAL_TINYUSB_SHIM_STRING_H
#define ZMETAL_TINYUSB_SHIM_STRING_H
#include <stddef.h>
void *memcpy(void *dst, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
size_t strlen(const char *s);
#endif
