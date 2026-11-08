/* Nexvyn compat layer - the opt-in part of the PC path handling: case-insensitive lookup and the path wrappers of the
 * --wrap=opendir family (wrap_fsmap.txt, nexvyn_compat_fsmap() in the CMake helper). With every flag off they call straight
 * through. This object is only linked when those wrapper symbols are referenced, which is why it can use __real_opendir
 * and friends without a plain nexvyn_use_compat() link needing the flags. Configuration and map_path: nxc_fsmap.c. */
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

#include "nxc_internal.h"
#include "nxc_path.h"

FILE* __real_freopen(const char* path, const char* mode, FILE* f);
int __real_stat(const char* path, struct stat* st);
DIR* __real_opendir(const char* path);
int __real_mkdir(const char* path, mode_t mode);
int __real_rmdir(const char* path);
int __real_unlink(const char* path);
int __real_remove(const char* path);
int __real_rename(const char* from, const char* to);
int __real_truncate(const char* path, off_t len);
int __real_chmod(const char* path, mode_t mode);

#define map_path nxc__map_path
#define MAP1(var, in)                                \
    char var##_buf[NXC_PATH_MAX];                    \
    const char* var = map_path((in), var##_buf);     \
    if ((in) && !var) return NXC_FAIL(errno)

/* ---- case-insensitive resolution ---- */

/* Finds an entry of dir that equals name ignoring case. Returns 1 and copies the real spelling into found. */
static int find_ci(const char* dir, const char* name, char* found, size_t cap) {
    DIR* d = __real_opendir(dir[0] ? dir : ".");
    if (!d) return 0;
    int hit = 0;
    struct dirent* e;
    while ((e = readdir(d)) != NULL) {
        if (strcasecmp(e->d_name, name) == 0) {
            if (strlen(e->d_name) < cap) {
                strcpy(found, e->d_name);
                hit = 1;
            }
            /* an exact match wins over a different-case one */
            if (strcmp(e->d_name, name) == 0) break;
        }
    }
    closedir(d);
    return hit;
}

/* Hook of nxc_fsmap.c. path (already translated) -> out with each component spelled like the file system has it. 1 = the whole path exists. */
int nxc__resolve_case(const char* path, char* out, size_t cap) {
    struct stat st;
    if (strlen(path) >= cap) return 0;
    strcpy(out, path);
    if (__real_stat(out, &st) == 0) return 1;

    char res[NXC_PATH_MAX];
    size_t rl = nxc_path_device_len(path);
    memcpy(res, path, rl);
    const char* p = path + rl;
    while (*p == '/') {
        res[rl++] = '/';
        p++;
    }
    res[rl] = 0;
    int searching = 1;
    while (*p) {
        const char* e = p;
        while (*e && *e != '/') e++;
        size_t cl = (size_t)(e - p);
        if (cl > NAME_MAX || rl + cl + 2 >= sizeof res) return 0;
        size_t parent_len = rl;
        if (rl && res[rl - 1] != '/') res[rl++] = '/';
        memcpy(res + rl, p, cl);
        res[rl + cl] = 0;
        if (searching && __real_stat(res, &st) != 0) {
            char parent[NXC_PATH_MAX], name[NAME_MAX + 1], found[NAME_MAX + 1];
            memcpy(parent, res, parent_len);
            parent[parent_len] = 0;
            memcpy(name, p, cl);
            name[cl] = 0;
            if (find_ci(parent, name, found, sizeof found)) {
                size_t fl = strlen(found);
                if (rl + fl + 1 >= sizeof res) return 0;
                memcpy(res + rl, found, fl + 1);
                cl = fl;
            } else {
                searching = 0; /* nothing below a missing folder can exist */
            }
        }
        rl += cl;
        p = e;
        while (*p == '/') p++;
    }
    if (strlen(res) >= cap) return 0;
    strcpy(out, res);
    return searching && __real_stat(out, &st) == 0;
}

FILE* __wrap_freopen(const char* path, const char* mode, FILE* f) {
    char b[NXC_PATH_MAX];
    const char* p = map_path(path, b);
    if (path && !p) return NULL;
    return __real_freopen(p, mode, f);
}


DIR* __wrap_opendir(const char* path) {
    char b[NXC_PATH_MAX];
    const char* p = map_path(path, b);
    if (path && !p) return NULL;
    return __real_opendir(p);
}

int __wrap_mkdir(const char* path, mode_t mode) { MAP1(p, path); return __real_mkdir(p, mode); }
int __wrap_rmdir(const char* path) { MAP1(p, path); return __real_rmdir(p); }
int __wrap_unlink(const char* path) { MAP1(p, path); return __real_unlink(p); }
int __wrap_remove(const char* path) { MAP1(p, path); return __real_remove(p); }
int __wrap_truncate(const char* path, off_t len) { MAP1(p, path); return __real_truncate(p, len); }
int __wrap_chmod(const char* path, mode_t mode) { MAP1(p, path); return __real_chmod(p, mode); }

int __wrap_rename(const char* from, const char* to) {
    MAP1(a, from);
    MAP1(b, to);
    return __real_rename(a, b);
}
