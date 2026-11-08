/* Nexvyn Native SDK library - shared libraries (nxn_lib.h). The ELF work is the loader core Nexvyn OS uses for its own
 * modules (sdk/native/loader/nxelf.c); this file finds the file, checks its identity, resolves imports against the
 * app's own export table and keeps the list of loaded libraries. */
#include "nxn_internal.h"
#include "nxelf.h"
#include "nxn_lib_id.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

/* The app's dynamic section and first byte (linker symbols of every libnx NRO). */
extern const char _DYNAMIC[] __attribute__((visibility("hidden")));
extern char __start__[] __attribute__((visibility("hidden")));
extern int __system_argc;
extern char** __system_argv;

#define LIB_PATH 768

struct nxn_lib {
    struct nxn_lib* next;
    char path[LIB_PATH];
    nxn__lib_id id;
    int refs;
    nxelf_mem mem;
    nxelf_info info;
};

static struct nxn_lib* g_libs;      /* load order */
static RMutex g_libs_lock;          /* recursive: a library constructor may open another library */
static nxelf_symtab g_host;
static int g_host_state;            /* 0 unread, 1 has a table, -1 exports nothing */
static int g_finis_registered;
static __thread char t_err[512];

static void set_err(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void set_err(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(t_err, sizeof t_err, fmt, ap);
    va_end(ap);
}

const char* nxn_lib_error(void) { return t_err; }

static const nxelf_symtab* host_table(void) {
    if (!g_host_state) g_host_state = nxelf_symtab_of(_DYNAMIC, (uintptr_t)__start__, &g_host) ? 1 : -1;
    return g_host_state > 0 ? &g_host : NULL;
}

static int host_lookup(void* ctx, const char* name, uint64_t* addr) {
    (void)ctx;
    const nxelf_symtab* t = host_table();
    uintptr_t a = 0;
    if (!t || !nxelf_symtab_find(t, name, &a)) return 0;
    *addr = (uint64_t)a;
    return 1;
}

/* ---------------------------------------------------------------- finding the file */
static int is_file(const char* p) {
    struct stat st;
    return stat(p, &st) == 0 && S_ISREG(st.st_mode);
}

static void parent_dir(const char* path, char* out, size_t n) {
    snprintf(out, n, "%s", path);
    char* slash = strrchr(out, '/');
    if (slash) *slash = 0;
    else out[0] = 0;
}

/* File names a bare name or a file name may stand for: itself when it ends in .nxvlib, else <stem>.nxvlib and, for
 * "libX", X.nxvlib (a ".so" or ".so.N" suffix is dropped first). */
static int file_names(const char* name, char out[2][256]) {
    size_t len = strlen(name);
    if (len >= 7 && strcmp(name + len - 7, ".nxvlib") == 0) {
        snprintf(out[0], 256, "%s", name);
        return 1;
    }
    char stem[256];
    snprintf(stem, sizeof stem, "%s", name);
    char* so = strstr(stem, ".so");
    if (so && (so[3] == 0 || so[3] == '.')) *so = 0;
    snprintf(out[0], 256, "%s.nxvlib", stem);
    if (strncmp(stem, "lib", 3) == 0 && stem[3]) {
        snprintf(out[1], 256, "%s.nxvlib", stem + 3);
        return 2;
    }
    return 1;
}

/* The search folders for a bare name: next to the app's .nro, its bundle folder, <data>/lib. */
static int search_dirs(char dirs[3][LIB_PATH]) {
    int n = 0;
    const char* argv0 = __system_argc > 0 && __system_argv && __system_argv[0] ? __system_argv[0] : "";
    if (argv0[0]) {
        char full[LIB_PATH];
        if (strncmp(argv0, "sdmc:", 5) == 0) snprintf(full, sizeof full, "%s", argv0);
        else snprintf(full, sizeof full, "sdmc:%s", argv0);
        parent_dir(full, dirs[n], LIB_PATH);
        if (dirs[n][0]) n++;
    }
    if (g_nxn.inited && g_nxn.bundle[0] && (n == 0 || strcmp(dirs[0], g_nxn.bundle) != 0))
        snprintf(dirs[n++], LIB_PATH, "%s", g_nxn.bundle);
    if (g_nxn.inited && g_nxn.data[0]) snprintf(dirs[n++], LIB_PATH, "%s/lib", g_nxn.data);
    return n;
}

static int find_file(const char* name, char* path, size_t n) {
    char names[2][256];
    int count;
    if (strchr(name, '/') || strchr(name, ':')) { /* a path: as given, then the .nxvlib names in its folder */
        if (is_file(name)) {
            snprintf(path, n, "%s", name);
            return 1;
        }
        char dir[LIB_PATH];
        parent_dir(name, dir, sizeof dir);
        const char* base = strrchr(name, '/');
        base = base ? base + 1 : name;
        count = file_names(base, names);
        for (int i = 0; i < count; i++) {
            snprintf(path, n, "%s/%s", dir, names[i]);
            if (is_file(path)) return 1;
        }
        return 0;
    }
    char dirs[3][LIB_PATH];
    int nd = search_dirs(dirs);
    count = file_names(name, names);
    for (int d = 0; d < nd; d++)
        for (int i = 0; i < count; i++) {
            snprintf(path, n, "%s/%s", dirs[d], names[i]);
            if (is_file(path)) return 1;
        }
    return 0;
}

static unsigned char* read_file(const char* path, size_t* size) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char* buf = NULL;
    long len = -1;
    if (fseek(f, 0, SEEK_END) == 0) len = ftell(f);
    if (len > 0 && fseek(f, 0, SEEK_SET) == 0) buf = (unsigned char*)malloc((size_t)len);
    if (buf && fread(buf, 1, (size_t)len, f) != (size_t)len) {
        free(buf);
        buf = NULL;
    }
    fclose(f);
    *size = buf ? (size_t)len : 0;
    return buf;
}

