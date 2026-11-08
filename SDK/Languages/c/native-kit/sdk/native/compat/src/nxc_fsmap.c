/* Nexvyn compat layer - the always-on part of the file calls: the pseudo devices (/dev/null ...), the path configuration and
 * the wrappers of open, fopen, stat, lstat, access, chdir, getcwd and realpath (wrap_core.txt).
 *
 * The opt-in PC path handling ("\\" separators, drive letters, "/x" rooted at the app folder, case-insensitive lookup) is
 * configured here too, but it only does something when nexvyn_compat_fsmap() set the flags (or nxc_fs_enable() did at run
 * time). Everything that needs the --wrap=opendir family (__real_opendir ...) lives in nxc_fsmap_wrap.c, which this file
 * reaches through a weak reference only, so a program linked with plain nexvyn_use_compat() never needs those flags. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>
#include <utime.h>

#include "nexvyn/compat.h"
#include "nxc_internal.h"
#include "nxc_path.h"

/* The libraries behind the wrappers. */
int __real_open(const char* path, int flags, ...);
FILE* __real_fopen(const char* path, const char* mode);
int __real_stat(const char* path, struct stat* st);
int __real_lstat(const char* path, struct stat* st);
int __real_access(const char* path, int mode);
int __real_chdir(const char* path);
int __real_close(int fd);
int __real_fclose(FILE* f);
char* __real_getcwd(char* buf, size_t size);

/* Defined in nxc_fsmap_wrap.c. A weak reference never pulls an archive member in: the member comes only with the
 * --wrap=opendir family (nexvyn_compat_fsmap), whose __real_* symbols it needs. Without it the case folding is off. */
extern int nxc__resolve_case(const char* path, char* out, size_t cap) __attribute__((weak));

char* __wrap_getcwd(char* buf, size_t size);
#if NXC_WINDOWED
/* A window cannot chdir the process (the working directory belongs to Nexvyn OS and every app): the app's own directory
 * is kept here, relative paths of the wrapped calls are made absolute with it, chdir / getcwd / realpath use it. */
static char g_vcwd[NXC_PATH_MAX];
const char* nxc__default_root(void);
const char* nxc__vcwd(void) {
    mutexLock(&g_nxc_mu);
    if (!g_vcwd[0]) snprintf(g_vcwd, sizeof g_vcwd, "%s", nxc__default_root());
    mutexUnlock(&g_nxc_mu);
    return g_vcwd;
}
static char* win_getcwd(char* buf, size_t size) {
    const char* c = nxc__vcwd();
    if (strlen(c) >= size) return (errno = ERANGE, NULL);
    memcpy(buf, c, strlen(c) + 1);
    return buf;
}
#define REAL_GETCWD win_getcwd
#else
#define REAL_GETCWD __real_getcwd
#endif
extern const unsigned nxc_fsmap_flags __attribute__((weak)); /* defined by nexvyn_compat_fsmap() */
const char* nxc__default_root(void);

static nxc_pathcfg g_cfg;
static int g_cfg_ready;

static void cfg_init(void) {
    if (g_cfg_ready) return;
    mutexLock(&g_nxc_mu);
    if (!g_cfg_ready) {
        snprintf(g_cfg.root, sizeof g_cfg.root, "%s", nxc__default_root());
        size_t n = strlen(g_cfg.root);
        while (n > 1 && g_cfg.root[n - 1] == '/') g_cfg.root[--n] = 0;
        g_cfg.flags = &nxc_fsmap_flags ? (nxc_fsmap_flags & NXC_FS_ALL) : 0;
        g_cfg_ready = 1;
    }
    mutexUnlock(&g_nxc_mu);
}

void nxc_fs_enable(unsigned flags) {
    cfg_init();
    g_cfg.flags = flags & NXC_FS_ALL;
}

unsigned nxc_fs_flags(void) {
    cfg_init();
    return g_cfg.flags;
}

void nxc_fs_set_root(const char* real_dir) {
    cfg_init();
    if (!real_dir || !real_dir[0]) return;
    snprintf(g_cfg.root, sizeof g_cfg.root, "%s", real_dir);
    size_t n = strlen(g_cfg.root);
    while (n > 1 && g_cfg.root[n - 1] == '/') g_cfg.root[--n] = 0;
}

