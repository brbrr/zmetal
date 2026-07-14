/* Minimal <inttypes.h> for the freestanding (no-libc) firmware build.
 *
 * tusb_common.h unconditionally #includes <inttypes.h> (for the PRIxNN
 * printf-format macros), but zig's bundled freestanding libc headers for
 * this target don't provide it. The only reference to a PRI* macro in the
 * TinyUSB source set we compile is inside dwc2_common.c's TU_LOG1(...) call,
 * which macro-expands to nothing because CFG_TUSB_DEBUG is left undefined
 * in tusb_config.h — so no PRI* macro actually needs to exist here. This
 * header only needs to be *present* so the #include resolves; it is
 * intentionally empty of content otherwise. */
#ifndef ZMETAL_TINYUSB_SHIM_INTTYPES_H
#define ZMETAL_TINYUSB_SHIM_INTTYPES_H
#endif