/* ---------------------------------------------------------------- loaded libraries */
static void run_finis(void) {
    /* reverse load order; a library's own atexit handlers ran before (they were registered later) */
    struct nxn_lib* order[256];
    int n = 0;
    for (struct nxn_lib* l = g_libs; l && n < 256; l = l->next) order[n++] = l;
    for (int i = n - 1; i >= 0; i--) {
        nxelf_info* in = &order[i]->info;
        for (size_t k = in->fini_count; k > 0; k--) ((void (*)(void))((uintptr_t*)in->fini_array)[k - 1])();
        if (in->fini) ((void (*)(void))in->fini)();
    }
}

static nxn_result check_version(const nxn__lib_id* id, const char* min_version) {
    if (!min_version || !min_version[0]) return NXN_OK;
    nxn__semver want;
    if (!nxn__semver_parse(min_version, &want)) {
        set_err("%s: bad minimum version \"%s\"", id->name, min_version);
        return NXN_ERR_INVALID;
    }
    if (id->ver.major != want.major) {
        set_err("%s: version %s is installed, this app needs %u.x (at least %s)", id->name, id->version, want.major,
                min_version);
        return NXN_ERR_UNSUPPORTED;
    }
    if (nxn__semver_cmp(&id->ver, &want) < 0) {
        set_err("%s: version %s is too old, this app needs at least %s", id->name, id->version, min_version);
        return NXN_ERR_UNSUPPORTED;
    }
    return NXN_OK;
}

static nxn_result code_of(int rc) {
    switch (rc) {
        case NXELF_E_TLS:
        case NXELF_E_SYMBOL:
        case NXELF_E_NOJIT: return NXN_ERR_UNSUPPORTED;
        case NXELF_E_MEMORY: return NXN_ERR_NO_MEMORY;
        case NXELF_E_MAP: return NXN_ERR_SYSTEM;
        default: return NXN_ERR_INVALID;
    }
}