const char* nxc_fs_root(void) {
    cfg_init();
    return g_cfg.root;
}

int nxc_fs_map_drive(char letter, const char* real_dir) {
    cfg_init();
    if (!((letter >= 'a' && letter <= 'z') || (letter >= 'A' && letter <= 'Z')) || !real_dir) return NXC_FAIL(EINVAL);
    int idx = (letter >= 'a' ? letter - 'a' : letter - 'A');
    if (strlen(real_dir) >= sizeof g_cfg.drives[idx]) return NXC_FAIL(ENAMETOOLONG);
    snprintf(g_cfg.drives[idx], sizeof g_cfg.drives[idx], "%s", real_dir);
    size_t n = strlen(g_cfg.drives[idx]);
    while (n > 1 && g_cfg.drives[idx][n - 1] == '/') g_cfg.drives[idx][--n] = 0;
    return 0;
}

int nxc_fs_translate(const char* in, char* out, size_t cap) {
    if (!in || !out) return NXC_FAIL(EINVAL);
    cfg_init();
    return nxc_path_translate(&g_cfg, in, out, cap) == 0 ? 0 : NXC_FAIL(ENAMETOOLONG);
}

/* Translate (and case-resolve) a path for a wrapped call. Returns the string to hand to the real function, or NULL with
 * errno set. buf must hold NXC_PATH_MAX. */
const char* nxc__map_path(const char* in, char* buf) {
    if (!in) return in;
    cfg_init();
    char tmp[NXC_PATH_MAX];
    const char* cur = in;
    if (g_cfg.flags) {
        if (nxc_path_translate(&g_cfg, in, tmp, sizeof tmp) != 0) return (errno = ENAMETOOLONG, NULL);
        cur = tmp;
    }
#if NXC_WINDOWED
    char abs[NXC_PATH_MAX];
    if (cur[0] && cur[0] != '/' && !nxc_path_device_len(cur)) {
        if (snprintf(abs, sizeof abs, "%s/%s", nxc__vcwd(), cur) >= (int)sizeof abs) return (errno = ENAMETOOLONG, NULL);
        cur = abs;
    }
    if (!g_cfg.flags) {
        if (cur == in) return in;
        memcpy(buf, cur, strlen(cur) + 1);
        return buf;
    }
#else
    if (!g_cfg.flags) return in;
#endif
    if ((g_cfg.flags & NXC_FS_CASEFOLD) && nxc__resolve_case) {
        if (!nxc__resolve_case(cur, buf, NXC_PATH_MAX)) {
            if (strlen(cur) >= NXC_PATH_MAX) return (errno = ENAMETOOLONG, NULL);
            /* not found: the parents are spelled right where they exist, the last name stays as given (creation) */
        }
        return buf;
    }
    memcpy(buf, cur, strlen(cur) + 1);
    return buf;
}
#define map_path nxc__map_path

