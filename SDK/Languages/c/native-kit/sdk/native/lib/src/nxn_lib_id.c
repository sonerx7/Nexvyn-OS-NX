/* Nexvyn Native SDK library - shared library identity and semver (nxn_lib_id.h). */
#include "nxn_lib_id.h"
#include "../../loader/nxelf.h"
#include <string.h>

static int read_num(const char** p, unsigned* out) {
    const char* s = *p;
    if (*s < '0' || *s > '9') return 0;
    unsigned long v = 0;
    while (*s >= '0' && *s <= '9') {
        v = v * 10 + (unsigned)(*s - '0');
        if (v > 0xFFFFFFu) return 0;
        s++;
    }
    *out = (unsigned)v;
    *p = s;
    return 1;
}

int nxn__semver_parse(const char* s, nxn__semver* out) {
    nxn__semver v;
    memset(&v, 0, sizeof v);
    if (!s || !read_num(&s, &v.major)) return 0;
    if (*s == '.') {
        s++;
        if (!read_num(&s, &v.minor)) return 0;
        if (*s == '.') {
            s++;
            if (!read_num(&s, &v.patch)) return 0;
        }
    }
    if (*s == '-') {
        if (!s[1]) return 0;
        v.pre = 1;
        s += strcspn(s, "+");
    }
    if (*s == '+') s += strlen(s);
    if (*s) return 0;
    if (out) *out = v;
    return 1;
}

int nxn__semver_cmp(const nxn__semver* a, const nxn__semver* b) {
    if (a->major != b->major) return a->major < b->major ? -1 : 1;
    if (a->minor != b->minor) return a->minor < b->minor ? -1 : 1;
    if (a->patch != b->patch) return a->patch < b->patch ? -1 : 1;
    if (a->pre != b->pre) return a->pre ? -1 : 1;
    return 0;
}

static int copy_field(char* dst, size_t cap, const char* src, size_t n) {
    if (n == 0 || n >= cap) return 0;
    memcpy(dst, src, n);
    dst[n] = 0;
    return 1;
}

int nxn__lib_id_parse(const char* text, size_t n, nxn__lib_id* out) {
    nxn__lib_id id;
    memset(&id, 0, sizeof id);
    size_t len = 0;
    while (len < n && text[len]) len++;
    if (len < 7 || memcmp(text, "nxvlib;", 7) != 0) return 0;
    size_t i = 7;
    while (i < len) {
        size_t end = i;
        while (end < len && text[end] != ';') end++;
        const char* eq = (const char*)memchr(text + i, '=', end - i);
        if (eq) {
            size_t klen = (size_t)(eq - (text + i)), vlen = end - (size_t)(eq - text) - 1;
            const char* val = eq + 1;
            if (klen == 3 && memcmp(text + i, "abi", 3) == 0 && !copy_field(id.abi, sizeof id.abi, val, vlen)) return 0;
            if (klen == 4 && memcmp(text + i, "name", 4) == 0 && !copy_field(id.name, sizeof id.name, val, vlen)) return 0;
            if (klen == 7 && memcmp(text + i, "version", 7) == 0 && !copy_field(id.version, sizeof id.version, val, vlen))
                return 0;
        }
        i = end + 1;
    }
    if (!id.abi[0] || !id.name[0] || !nxn__semver_parse(id.version, &id.ver)) return 0;
    if (out) *out = id;
    return 1;
}

int nxn__lib_id_read(const unsigned char* img, size_t size, nxn__lib_id* out) {
    uint64_t off = 0, bytes = 0;
    if (!nxelf_section(img, size, ".nxvlib", &off, &bytes)) return 1;
    return nxn__lib_id_parse((const char*)img + off, (size_t)bytes, out) ? 0 : 2;
}
