/* Nexvyn compat layer - pure path rules (no OS calls; the host tests compile nxc_path.c as is). */
#ifndef NXC_PATH_H
#define NXC_PATH_H

#include <stddef.h>

#define NXC_PATH_MAX 1024

typedef struct nxc_pathcfg {
    unsigned flags;                    /* NXC_FS_* */
    char root[NXC_PATH_MAX];           /* no trailing "/" */
    char drives[26][NXC_PATH_MAX];     /* "" = use root */
} nxc_pathcfg;

/* Length of a device prefix like "sdmc:" / "romfs:" (a name of 2+ characters, then ':'), 0 if none. A single letter and ':'
 * is a drive, not a device. */
size_t nxc_path_device_len(const char* p);

/* PC path -> Switch path (see nexvyn/compat.h). 0 on success, -1 when it does not fit. in == out is allowed. */
int nxc_path_translate(const nxc_pathcfg* cfg, const char* in, char* out, size_t cap);

/* Lexical clean-up: "//" -> "/", "." dropped, ".." resolved (never above the root of the path). 0 / -1. in == out allowed. */
int nxc_path_normalize(const char* in, char* out, size_t cap);

/* "<root>/a/b" -> "/a/b" (and the root itself -> "/"); anything else is copied unchanged. 0 / -1. */
int nxc_path_virtualize(const nxc_pathcfg* cfg, const char* real, char* out, size_t cap);

#endif