#define MAP1(var, in)                                \
    char var##_buf[NXC_PATH_MAX];                    \
    const char* var = map_path((in), var##_buf);     \
    if ((in) && !var) return NXC_FAIL(errno)

/* ---- write-open files ----
 * On a console the SD card file system (Horizon FS) refuses stat() of a file this process has open for writing, with
 * EIO (an emulator does not, and answers with the size of the last flush). Ported programs do that all the time (write,
 * then stat to learn the size). So the path of every file opened for writing is remembered per descriptor, and stat /
 * lstat / access of such a path are answered from fstat() of the open descriptor, which is right on both. Entries are dropped by close / fclose. Not covered: a
 * descriptor made by dup / fdopen / freopen, and a second open of the file (the file system still refuses it). */
#define NXC_WO_SLOTS 64
static struct {
    int fd; /* -1 = free */
    char path[NXC_PATH_MAX];
} g_wo[NXC_WO_SLOTS];
static int g_wo_init;
static volatile int g_wo_count; /* entries in use: stat of any other path skips the table while it is 0 */

/* Absolute, lexically normalised key of a mapped path; 0 on success. */
static int wo_key(const char* mapped, char* out, size_t cap) {
    char abs[NXC_PATH_MAX];
    if (!nxc_path_device_len(mapped) && mapped[0] != '/') {
        char cwd[NXC_PATH_MAX];
        if (!REAL_GETCWD(cwd, sizeof cwd)) return -1;
        if (snprintf(abs, sizeof abs, "%s/%s", cwd, mapped) >= (int)sizeof abs) return -1;
    } else if (snprintf(abs, sizeof abs, "%s", mapped) >= (int)sizeof abs) {
        return -1;
    }
    return nxc_path_normalize(abs, out, cap);
}

static void wo_init_locked(void) {
    if (g_wo_init) return;
    for (int i = 0; i < NXC_WO_SLOTS; i++) g_wo[i].fd = -1;
    g_wo_init = 1;
}

static void wo_add(int fd, const char* mapped) {
    char key[NXC_PATH_MAX];
    if (fd < 0 || wo_key(mapped, key, sizeof key) != 0) return;
    mutexLock(&g_nxc_mu);
    wo_init_locked();
    int slot = -1;
    for (int i = 0; i < NXC_WO_SLOTS; i++) {
        if (g_wo[i].fd == fd) { slot = i; break; }
        if (slot < 0 && g_wo[i].fd < 0) slot = i;
    }
    if (slot >= 0) {
        if (g_wo[slot].fd < 0) g_wo_count++;
        g_wo[slot].fd = fd;
        memcpy(g_wo[slot].path, key, strlen(key) + 1);
    }
    mutexUnlock(&g_nxc_mu);
}

static void wo_remove(int fd) {
    if (fd < 0) return;
    mutexLock(&g_nxc_mu);
    wo_init_locked();
    for (int i = 0; i < NXC_WO_SLOTS; i++)
        if (g_wo[i].fd == fd) {
            g_wo[i].fd = -1;
            g_wo_count--;
        }
    mutexUnlock(&g_nxc_mu);
}

/* Descriptor of a write-open file with this (mapped) path, or -1. FAT is case-insensitive, so the compare is too. */
static int wo_find(const char* mapped) {
    char key[NXC_PATH_MAX];
    if (wo_key(mapped, key, sizeof key) != 0) return -1;
    int fd = -1;
    mutexLock(&g_nxc_mu);
    wo_init_locked();
    for (int i = 0; i < NXC_WO_SLOTS; i++)
        if (g_wo[i].fd >= 0 && strcasecmp(g_wo[i].path, key) == 0) { fd = g_wo[i].fd; break; }
    mutexUnlock(&g_nxc_mu);
    return fd;
}

/* fstat of our own write-open descriptor for this path. 0 = answered, -1 = not ours (errno kept). */
static int wo_fstat(const char* mapped, struct stat* st) {
    int fd = wo_find(mapped);
    if (fd < 0) return -1;
    struct stat tmp;
    if (fstat(fd, &tmp) != 0 || !S_ISREG(tmp.st_mode)) return -1;
    if (st) *st = tmp;
    return 0;
}

int __wrap_open(const char* path, int flags, ...) {
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = (mode_t)va_arg(ap, int);
        va_end(ap);
    }
    if (nxc__dev_match(path)) return nxc__dev_open(path, flags);
    MAP1(p, path);
    int fd = __real_open(p, flags, mode);
    if (fd >= 0 && p && (flags & O_ACCMODE) != O_RDONLY) wo_add(fd, p);
    return fd;
}

FILE* __wrap_fopen(const char* path, const char* mode) {
    if (nxc__dev_match(path)) return nxc__dev_fopen(path, mode);
    char b[NXC_PATH_MAX];
    const char* p = map_path(path, b);
    if (path && !p) return NULL;
    FILE* f = __real_fopen(p, mode);
    if (f && p && mode && (strchr(mode, 'w') || strchr(mode, 'a') || strchr(mode, '+'))) wo_add(fileno(f), p);
    return f;
}

int __wrap_close(int fd) {
    wo_remove(fd);
#if NXC_WINDOWED
    nxc__sock_forget(fd);
#endif
    return __real_close(fd);
}

int __wrap_fclose(FILE* f) {
    if (f) wo_remove(fileno(f));
    return __real_fclose(f);
}

int __wrap_stat(const char* path, struct stat* st) {
    if (nxc__dev_match(path)) return nxc__dev_stat(path, st);
    MAP1(p, path);
    if (g_wo_count > 0 && p && wo_fstat(p, st) == 0) return 0;
    return __real_stat(p, st);
}

