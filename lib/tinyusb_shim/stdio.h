/* Minimal <stdio.h> for the freestanding (no-libc) firmware build.
 *
 * tusb_common.h unconditionally #includes <stdio.h> (for printf/snprintf
 * used only by CFG_TUSB_DEBUG logging helpers), but zig's bundled
 * freestanding libc headers don't provide it. CFG_TUSB_DEBUG is left
 * undefined in tusb_config.h, so TU_LOG1(...) and friends macro-expand to
 * nothing and no printf-family symbol is actually referenced by the
 * TinyUSB source set we compile. This header only needs to be *present* so
 * the #include resolves; it is intentionally empty of content otherwise. */
#ifndef ZMETAL_TINYUSB_SHIM_STDIO_H
#define ZMETAL_TINYUSB_SHIM_STDIO_H
#endif
