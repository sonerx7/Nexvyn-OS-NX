/* Nexvyn Native SDK library - hand-off / return record text formats (nxn_handoff.h). Valid C and C++. */
#include "nxn_handoff.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void copy_field(char* dst, size_t cap, const char* v, size_t vl) {
    if (vl >= cap) vl = cap - 1;
    memcpy(dst, v, vl);
    dst[vl] = 0;
}

static uint64_t parse_u64(const char* v, size_t vl) {
    char tmp[40];
    copy_field(tmp, sizeof tmp, v, vl);
    return (uint64_t)strtoull(tmp, NULL, 0);
}

static int64_t parse_i64(const char* v, size_t vl) {
    char tmp[40];
    copy_field(tmp, sizeof tmp, v, vl);
    return (int64_t)strtoll(tmp, NULL, 0);
}

typedef void (*kv_fn)(void* user, const char* k, size_t kl, const char* v, size_t vl);

/* Header "<word> <version>" on the first line, then key=value lines (CR LF tolerated). Returns the version or 0. */
static int kv_parse(const char* text, size_t len, const char* word, kv_fn fn, void* user) {
    size_t wl = strlen(word), i = 0;
    if (!text || len < wl + 2 || memcmp(text, word, wl) != 0 || text[wl] != ' ') return 0;
    int version = atoi(text + wl + 1);
    if (version < 1) return 0;
    while (i < len && text[i] != '\n') i++;
    while (i < len) {
        size_t s = ++i;
        while (i < len && text[i] != '\n') i++;
        size_t e = i;
        if (e > s && text[e - 1] == '\r') e--;
        const char* eq = (const char*)memchr(text + s, '=', e - s);
        if (!eq || eq == text + s) continue;
        fn(user, text + s, (size_t)(eq - (text + s)), eq + 1, (size_t)(text + e - (eq + 1)));
    }
    return version;
}

#define KEY(name) (kl == sizeof(name) - 1 && memcmp(k, name, kl) == 0)
#define STR(name, field) else if (KEY(name)) copy_field(h->field, sizeof h->field, v, vl)

static void handoff_kv(void* user, const char* k, size_t kl, const char* v, size_t vl) {
    nxn__handoff* h = (nxn__handoff*)user;
    if (0) {}
    STR("host", host);
    STR("host_nro", host_nro);
    STR("os_version", os_version);
    STR("sdk_version", sdk_version);
    STR("native_version", native_version);
    STR("app_id", app_id);
    STR("app_version", app_version);
    STR("bundle", bundle);
    STR("data", data);
    STR("cache", cache);
    STR("log", log);
    STR("return", ret);
    STR("user", user);
    STR("language", language);
    STR("theme", theme);
    STR("launch_id", launch_id);
    else if (KEY("accent")) h->accent = (uint32_t)parse_u64(v, vl);
    else if (KEY("confirm")) h->confirm = parse_u64(v, vl);
    else if (KEY("cancel")) h->cancel = parse_u64(v, vl);
}

#undef STR
#define STR(name, field) else if (KEY(name)) copy_field(r->field, sizeof r->field, v, vl)

static void return_kv(void* user, const char* k, size_t kl, const char* v, size_t vl) {
    nxn__return_rec* r = (nxn__return_rec*)user;
    if (0) {}
    STR("launch_id", launch_id);
    STR("state", state);
    STR("reason", reason);
    STR("message", message);
    STR("crash_kind", crash_kind);
    STR("crash_thread", crash_thread);
    else if (KEY("code")) r->code = (int32_t)parse_i64(v, vl);
    else if (KEY("crash_pc")) r->crash_pc = parse_u64(v, vl);
    else if (KEY("crash_lr")) r->crash_lr = parse_u64(v, vl);
    else if (KEY("crash_far")) r->crash_far = parse_u64(v, vl);
    else if (KEY("time")) r->time = parse_i64(v, vl);
}

int nxn__handoff_parse(const char* text, size_t len, nxn__handoff* out) {
    int v = kv_parse(text, len, "nxn-handoff", handoff_kv, out);
    if (v) out->version = v;
    return v > 0;
}

int nxn__return_parse(const char* text, size_t len, nxn__return_rec* out) {
    int v = kv_parse(text, len, "nxn-return", return_kv, out);
    if (v) out->version = v;
    return v > 0;
}

/* Appends "key=value\n"; line breaks inside the value become spaces. */
static int put(char* out, size_t cap, size_t* pos, const char* key, const char* value) {
    size_t kl = strlen(key), vl = strlen(value);
    if (*pos + kl + vl + 2 >= cap) return 0;
    memcpy(out + *pos, key, kl);
    *pos += kl;
    out[(*pos)++] = '=';
    for (size_t i = 0; i < vl; i++) out[(*pos)++] = (value[i] == '\n' || value[i] == '\r') ? ' ' : value[i];
    out[(*pos)++] = '\n';
    out[*pos] = 0;
    return 1;
}

size_t nxn__return_format(const nxn__return_rec* r, char* out, size_t cap) {
    char num[40];
    size_t pos = 0;
    if (!out || cap < 32) return 0;
    pos = (size_t)snprintf(out, cap, "nxn-return %d\n", NXN_RETURN_VERSION);
    int ok = put(out, cap, &pos, "launch_id", r->launch_id) && put(out, cap, &pos, "state", r->state) &&
             put(out, cap, &pos, "reason", r->reason);
    snprintf(num, sizeof num, "%d", (int)r->code);
    ok = ok && put(out, cap, &pos, "code", num);
    if (r->message[0]) ok = ok && put(out, cap, &pos, "message", r->message);
    if (r->crash_kind[0]) {
        ok = ok && put(out, cap, &pos, "crash_kind", r->crash_kind) && put(out, cap, &pos, "crash_thread", r->crash_thread);
        snprintf(num, sizeof num, "0x%llx", (unsigned long long)r->crash_pc);
        ok = ok && put(out, cap, &pos, "crash_pc", num);
        snprintf(num, sizeof num, "0x%llx", (unsigned long long)r->crash_lr);
        ok = ok && put(out, cap, &pos, "crash_lr", num);
        snprintf(num, sizeof num, "0x%llx", (unsigned long long)r->crash_far);
        ok = ok && put(out, cap, &pos, "crash_far", num);
    }
    snprintf(num, sizeof num, "%lld", (long long)r->time);
    ok = ok && put(out, cap, &pos, "time", num);
    return ok ? pos : 0;
}

const char* nxn__handoff_arg(int argc, char** argv) {
    size_t n = strlen(NXN_HANDOFF_ARG);
    for (int i = 1; i < argc; i++)
        if (argv[i] && strncmp(argv[i], NXN_HANDOFF_ARG, n) == 0 && argv[i][n]) return argv[i] + n;
    return NULL;
}

int nxn__rel_ok(const char* rel) {
    if (!rel) return 0;
    if (rel[0] == '/' || rel[0] == '\\' || strchr(rel, ':')) return 0;
    const char* p = rel;
    while (*p) {
        const char* s = p;
        while (*p && *p != '/' && *p != '\\') p++;
        if (p - s == 2 && s[0] == '.' && s[1] == '.') return 0;
        if (*p) p++;
    }
    return 1;
}
