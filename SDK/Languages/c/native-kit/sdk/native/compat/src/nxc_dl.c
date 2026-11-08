/* Nexvyn compat layer - dlopen family on top of the Native SDK's shared libraries (nexvyn/nxn_lib.h, .nxvlib files),
 * plus a registry for dlsym(RTLD_DEFAULT) (nxc_dl_register). libnexvyn_native is referenced weakly: an app that links
 * only the compat layer gets a clear dlerror() text instead of a link error. */
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nexvyn/compat.h"
#include "nxc_internal.h"

#define MAIN_HANDLE ((void*)(uintptr_t)1)

/* nexvyn/nxn_lib.h (weak: present when the app links libnexvyn_native) */
typedef struct nxn_lib nxn_lib;
extern int32_t nxn_lib_open(const char* name, const char* min_version, nxn_lib** out) __attribute__((weak));
extern void* nxn_lib_sym(nxn_lib* lib, const char* name) __attribute__((weak));
extern int32_t nxn_lib_close(nxn_lib* lib) __attribute__((weak));
extern const char* nxn_lib_error(void) __attribute__((weak));

typedef struct dl_entry {
    char* name;
    void* addr;
} dl_entry;

static dl_entry* g_tab;
static size_t g_count, g_cap;
#if NXC_WINDOWED
typedef struct {
    const char* err;
    char buf[512];
} dl_tls;
static nxc_tlskey g_dl_key = {0, 0, free};
static dl_tls g_dl_fallback; /* only when memory is gone */
static dl_tls* dl_tl(void) {
    dl_tls* t = (dl_tls*)nxc__tls_get(&g_dl_key);
    if (!t) {
        t = (dl_tls*)calloc(1, sizeof *t);
        if (!t) return &g_dl_fallback;
        nxc__tls_set(&g_dl_key, t);
    }
    return t;
}
#define t_err (dl_tl()->err)
#define t_buf (dl_tl()->buf)
#else
static __thread const char* t_err;
static __thread char t_buf[512];
#endif

/* (file, handle) pairs dlopen returned, for RTLD_NOLOAD */
typedef struct dl_open {
    char* file;
    void* handle;
} dl_open;
static dl_open* g_open;
static size_t g_open_count, g_open_cap;

static void set_err(const char* prefix, const char* why) {
    snprintf(t_buf, sizeof t_buf, "%s: %s", prefix, why && why[0] ? why : "failed");
    t_err = t_buf;
}

int nxc_dl_register(const char* name, void* address) {
    if (!name || !name[0] || !address) return NXC_FAIL(EINVAL);
    char* copy = strdup(name);
    if (!copy) return NXC_FAIL(ENOMEM);
    mutexLock(&g_nxc_mu);
    for (size_t i = 0; i < g_count; i++) {
        if (strcmp(g_tab[i].name, name) == 0) {
            g_tab[i].addr = address;
            mutexUnlock(&g_nxc_mu);
            free(copy);
            return 0;
        }
    }
    if (g_count == g_cap) {
        size_t cap = g_cap ? g_cap * 2 : 16;
        dl_entry* t = (dl_entry*)realloc(g_tab, cap * sizeof *t);
        if (!t) {
            mutexUnlock(&g_nxc_mu);
            free(copy);
            return NXC_FAIL(ENOMEM);
        }
        g_tab = t;
        g_cap = cap;
    }
    g_tab[g_count].name = copy;
    g_tab[g_count].addr = address;
    g_count++;
    mutexUnlock(&g_nxc_mu);
    return 0;
}

static void* opened(const char* file) {
    void* h = NULL;
    mutexLock(&g_nxc_mu);
    for (size_t i = 0; i < g_open_count; i++)
        if (strcmp(g_open[i].file, file) == 0) {
            h = g_open[i].handle;
            break;
        }
    mutexUnlock(&g_nxc_mu);
    return h;
}