int __wrap_lstat(const char* path, struct stat* st) {
    if (nxc__dev_match(path)) return nxc__dev_stat(path, st);
    MAP1(p, path);
    if (g_wo_count > 0 && p && wo_fstat(p, st) == 0) return 0;
    return __real_lstat(p, st);
}

int __wrap_access(const char* path, int mode) {
    if (nxc__dev_match(path)) return nxc__dev_access(path, mode);
    MAP1(p, path);
    if (g_wo_count > 0 && p && wo_fstat(p, NULL) == 0) return 0;
    return __real_access(p, mode);
}

int __wrap_chdir(const char* path) {
    MAP1(p, path);
#if NXC_WINDOWED
    char norm[NXC_PATH_MAX];
    struct stat dst;
    if (nxc_path_normalize(p, norm, sizeof norm) != 0) return NXC_FAIL(ENAMETOOLONG);
    if (__real_stat(norm, &dst) != 0) return -1;
    if (!S_ISDIR(dst.st_mode)) return NXC_FAIL(ENOTDIR);
    nxc__vcwd();
    mutexLock(&g_nxc_mu);
    snprintf(g_vcwd, sizeof g_vcwd, "%s", norm);
    mutexUnlock(&g_nxc_mu);
    int rc = 0;
#else
    int rc = __real_chdir(p);
#endif
    if (rc == 0) {
        char cwd[NXC_PATH_MAX];
        if (__wrap_getcwd(cwd, sizeof cwd)) setenv("PWD", cwd, 1); /* keep $PWD true, like a shell would */
    }
    return rc;
}

char* __wrap_getcwd(char* buf, size_t size) {
    cfg_init();
    if (!(g_cfg.flags & NXC_FS_VROOT)) return REAL_GETCWD(buf, size);
    char real[NXC_PATH_MAX], virt[NXC_PATH_MAX];
    if (!REAL_GETCWD(real, sizeof real)) return NULL;
    if (nxc_path_virtualize(&g_cfg, real, virt, sizeof virt) != 0) return (errno = ERANGE, NULL);
    size_t need = strlen(virt) + 1;
    if (!buf) {
        buf = (char*)malloc(size > need ? size : need);
        if (!buf) return (errno = ENOMEM, NULL);
    } else if (size < need) {
        return (errno = ERANGE, NULL);
    }
    memcpy(buf, virt, need);
    return buf;
}

char* __wrap_realpath(const char* path, char* resolved) {
    if (!path) return (errno = EINVAL, NULL);
    cfg_init();
    char tmp[NXC_PATH_MAX], abs[NXC_PATH_MAX], norm[NXC_PATH_MAX], out[NXC_PATH_MAX];
    const char* mapped = map_path(path, tmp);
    if (!mapped) return NULL;
    if (!nxc_path_device_len(mapped) && mapped[0] != '/') {
        char cwd[NXC_PATH_MAX];
        if (!REAL_GETCWD(cwd, sizeof cwd)) return NULL;
        if (snprintf(abs, sizeof abs, "%s/%s", cwd, mapped) >= (int)sizeof abs) return (errno = ENAMETOOLONG, NULL);
    } else if (snprintf(abs, sizeof abs, "%s", mapped) >= (int)sizeof abs) {
        return (errno = ENAMETOOLONG, NULL);
    }
    if (nxc_path_normalize(abs, norm, sizeof norm) != 0) return (errno = ENAMETOOLONG, NULL);
    struct stat st;
    if (__real_stat(norm, &st) != 0) return NULL; /* errno from stat (ENOENT ...) */
    if ((g_cfg.flags & NXC_FS_VROOT) ? nxc_path_virtualize(&g_cfg, norm, out, sizeof out) != 0 : (snprintf(out, sizeof out, "%s", norm) >= (int)sizeof out))
        return (errno = ENAMETOOLONG, NULL);
    size_t need = strlen(out) + 1;
    if (!resolved) {
        resolved = (char*)malloc(need);
        if (!resolved) return (errno = ENOMEM, NULL);
    }
    memcpy(resolved, out, need);
    return resolved;
}
