#include "compat_fs.h"
#include <dirent.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>

static int exists(const char* p) {
    struct stat st;
    return stat(p, &st) == 0;
}

int compat_resolve_path(const char* path, char* out, size_t outSize) {
    if (!path || !outSize) return -1;
    if (exists(path)) {  // fast path: exact spelling
        if (strlen(path) >= outSize) return -1;
        strcpy(out, path);
        return 0;
    }
    char cur[512];
    size_t len = 0;
    const char* p = path;
    // keep the device prefix ("sdmc:", "romfs:") as written; only the components after it are matched
    const char* colon = strchr(path, ':');
    if (colon && colon - path < 16) {
        size_t n = (size_t)(colon - path) + 1;
        memcpy(cur, path, n);
        len = n;
        p = colon + 1;
    }
    while (*p) {
        while (*p == '/') {
            if (len + 1 >= sizeof cur) return -1;
            if (len == 0 || cur[len - 1] != '/') cur[len++] = '/';
            p++;
        }
        if (!*p) break;
        char comp[256];
        size_t cl = 0;
        while (p[cl] && p[cl] != '/') cl++;
        if (cl >= sizeof comp) return -1;
        memcpy(comp, p, cl);
        comp[cl] = 0;
        p += cl;

        cur[len] = 0;
        DIR* d = opendir(len ? cur : ".");
        if (!d) return -1;
        struct dirent* e;
        int found = 0;
        while ((e = readdir(d)) != NULL) {
            if (strcasecmp(e->d_name, comp) == 0) {
                size_t nl = strlen(e->d_name);
                if (len + nl + 1 >= sizeof cur) { closedir(d); return -1; }
                memcpy(cur + len, e->d_name, nl);
                len += nl;
                found = 1;
                break;
            }
        }
        closedir(d);
        if (!found) return -1;
    }
    cur[len] = 0;
    if (len >= outSize) return -1;
    strcpy(out, cur);
    return 0;
}

FILE* fopen_ci(const char* path, const char* mode) {
    char real[512];
    if (compat_resolve_path(path, real, sizeof real) == 0) return fopen(real, mode);
    return fopen(path, mode);  // not found: let fopen set errno (or create the file for "w" modes)
}