/* Loads the file at path (the lock is held). */
static nxn_result load(const char* path, const char* min_version, struct nxn_lib** out) {
    const char* shown = strrchr(path, '/') ? strrchr(path, '/') + 1 : path;
    size_t size = 0;
    unsigned char* img = read_file(path, &size);
    if (!img) {
        set_err("%s: cannot read the file", shown);
        return NXN_ERR_IO;
    }
    nxn__lib_id id;
    int idrc = nxn__lib_id_read(img, size, &id);
    if (idrc != 0) {
        free(img);
        if (idrc == 1) set_err("%s: not a Nexvyn library (no .nxvlib identity; build it with nxv-native lib)", shown);
        else set_err("%s: unreadable .nxvlib identity", shown);
        return NXN_ERR_INVALID;
    }
    if (strcmp(id.abi, NXN_LIB_ABI_GEN) != 0) {
        free(img);
        set_err("%s: built for library ABI generation %s, this app has %s (rebuild it with the current SDK)", id.name,
                id.abi, NXN_LIB_ABI_GEN);
        return NXN_ERR_UNSUPPORTED;
    }
    nxn_result vr = check_version(&id, min_version);
    if (vr != NXN_OK) {
        free(img);
        return vr;
    }
    char why[400] = "";
    nxelf_layout layout;
    int rc = nxelf_layout_of(img, size, "library", &layout, why, sizeof why);
    struct nxn_lib* lib = NULL;
    if (rc == NXELF_OK) {
        lib = (struct nxn_lib*)calloc(1, sizeof *lib);
        if (!lib) {
            free(img);
            set_err("%s: out of memory", id.name);
            return NXN_ERR_NO_MEMORY;
        }
        rc = nxelf_map_jit(&lib->mem, &layout, why, sizeof why);
        if (rc == NXELF_E_NOJIT)
            snprintf(why, sizeof why, "JIT code memory is not available: start Nexvyn OS through Atmosph\xc3\xa8re's homebrew "
                                      "loader (hold R while launching a game), not from the album applet");
    }
    if (rc == NXELF_OK) rc = nxelf_link(img, size, &lib->mem, host_lookup, NULL, &lib->info, why, sizeof why);
    free(img);
    if (rc != NXELF_OK) {
        if (lib) {
            nxelf_unmap_jit(&lib->mem);
            free(lib);
        }
        if (rc == NXELF_E_SYMBOL && !host_table())
            set_err("%s: %s (the app exports no symbols: link it with nexvyn_export_symbols())", id.name, why);
        else if (rc == NXELF_E_SYMBOL)
            set_err("%s: %s (the app does not export it: list the library in nexvyn_export_symbols())", id.name, why);
        else
            set_err("%s: %s", id.name, why);
        return code_of(rc);
    }
    snprintf(lib->path, sizeof lib->path, "%s", path);
    lib->id = id;
    lib->refs = 1;
    /* append (load order) before the constructors: a constructor may look its own library up */
    struct nxn_lib** tail = &g_libs;
    while (*tail) tail = &(*tail)->next;
    *tail = lib;
    if (!g_finis_registered) {
        g_finis_registered = 1;
        atexit(run_finis);
    }
    if (lib->info.init) ((void (*)(void))lib->info.init)();
    for (size_t i = 0; i < lib->info.init_count; i++) ((void (*)(void))((uintptr_t*)lib->info.init_array)[i])();
    nxn_log(NXN_LOG_INFO, "loaded library %s %s from %s at %p", id.name, id.version, path, (void*)lib->mem.base);
    *out = lib;
    return NXN_OK;
}

