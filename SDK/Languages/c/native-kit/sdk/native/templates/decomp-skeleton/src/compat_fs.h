// Case-insensitive file access for decompilation ports: PC games ship "Data/Level1.DAT" and open "data/level1.dat".
// romfs and many SD card layouts are case-sensitive, so fopen_ci() tries the path as given, then matches every path
// component against the directory listing ignoring case.
#pragma once
#include <stdio.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Writes the real on-disk spelling of `path` to `out`; returns 0 on success, -1 when no match exists.
int compat_resolve_path(const char* path, char* out, size_t outSize);
FILE* fopen_ci(const char* path, const char* mode);

#ifdef __cplusplus
}
#endif