static void remember(const char* file, void* handle) {
    if (opened(file)) return;
    char* copy = strdup(file);
    if (!copy) return;
    mutexLock(&g_nxc_mu);
    if (g_open_count == g_open_cap) {
        size_t cap = g_open_cap ? g_open_cap * 2 : 8;
        dl_open* t = (dl_open*)realloc(g_open, cap * sizeof *t);
        if (!t) {
            mutexUnlock(&g_nxc_mu);
            free(copy);
            return;
        }
        g_open = t;
        g_open_cap = cap;
    }
    g_open[g_open_count].file = copy;
    g_open[g_open_count].handle = handle;
    g_open_count++;
    mutexUnlock(&g_nxc_mu);
}

/* mode: RTLD_LAZY / RTLD_NOW / RTLD_GLOBAL / RTLD_LOCAL / RTLD_NODELETE are accepted and change nothing (every
 * library is bound at once, its symbols are found by dlsym(RTLD_DEFAULT) and it stays loaded until the app ends).
 * RTLD_NOLOAD returns the handle of a file this dlopen opened before, NULL otherwise. */
void* dlopen(const char* file, int mode) {
    if (!file || !file[0]) {
        t_err = NULL;
        return MAIN_HANDLE;
    }
    if (mode & RTLD_NOLOAD) {
        void* h = opened(file);
        if (h && nxn_lib_open) {
            nxn_lib* again = NULL;
            if (nxn_lib_open(file, NULL, &again) == 0) { /* one more reference, like dlopen */
                t_err = NULL;
                return again;
            }
        }
        set_err("dlopen", "not loaded (RTLD_NOLOAD)");
        return NULL;
    }
    if (!nxn_lib_open) {
        set_err("dlopen", "loading shared libraries needs libnexvyn_native (link -lnexvyn_native), or link the library statically");
        nxc_unsupported("dlopen", "link libnexvyn_native, or link the library statically");
        return NULL;
    }
    nxn_lib* lib = NULL;
    if (nxn_lib_open(file, NULL, &lib) != 0 || !lib) {
        set_err("dlopen", nxn_lib_error ? nxn_lib_error() : "");
        return NULL;
    }
    remember(file, lib);
    t_err = NULL;
    return lib;
}

void* dlsym(void* handle, const char* name) {
    if (!name) {
        t_err = "dlsym: no symbol name";
        return NULL;
    }
    if (handle == MAIN_HANDLE || handle == RTLD_DEFAULT || handle == RTLD_NEXT) {
        void* found = NULL;
        mutexLock(&g_nxc_mu);
        for (size_t i = 0; i < g_count; i++) {
            if (strcmp(g_tab[i].name, name) == 0) {
                found = g_tab[i].addr;
                break;
            }
        }
        mutexUnlock(&g_nxc_mu);
        /* then the app's own exports and every open library */
        if (!found && nxn_lib_sym) found = nxn_lib_sym(NULL, name);
        if (found) {
            t_err = NULL;
            return found;
        }
        t_err = nxn_lib_sym ? "dlsym: symbol not found (not registered with nxc_dl_register, not exported by the app or an open library)"
                            : "dlsym: symbol not registered (nxc_dl_register)";
        return NULL;
    }
    if (!nxn_lib_sym) {
        t_err = "dlsym: invalid handle";
        return NULL;
    }
    void* p = nxn_lib_sym((nxn_lib*)handle, name);
    if (!p) {
        set_err("dlsym", nxn_lib_error ? nxn_lib_error() : "symbol not found");
        return NULL;
    }
    t_err = NULL;
    return p;
}

int dlclose(void* handle) {
    if (handle == MAIN_HANDLE) return 0;
    if (handle && nxn_lib_close && nxn_lib_close((nxn_lib*)handle) == 0) return 0;
    t_err = "dlclose: invalid handle";
    return -1;
}

char* dlerror(void) {
    const char* e = t_err;
    t_err = NULL;
    return (char*)e;
}

int dladdr(const void* addr, Dl_info* info) {
    if (info) memset(info, 0, sizeof *info);
    return 0;
}
