/* Freestanding libc shim for the vendored FatFs C (no system libc), injected
 * into the zfat module from build.zig. mem* are supplied by Zig's compiler_rt;
 * FatFs also calls strchr/strlen, implemented here. malloc/free are only used
 * by FatFs when FF_USE_LFN == 3 (heap LFN), which this build does not enable,
 * so they are intentionally omitted. */
#include <stddef.h>

char *strchr(const char *s, int c) {
    const char ch = (char)c;
    for (;; s++) {
        if (*s == ch) return (char *)s;
        if (*s == '\0') return NULL;
    }
}

size_t strlen(const char *s) {
    const char *p = s;
    while (*p) p++;
    return (size_t)(p - s);
}
