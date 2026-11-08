/* Nexvyn compat layer - pure path rules. Keep this file free of OS calls: sdk/native/compat/tests/host builds it on the PC. */
#include "nxc_path.h"

#include <ctype.h>
#include <string.h>

#define F_CASEFOLD  0x01u
#define F_BACKSLASH 0x02u
#define F_DRIVES    0x04u
#define F_VROOT     0x08u

size_t nxc_path_device_len(const char* p) {
    size_t i = 0;
    while (p[i] && p[i] != '/' && p[i] != '\\' && p[i] != ':') i++;
    return (p[i] == ':' && i >= 2) ? i + 1 : 0;
}

static int put(char* out, size_t cap, size_t* n, const char* s, size_t len) {
    if (*n + len + 1 > cap) return -1;
    memmove(out + *n, s, len);
    *n += len;
    out[*n] = 0;
    return 0;
}

int nxc_path_translate(const nxc_pathcfg* cfg, const char* in, char* out, size_t cap) {
    char tmp[NXC_PATH_MAX];
    size_t len = strlen(in);
    if (len >= sizeof tmp || cap == 0) return -1;
    for (size_t i = 0; i <= len; i++) tmp[i] = ((cfg->flags & F_BACKSLASH) && in[i] == '\\') ? '/' : in[i];

    const char* base = NULL;
    const char* rest = tmp;
    if (nxc_path_device_len(tmp)) {
        /* already a Switch path */
    } else if ((cfg->flags & F_DRIVES) && isalpha((unsigned char)tmp[0]) && tmp[1] == ':') {
        int idx = toupper((unsigned char)tmp[0]) - 'A';
        base = cfg->drives[idx][0] ? cfg->drives[idx] : cfg->root;
        rest = tmp + 2;
    } else if ((cfg->flags & F_VROOT) && tmp[0] == '/') {
        base = cfg->root;
    }
    size_t n = 0;
    out[0] = 0;
    if (base) {
        if (put(out, cap, &n, base, strlen(base))) return -1;
        if (*rest && *rest != '/' && put(out, cap, &n, "/", 1)) return -1; /* "C:foo" */
        if (!*rest && n == 0 && put(out, cap, &n, "/", 1)) return -1;
    }
    return put(out, cap, &n, rest, strlen(rest));
}

int nxc_path_normalize(const char* in, char* out, size_t cap) {
    char tmp[NXC_PATH_MAX];
    size_t len = strlen(in);
    if (len >= sizeof tmp || cap == 0) return -1;
    memcpy(tmp, in, len + 1);

    size_t dev = nxc_path_device_len(tmp);
    int absolute = tmp[dev] == '/';
    size_t n = 0;
    out[0] = 0;
    if (dev && put(out, cap, &n, tmp, dev)) return -1;
    if (absolute && put(out, cap, &n, "/", 1)) return -1;
    size_t floor_len = n;   /* never cut below this (the root) */
    for (char* p = tmp + dev; *p;) {
        while (*p == '/') p++;
        char* e = p;
        while (*e && *e != '/') e++;
        size_t cl = (size_t)(e - p);
        if (cl == 0) break;
        if (cl == 1 && p[0] == '.') {
            /* skip */
        } else if (cl == 2 && p[0] == '.' && p[1] == '.') {
            size_t k = n;
            while (k > floor_len && out[k - 1] == '/') k--;
            size_t cut = k;
            while (cut > floor_len && out[cut - 1] != '/') cut--;
            if (cut == k && !absolute) {
                /* leading ".." of a relative path stays */
                if (n > floor_len && out[n - 1] != '/' && put(out, cap, &n, "/", 1)) return -1;
                if (put(out, cap, &n, "..", 2)) return -1;
            } else if (cut < k) {
                n = cut;
                out[n] = 0;
            }
        } else {
            if (n > floor_len && out[n - 1] != '/' && put(out, cap, &n, "/", 1)) return -1;
            if (put(out, cap, &n, p, cl)) return -1;
        }
        p = e;
    }
    while (n > floor_len + 1 && out[n - 1] == '/') out[--n] = 0;
    if (n == 0 && put(out, cap, &n, ".", 1)) return -1;
    return 0;
}

int nxc_path_virtualize(const nxc_pathcfg* cfg, const char* real, char* out, size_t cap) {
    size_t rl = strlen(cfg->root);
    size_t n = 0;
    out[0] = 0;
    if (rl && strncmp(real, cfg->root, rl) == 0 && (real[rl] == '/' || real[rl] == 0)) {
        const char* rest = real + rl;
        if (put(out, cap, &n, *rest ? rest : "/", strlen(*rest ? rest : "/"))) return -1;
        return 0;
    }
    return put(out, cap, &n, real, strlen(real));
}
