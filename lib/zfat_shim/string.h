/* Minimal <string.h> for the freestanding (no-libc) firmware build: only the
 * declarations the vendored FatFs C references. memcpy/memset/memcmp are
 * implemented by Zig's compiler_rt; strchr/strlen come from shim.c. */
#ifndef ZMETAL_ZFAT_SHIM_STRING_H
#define ZMETAL_ZFAT_SHIM_STRING_H
#include <stddef.h>
void *memcpy(void *dst, const void *src, size_t n);
void *memset(void *s, int c, size_t n);
int memcmp(const void *a, const void *b, size_t n);
char *strchr(const char *s, int c);
size_t strlen(const char *s);
#endif