nxn_result nxn_lib_open(const char* name, const char* min_version, nxn_lib** out) {
    if (out) *out = NULL;
    if (!name || !name[0] || !out) {
        set_err("nxn_lib_open: no library name");
        return NXN_ERR_INVALID;
    }
    char path[LIB_PATH];
    if (!find_file(name, path, sizeof path)) {
        set_err("%s: not found (as a path, next to the app and in its data folder's lib folder)", name);
        return NXN_ERR_NOT_FOUND;
    }
    nxn_result r;
    rmutexLock(&g_libs_lock);
    struct nxn_lib* lib = g_libs;
    while (lib && strcmp(lib->path, path) != 0) lib = lib->next;
    if (lib) {
        r = check_version(&lib->id, min_version);
        if (r == NXN_OK) {
            lib->refs++;
            *out = lib;
        }
    } else {
        r = load(path, min_version, &lib);
        if (r == NXN_OK) *out = lib;
    }
    rmutexUnlock(&g_libs_lock);
    if (r == NXN_OK) t_err[0] = 0;
    return r;
}

void* nxn_lib_sym(nxn_lib* lib, const char* name) {
    if (!name || !name[0]) {
        set_err("nxn_lib_sym: no symbol name");
        return NULL;
    }
    uintptr_t a = 0;
    if (lib) {
        /* only handles of this list are read (dlsym passes whatever the port hands it) */
        rmutexLock(&g_libs_lock);
        struct nxn_lib* l = g_libs;
        while (l && l != lib) l = l->next;
        rmutexUnlock(&g_libs_lock);
        if (!l) {
            set_err("nxn_lib_sym: not an open library");
            return NULL;
        }
        if (nxelf_symtab_find(&lib->info.symtab, name, &a)) return (void*)a;
        set_err("%s: no symbol %s", lib->id.name, name);
        return NULL;
    }
    const nxelf_symtab* host = host_table();
    if (host && nxelf_symtab_find(host, name, &a)) return (void*)a;
    rmutexLock(&g_libs_lock);
    for (struct nxn_lib* l = g_libs; l; l = l->next)
        if (nxelf_symtab_find(&l->info.symtab, name, &a)) break;
    rmutexUnlock(&g_libs_lock);
    if (a) return (void*)a;
    set_err("no symbol %s in the app or its libraries", name);
    return NULL;
}

nxn_result nxn_lib_close(nxn_lib* lib) {
    if (!lib) return NXN_ERR_INVALID;
    nxn_result r = NXN_ERR_INVALID;
    rmutexLock(&g_libs_lock);
    for (struct nxn_lib* l = g_libs; l; l = l->next)
        if (l == lib) {
            if (l->refs > 0) {
                l->refs--;
                r = NXN_OK;
            }
            break;
        }
    rmutexUnlock(&g_libs_lock);
    if (r != NXN_OK) set_err("nxn_lib_close: not an open library");
    return r;
}

int nxn__libs_ranges(uint64_t* pairs, int max_pairs) {
    int n = 0;
    for (struct nxn_lib* l = g_libs; l; l = l->next) {
        const nxelf_mem* m = &l->mem;
        if (m->ro_src && n < max_pairs) {
            pairs[2 * n] = (uint64_t)(uintptr_t)m->ro_src;
            pairs[2 * n++ + 1] = (uint64_t)(uintptr_t)m->ro_src + m->ro_size;
        }
        if (m->rw_src && n < max_pairs) {
            pairs[2 * n] = (uint64_t)(uintptr_t)m->rw_src;
            pairs[2 * n++ + 1] = (uint64_t)(uintptr_t)m->rw_src + m->rw_size;
        }
    }
    return n;
}

/* No lock: it runs once at the very end (userAppExit), possibly after a crash; nothing calls into a library after it. */
int nxn__libs_release(int may_free) {
    int n = 0;
    for (struct nxn_lib* l = g_libs; l; l = l->next) {
        nxelf_mem* m = &l->mem;
        if (!m->ro_handle && !m->rw_handle) continue;
        if (!may_free) m->ro_src = m->rw_src = NULL; /* unmapped and unlocked, but not handed back to malloc */
        nxelf_unmap_jit(m);
        n++;
    }
    return n;
}

const char* nxn_lib_version(nxn_lib* lib) { return lib ? lib->id.version : ""; }
const char* nxn_lib_name(nxn_lib* lib) { return lib ? lib->id.name : ""; }

