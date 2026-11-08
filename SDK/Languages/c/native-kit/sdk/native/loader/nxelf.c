/* Nexvyn ELF loader core (format, steps and rules: nxelf.h). Compiled as C by Nexvyn OS and libnexvyn_native and as
 * C++ by the desktop tests, so it uses only the common subset of both languages. */
#include "nxelf.h"

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __SWITCH__
#include <switch.h>
#endif

/* ---------------------------------------------------------------- ELF64 (only what the loader reads) */
typedef struct Ehdr {
    uint8_t ident[16];
    uint16_t type, machine;
    uint32_t version;
    uint64_t entry, phoff, shoff;
    uint32_t flags;
    uint16_t ehsize, phentsize, phnum, shentsize, shnum, shstrndx;
} Ehdr;
typedef struct Phdr {
    uint32_t type, flags;
    uint64_t offset, vaddr, paddr, filesz, memsz, align;
} Phdr;
typedef struct Shdr {
    uint32_t name, type;
    uint64_t flags, addr, offset, size;
    uint32_t link, info;
    uint64_t addralign, entsize;
} Shdr;
typedef struct Dyn {
    int64_t tag;
    uint64_t val;
} Dyn;
typedef struct Sym {
    uint32_t name;
    uint8_t info, other;
    uint16_t shndx;
    uint64_t value, size;
} Sym;
typedef struct Rela {
    uint64_t offset, info;
    int64_t addend;
} Rela;

#define PT_LOAD 1u
#define PT_DYNAMIC 2u
#define PT_TLS 7u
#define PF_W 2u
#define DT_NULL 0
#define DT_PLTRELSZ 2
#define DT_HASH 4
#define DT_STRTAB 5
#define DT_SYMTAB 6
#define DT_RELA 7
#define DT_RELASZ 8
#define DT_INIT 12
#define DT_FINI 13
#define DT_TEXTREL 22
#define DT_JMPREL 23
#define DT_INIT_ARRAY 25
#define DT_FINI_ARRAY 26
#define DT_INIT_ARRAYSZ 27
#define DT_FINI_ARRAYSZ 28
#define DT_FLAGS 30
#define DT_RELRSZ 35
#define DT_RELR 36
#define R_AARCH64_NONE 0u
#define R_AARCH64_ABS64 257u
#define R_AARCH64_GLOB_DAT 1025u
#define R_AARCH64_JUMP_SLOT 1026u
#define R_AARCH64_RELATIVE 1027u
#define R_AARCH64_TLS_DTPMOD64 1028u
#define R_AARCH64_TLS_DTPREL64 1029u
#define R_AARCH64_TLS_TPREL64 1030u
#define R_AARCH64_TLSDESC 1031u
#define SHN_UNDEF 0
#define SHN_ABS 0xfff1
#define DF_TEXTREL 4u

static uint64_t page_up(uint64_t v) { return (v + NXELF_PAGE - 1) & ~(uint64_t)(NXELF_PAGE - 1); }
static uint64_t page_down(uint64_t v) { return v & ~(uint64_t)(NXELF_PAGE - 1); }
static uint8_t sym_bind(const Sym* s) { return (uint8_t)(s->info >> 4); }

static int fail(int code, char* err, size_t errsz, const char* fmt, ...) {
    if (err && errsz) {
        va_list ap;
        va_start(ap, fmt);
        vsnprintf(err, errsz, fmt, ap);
        va_end(ap);
    }
    return code;
}

int nxelf_exportable(uint8_t info, uint16_t shndx, const char* name) {
    uint8_t b = (uint8_t)(info >> 4), t = (uint8_t)(info & 15);
    return name && *name && shndx != SHN_UNDEF && shndx != SHN_ABS && (b == 1 || b == 2 || b == 10) &&
           t != 3 /* SECTION */ && t != 4 /* FILE */ && t != 6 /* TLS */;
}

/* ---------------------------------------------------------------- layout */
int nxelf_layout_of(const uint8_t* img, size_t size, const char* kind, nxelf_layout* out, char* err, size_t errsz) {
    return nxelf_layout_ex(img, size, kind, 0, out, err, errsz);
}

int nxelf_layout_ex(const uint8_t* img, size_t size, const char* kind, unsigned flags, nxelf_layout* out, char* err,
                    size_t errsz) {
    if (!kind) kind = "module";
    memset(out, 0, sizeof *out);
    if (!img || size < sizeof(Ehdr)) return fail(NXELF_E_FORMAT, err, errsz, "not a %s", kind);
    const Ehdr* eh = (const Ehdr*)img;
    if (memcmp(eh->ident, "\x7f" "ELF", 4) != 0 || eh->ident[4] != 2 || eh->ident[5] != 1 || eh->machine != 183 ||
        eh->type != 3)
        return fail(NXELF_E_FORMAT, err, errsz, "not an AArch64 shared object");
    if (eh->phentsize != sizeof(Phdr) || eh->phoff + (uint64_t)eh->phnum * sizeof(Phdr) > size)
        return fail(NXELF_E_FORMAT, err, errsz, "bad program headers");
    const Phdr* ph = (const Phdr*)(img + eh->phoff);
    uint64_t ro_end = 0, rw_start = UINT64_MAX, rw_end = 0, dyn = 0;
    for (int i = 0; i < eh->phnum; i++) {
        const Phdr* p = &ph[i];
        if (p->type == PT_TLS && !(flags & NXELF_F_TLS))
            return fail(NXELF_E_TLS, err, errsz, "thread_local variables are not supported in %s",
                        strcmp(kind, "library") == 0 ? "libraries" : "modules");
        if (p->type == PT_TLS) {
            /* one TLS segment, its image inside the file, a sane alignment (a power of two up to a page) */
            uint64_t al = p->align ? p->align : 1;
            if (out->tls_memsz || p->filesz > p->memsz || p->offset + p->filesz > size || (al & (al - 1)) || al > NXELF_PAGE ||
                p->memsz > (64u << 20))
                return fail(NXELF_E_FORMAT, err, errsz, "bad thread_local segment");
            out->tls_vaddr = p->vaddr;
            out->tls_filesz = p->filesz;
            out->tls_memsz = p->memsz ? p->memsz : 1;
            out->tls_align = al;
            continue;
        }
        if (p->type == PT_DYNAMIC) dyn = p->vaddr;
        if (p->type != PT_LOAD) continue;
        if (p->offset + p->filesz > size || p->filesz > p->memsz) return fail(NXELF_E_FORMAT, err, errsz, "truncated segment");
        if (p->flags & PF_W) {
            if (page_down(p->vaddr) < rw_start) rw_start = page_down(p->vaddr);
            if (page_up(p->vaddr + p->memsz) > rw_end) rw_end = page_up(p->vaddr + p->memsz);
        } else {
            if (page_up(p->vaddr + p->memsz) > ro_end) ro_end = page_up(p->vaddr + p->memsz);
        }
    }
    if (!ro_end || rw_start == UINT64_MAX || rw_start < ro_end || !dyn)
        return fail(NXELF_E_FORMAT, err, errsz, "unexpected segment layout");
    out->ro_size = ro_end;
    out->rw_start = rw_start;
    out->rw_size = rw_end - rw_start;
    out->dyn = dyn;
    return NXELF_OK;
}

/* ---------------------------------------------------------------- linking */
typedef struct link_ctx {
    const nxelf_mem* m;
    const Sym* syms;
    const char* strs;
    uint32_t nsyms;
    nxelf_lookup_fn lookup;
    void* ctx;
    const char* missing;
    char* err;
    size_t errsz;
    unsigned tls_relocs;  /* DTPMOD64 relocations applied */
} link_ctx;

static int in_data(const nxelf_mem* m, uint64_t off, uint64_t n) {
    return off >= m->rw_start && off + n <= m->rw_start + m->rw_size;
}
static int in_image(const nxelf_mem* m, uint64_t off, uint64_t n) {
    return off + n <= m->rw_start + m->rw_size && (off + n <= m->ro_size || off >= m->rw_start);
}

/* S of a relocation: the host's export first (one copy of every shared function and static), then the object's own */
static int resolve(link_ctx* c, uint32_t idx, uint64_t* out) {
    if (idx == 0 || idx >= c->nsyms) {
        *out = 0;
        return idx == 0;
    }
    const Sym* s = &c->syms[idx];
    const char* name = c->strs + s->name;
    if (sym_bind(s) != 0 && *name && c->lookup && c->lookup(c->ctx, name, out)) return 1;
    if (s->shndx == SHN_ABS) *out = s->value;
    else if (s->shndx != SHN_UNDEF) *out = (uint64_t)(uintptr_t)c->m->base + s->value;
    else if (sym_bind(s) == 2) *out = 0;  /* weak and nowhere: null */
    else {
        if (!c->missing) c->missing = name;
        return 0;
    }
    return 1;
}

static int apply_rela(link_ctx* c, uint64_t at, uint64_t bytes) {
    const nxelf_mem* m = c->m;
    if (!bytes) return NXELF_OK;
    if (!in_image(m, at, bytes)) return fail(NXELF_E_FORMAT, c->err, c->errsz, "bad relocation table");
    const Rela* r = (const Rela*)(m->base + at);
    for (size_t i = 0; i < bytes / sizeof(Rela); i++) {
        uint32_t type = (uint32_t)r[i].info, sym = (uint32_t)(r[i].info >> 32);
        if (type == R_AARCH64_NONE) continue;
        if (!in_data(m, r[i].offset, 8)) return fail(NXELF_E_FORMAT, c->err, c->errsz, "relocation outside the data segment");
        uint64_t* p = (uint64_t*)(m->base + r[i].offset);
        uint64_t s = 0;
        switch (type) {
            case R_AARCH64_RELATIVE: *p = (uint64_t)(uintptr_t)m->base + r[i].addend; break;
            case R_AARCH64_GLOB_DAT:
            case R_AARCH64_JUMP_SLOT:
            case R_AARCH64_ABS64:
                if (!resolve(c, sym, &s)) return fail(NXELF_E_SYMBOL, c->err, c->errsz, "missing symbol %s", c->missing);
                *p = s + r[i].addend;
                break;
            case R_AARCH64_TLS_DTPMOD64:
            case R_AARCH64_TLS_DTPREL64: {
                /* general-dynamic thread_local (-mtls-dialect=trad): a tls_index {module, offset} for __tls_get_addr.
                 * Only the object's own variables: a thread_local of another object is not offered. */
                if (!m->tls_module) /* TLS not offered by the caller: the answer of the 1.0 loader */
                    return fail(NXELF_E_RELOC, c->err, c->errsz, "unsupported relocation type %u", type);
                uint64_t off = 0;
                if (sym) {
                    const Sym* ts = sym < c->nsyms ? &c->syms[sym] : NULL;
                    if (!ts || ts->shndx == SHN_UNDEF)
                        return fail(NXELF_E_TLS, c->err, c->errsz, "thread_local %s of another object (not supported)",
                                    ts ? c->strs + ts->name : "?");
                    off = ts->value;
                }
                if (type == R_AARCH64_TLS_DTPMOD64) {
                    *p = m->tls_module;
                    c->tls_relocs++;
                } else {
                    *p = off + (uint64_t)r[i].addend;
                }
                break;
            }
            case R_AARCH64_TLS_TPREL64:
            case R_AARCH64_TLSDESC:
                if (!m->tls_module) return fail(NXELF_E_RELOC, c->err, c->errsz, "unsupported relocation type %u", type);
                return fail(NXELF_E_TLS, c->err, c->errsz,
                            "thread_local code built for another TLS model: compile every object with -mtls-dialect=trad "
                            "(the Nexvyn native kit does)");
            default: return fail(NXELF_E_RELOC, c->err, c->errsz, "unsupported relocation type %u", type);
        }
    }
    return NXELF_OK;
}

int nxelf_link(const uint8_t* img, size_t size, const nxelf_mem* m, nxelf_lookup_fn lookup, void* ctx, nxelf_info* info,
               char* err, size_t errsz) {
    if (!img || size < sizeof(Ehdr) || !m || !m->base || !m->ro_copy || !info)
        return fail(NXELF_E_FORMAT, err, errsz, "not loaded");
    memset(info, 0, sizeof *info);
    const Ehdr* eh = (const Ehdr*)img;
    const Phdr* ph = (const Phdr*)(img + eh->phoff);
    uint64_t dyn_addr = 0;

    /* Code memory comes back filled with 0xFF, not with what the source pages held. Everything not copied from the
     * file must be cleared here: .bss above all (an 0xFF guard byte reads "already constructed", so function statics
     * were never built and their mutexes and strings held 0xFF..., the 1.0.0 crash), then the gaps between segments. */
    memset(m->ro_copy, 0, m->ro_size);
    memset(m->base + m->rw_start, 0, m->rw_size);
    /* copy the segments (writable ones straight to their place, code through its RW view) */
    for (int i = 0; i < eh->phnum; i++) {
        const Phdr* p = &ph[i];
        if (p->type == PT_DYNAMIC) dyn_addr = p->vaddr;
        if (p->type != PT_LOAD) continue;
        uint8_t* dst = (p->flags & PF_W) ? m->base + p->vaddr : m->ro_copy + p->vaddr;
        memcpy(dst, img + p->offset, p->filesz);
    }
    uint8_t* base = m->base;

    /* dynamic section: tables are read through the RX view (readable), only the data segment is written */
    if (!in_data(m, dyn_addr, sizeof(Dyn))) return fail(NXELF_E_FORMAT, err, errsz, "bad dynamic section");
    uint64_t symtab = 0, strtab = 0, hash = 0, rela = 0, rela_sz = 0, jmprel = 0, plt_sz = 0, relr = 0, relr_sz = 0;
    uint64_t init = 0, init_arr = 0, init_sz = 0, fini = 0, fini_arr = 0, fini_sz = 0;
    for (const Dyn* d = (const Dyn*)(base + dyn_addr); in_data(m, (uint64_t)((const uint8_t*)d - base), sizeof(Dyn)) && d->tag != DT_NULL;
         d++) {
        switch (d->tag) {
            case DT_SYMTAB: symtab = d->val; break;
            case DT_STRTAB: strtab = d->val; break;
            case DT_HASH: hash = d->val; break;
            case DT_RELA: rela = d->val; break;
            case DT_RELASZ: rela_sz = d->val; break;
            case DT_JMPREL: jmprel = d->val; break;
            case DT_PLTRELSZ: plt_sz = d->val; break;
            case DT_RELR: relr = d->val; break;
            case DT_RELRSZ: relr_sz = d->val; break;
            case DT_INIT: init = d->val; break;
            case DT_INIT_ARRAY: init_arr = d->val; break;
            case DT_INIT_ARRAYSZ: init_sz = d->val; break;
            case DT_FINI: fini = d->val; break;
            case DT_FINI_ARRAY: fini_arr = d->val; break;
            case DT_FINI_ARRAYSZ: fini_sz = d->val; break;
            case DT_TEXTREL: return fail(NXELF_E_TEXTREL, err, errsz, "text relocations (build with -fPIC)");
            case DT_FLAGS:
                if (d->val & DF_TEXTREL) return fail(NXELF_E_TEXTREL, err, errsz, "text relocations (build with -fPIC)");
                break;
        }
    }
    if (!symtab || !strtab || !hash || !in_image(m, hash, 8)) return fail(NXELF_E_FORMAT, err, errsz, "no dynamic symbol table");
    uint32_t nsyms = ((const uint32_t*)(base + hash))[1];
    if (!in_image(m, symtab, (uint64_t)nsyms * sizeof(Sym))) return fail(NXELF_E_FORMAT, err, errsz, "bad symbol table");

    link_ctx c;
    memset(&c, 0, sizeof c);
    c.m = m;
    c.syms = (const Sym*)(base + symtab);
    c.strs = (const char*)(base + strtab);
    c.nsyms = nsyms;
    c.lookup = lookup;
    c.ctx = ctx;
    c.err = err;
    c.errsz = errsz;
    int rc = apply_rela(&c, rela, rela_sz);
    if (rc == NXELF_OK) rc = apply_rela(&c, jmprel, plt_sz);
    if (rc != NXELF_OK) return rc;
    /* thread_local data but no tls_index: devkitA64's gcc with -mtp=soft miscompiles the default TLSDESC dialect into
     * code that reads a wrong address without leaving a relocation, so such an object is refused, not run */
    for (int i = 0; i < eh->phnum; i++)
        if (m->tls_module && ph[i].type == PT_TLS && ph[i].memsz && !c.tls_relocs)
            return fail(NXELF_E_TLS, err, errsz,
                        "thread_local code built for another TLS model: compile every object with -mtls-dialect=trad "
                        "(the Nexvyn native kit does)");
    if (relr_sz) { /* packed relative relocations: an address, then bitmaps of the following words */
        if (!in_image(m, relr, relr_sz)) return fail(NXELF_E_FORMAT, err, errsz, "bad RELR table");
        const uint64_t* e = (const uint64_t*)(base + relr);
        uint64_t where = 0;
        for (size_t i = 0; i < relr_sz / 8; i++) {
            if (!(e[i] & 1)) {
                if (!in_data(m, e[i], 8)) return fail(NXELF_E_FORMAT, err, errsz, "relocation outside the data segment");
                *(uint64_t*)(base + e[i]) += (uint64_t)(uintptr_t)base;
                where = e[i] + 8;
            } else {
                uint64_t bits = e[i] >> 1;
                for (int b = 0; bits; b++, bits >>= 1)
                    if (bits & 1) {
                        if (!in_data(m, where + (uint64_t)b * 8, 8))
                            return fail(NXELF_E_FORMAT, err, errsz, "relocation outside the data segment");
                        *(uint64_t*)(base + where + (uint64_t)b * 8) += (uint64_t)(uintptr_t)base;
                    }
                where += 63 * 8;
            }
        }
    }
#ifdef __SWITCH__
    armDCacheFlush(m->ro_copy, m->ro_size);
    armICacheInvalidate(m->base, m->ro_size);
#endif

    if (init_sz && !in_data(m, init_arr, init_sz)) return fail(NXELF_E_FORMAT, err, errsz, "bad .init_array");
    if (fini_sz && !in_data(m, fini_arr, fini_sz)) return fail(NXELF_E_FORMAT, err, errsz, "bad .fini_array");
    info->symtab.syms = c.syms;
    info->symtab.strs = c.strs;
    info->symtab.hash = (const uint32_t*)(base + hash);
    info->symtab.nsyms = nsyms;
    info->symtab.base = (uintptr_t)base;
    info->init = init ? (uintptr_t)(base + init) : 0;
    info->init_array = (uintptr_t)(base + init_arr);
    info->init_count = init_sz / 8;
    info->fini = fini ? (uintptr_t)(base + fini) : 0;
    info->fini_array = (uintptr_t)(base + fini_arr);
    info->fini_count = fini_sz / 8;
    return NXELF_OK;
}

/* ---------------------------------------------------------------- sections */
int nxelf_section(const uint8_t* img, size_t size, const char* name, uint64_t* offset, uint64_t* bytes) {
    if (!img || size < sizeof(Ehdr) || !name) return 0;
    const Ehdr* eh = (const Ehdr*)img;
    if (!eh->shoff || eh->shentsize != sizeof(Shdr) || eh->shoff + (uint64_t)eh->shnum * sizeof(Shdr) > size ||
        eh->shstrndx >= eh->shnum)
        return 0;
    const Shdr* sh = (const Shdr*)(img + eh->shoff);
    const Shdr* names = &sh[eh->shstrndx];
    if (names->offset + names->size > size) return 0;
    size_t want = strlen(name);
    for (int i = 0; i < eh->shnum; i++) {
        if (sh[i].name >= names->size || sh[i].offset + sh[i].size > size) continue;
        const char* n = (const char*)img + names->offset + sh[i].name;
        /* the name must end inside the string table */
        if (names->size - sh[i].name <= want) continue;
        if (memcmp(n, name, want + 1) == 0) {
            if (offset) *offset = sh[i].offset;
            if (bytes) *bytes = sh[i].size;
            return 1;
        }
    }
    return 0;
}

int nxelf_section_addr(const uint8_t* img, size_t size, const char* name, uint64_t* addr, uint64_t* bytes) {
    uint64_t off = 0, n = 0;
    if (!nxelf_section(img, size, name, &off, &n)) return 0;
    const Ehdr* eh = (const Ehdr*)img;
    const Shdr* sh = (const Shdr*)(img + eh->shoff);
    for (int i = 0; i < eh->shnum; i++)
        if (sh[i].offset == off && sh[i].size == n && sh[i].type != 8 /* NOBITS */) {
            if (addr) *addr = sh[i].addr;
            if (bytes) *bytes = n;
            return 1;
        }
    return 0;
}

/* ---------------------------------------------------------------- symbol tables */
int nxelf_symtab_of(const void* dynamic, uintptr_t base, nxelf_symtab* out) {
    memset(out, 0, sizeof *out);
    if (!dynamic) return 0;
    const Sym* syms = NULL;
    const char* strs = NULL;
    const uint32_t* hash = NULL;
    for (const Dyn* d = (const Dyn*)dynamic; d->tag != DT_NULL; d++) {
        uintptr_t at = (uintptr_t)d->val < base ? base + (uintptr_t)d->val : (uintptr_t)d->val; /* link-time addresses */
        if (d->tag == DT_SYMTAB) syms = (const Sym*)at;
        else if (d->tag == DT_STRTAB) strs = (const char*)at;
        else if (d->tag == DT_HASH) hash = (const uint32_t*)at;
    }
    if (!syms || !strs || !hash) return 0;
    out->syms = syms;
    out->strs = strs;
    out->hash = hash;
    out->nsyms = hash[1]; /* nchain = number of symbols */
    out->base = base;
    return 1;
}

void nxelf_symtab_each(const nxelf_symtab* t, void (*fn)(void* ctx, const char* name, uintptr_t addr), void* ctx) {
    if (!t || !t->syms || !fn) return;
    const Sym* syms = (const Sym*)t->syms;
    for (uint32_t i = 1; i < t->nsyms; i++) {
        const Sym* s = &syms[i];
        const char* n = t->strs + s->name;
        if (!nxelf_exportable(s->info, s->shndx, n)) continue;
        fn(ctx, n, t->base + (uintptr_t)s->value);
    }
}

static uint32_t sysv_hash(const char* s) {
    uint32_t h = 0, g;
    while (*s) {
        h = (h << 4) + (uint8_t)*s++;
        g = h & 0xf0000000u;
        if (g) h ^= g >> 24;
        h &= ~g;
    }
    return h;
}

int nxelf_symtab_find(const nxelf_symtab* t, const char* name, uintptr_t* addr) {
    if (!t || !t->syms || !t->hash || !name || !*name) return 0;
    uint32_t nbucket = t->hash[0], nchain = t->hash[1];
    if (!nbucket) return 0;
    const uint32_t* bucket = t->hash + 2;
    const uint32_t* chain = bucket + nbucket;
    const Sym* syms = (const Sym*)t->syms;
    uint32_t steps = 0;
    for (uint32_t i = bucket[sysv_hash(name) % nbucket]; i && i < nchain && steps <= nchain; i = chain[i], steps++) {
        const Sym* s = &syms[i];
        const char* n = t->strs + s->name;
        if (strcmp(n, name) == 0 && nxelf_exportable(s->info, s->shndx, n)) {
            if (addr) *addr = t->base + (uintptr_t)s->value;
            return 1;
        }
    }
    return 0;
}

/* ---------------------------------------------------------------- JIT code memory (console) */
#ifdef __SWITCH__
int nxelf_jit_available(void) { return envIsSyscallHinted(0x4B) && envIsSyscallHinted(0x4C); }

/* Code memory objects (KCodeMemory) are a kernel object kind with a small fixed count for the WHOLE system (the slab
 * of the console's kernel: 10). svcCreateCodeMemory answers 0xCE01 (ResultOutOfResource) when none is left, whatever
 * the free RAM; an emulator has no such limit. Every object this program makes or closes is counted here (the loader's
 * own, and those its callers note with nxelf_cm_note: C apps, JIT buffers), so a log can show what is held. */
static int g_cm_live;          /* objects held right now */
static int g_cm_peak;          /* most held at once */
static int g_cm_unmap_failed;  /* views the kernel refused to unmap: their source pages were never handed back */
static int g_cm_test_limit;    /* test only: refuse a new object at this many held (0 = off) */

void nxelf_cm_note(int delta) {
    int now = __atomic_add_fetch(&g_cm_live, delta, __ATOMIC_RELAXED);
    if (now > __atomic_load_n(&g_cm_peak, __ATOMIC_RELAXED)) __atomic_store_n(&g_cm_peak, now, __ATOMIC_RELAXED);
}
int nxelf_cm_count(void) { return __atomic_load_n(&g_cm_live, __ATOMIC_RELAXED); }
void nxelf_cm_set_test_limit(int n) { g_cm_test_limit = n > 0 ? n : 0; }
int nxelf_cm_test_refuses(void) { return g_cm_test_limit > 0 && nxelf_cm_count() >= g_cm_test_limit; }

static Result cm_create(Handle* h, void* src, uint64_t size) {
    if (nxelf_cm_test_refuses()) return MAKERESULT(Module_Kernel, KernelError_ResourceExhausted);
    Result rc = svcCreateCodeMemory(h, src, size);
    if (R_SUCCEEDED(rc)) nxelf_cm_note(1);
    return rc;
}

void nxelf_resource_report(char* out, size_t cap) {
    if (!out || !cap) return;
    int n = snprintf(out, cap, "code memory objects held by this program: %d (peak %d%s%s), system limit 10 for all programs",
                     nxelf_cm_count(), __atomic_load_n(&g_cm_peak, __ATOMIC_RELAXED),
                     g_cm_test_limit ? ", test limit " : "", g_cm_test_limit ? "on" : "");
    if (n < 0 || (size_t)n >= cap) return;
    if (g_cm_unmap_failed) {
        int k = snprintf(out + n, cap - (size_t)n, "; %d view(s) the kernel did not unmap", g_cm_unmap_failed);
        if (k < 0 || (size_t)(n + k) >= cap) return;
        n += k;
    }
    uint64_t used = 0, total = 0;
    if (R_SUCCEEDED(svcGetInfo(&total, InfoType_SystemResourceSizeTotal, CUR_PROCESS_HANDLE, 0)) &&
        R_SUCCEEDED(svcGetInfo(&used, InfoType_SystemResourceSizeUsed, CUR_PROCESS_HANDLE, 0))) {
        int k = snprintf(out + n, cap - (size_t)n, "; kernel resource memory %llu / %llu KB", (unsigned long long)(used >> 10),
                         (unsigned long long)(total >> 10));
        if (k < 0 || (size_t)(n + k) >= cap) return;
        n += k;
    }
    /* the resource limit of the process (threads, events, transfer memories, sessions): only when the two calls are
     * allowed to this program (a call that is not would end it) */
    uint64_t lim = 0;
    if (envIsSyscallHinted(0x30) && envIsSyscallHinted(0x31) &&
        R_SUCCEEDED(svcGetInfo(&lim, InfoType_ResourceLimit, INVALID_HANDLE, 0)) && lim) {
        static const char* const kNames[] = {"threads", "events", "transfer memories", "sessions"};
        for (int i = 0; i < 4; i++) {
            s64 cur = 0, max = 0;
            if (R_FAILED(svcGetResourceLimitCurrentValue(&cur, (Handle)lim, (LimitableResource)(i + 1))) ||
                R_FAILED(svcGetResourceLimitLimitValue(&max, (Handle)lim, (LimitableResource)(i + 1))))
                continue;
            int k = snprintf(out + n, cap - (size_t)n, "; %s %lld / %lld", kNames[i], (long long)cur, (long long)max);
            if (k < 0 || (size_t)(n + k) >= cap) break;
            n += k;
        }
        svcCloseHandle((Handle)lim);
    }
}

static void cm_unmap(Handle h, CodeMapOperation op, void* addr, uint64_t size, int* ok) {
    if (R_FAILED(svcControlCodeMemory(h, op, addr, size, 0))) {
        *ok = 0;
        __atomic_add_fetch(&g_cm_unmap_failed, 1, __ATOMIC_RELAXED);
    }
}

void nxelf_unmap_jit(nxelf_mem* m) {
    int ok = 1;
    if (m->base && m->rw_handle != INVALID_HANDLE)
        cm_unmap(m->rw_handle, CodeMapOperation_UnmapOwner, m->base + m->rw_start, m->rw_size, &ok);
    if (m->base && m->ro_handle != INVALID_HANDLE) cm_unmap(m->ro_handle, CodeMapOperation_UnmapSlave, m->base, m->ro_size, &ok);
    if (m->ro_copy) cm_unmap(m->ro_handle, CodeMapOperation_UnmapOwner, m->ro_copy, m->ro_size, &ok);
    if (m->ro_handle != INVALID_HANDLE) {
        svcCloseHandle(m->ro_handle);
        nxelf_cm_note(-1);
    }
    if (m->rw_handle != INVALID_HANDLE) {
        svcCloseHandle(m->rw_handle);
        nxelf_cm_note(-1);
    }
    /* the kernel unlocks the source pages when an object without views is closed; a view it refused to unmap keeps
     * them locked (no access), so they never go back to malloc (its next user would fault on them) */
    if (ok) {
        free(m->ro_src);
        free(m->rw_src);
    }
    memset(m, 0, sizeof *m);
}

/* Layout in one free stretch of the code region: [base: RX read-only segments][gap][base+rw_start: RW writable
 * segments][base+rw_end: RW copy of the read-only segments]. */
int nxelf_map_jit(nxelf_mem* m, const nxelf_layout* l, char* err, size_t errsz) {
    memset(m, 0, sizeof *m);
    m->ro_size = l->ro_size;
    m->rw_start = l->rw_start;
    m->rw_size = l->rw_size;
    if (!nxelf_jit_available())
        return fail(NXELF_E_NOJIT, err, errsz, "JIT code memory is not available (start Nexvyn OS through Atmosph\xc3\xa8re's homebrew loader)");
    m->ro_src = aligned_alloc(NXELF_PAGE, m->ro_size);
    m->rw_src = aligned_alloc(NXELF_PAGE, m->rw_size);
    if (!m->ro_src || !m->rw_src) {
        free(m->ro_src);
        free(m->rw_src);
        m->ro_src = m->rw_src = NULL;
        return fail(NXELF_E_MEMORY, err, errsz, "out of memory");
    }
    /* no point in clearing the source here: svcCreateCodeMemory fills the pages with 0xFF (the kernel does, and
     * the emulator does the same), so the image is written and .bss zeroed only once the views are mapped (nxelf_link) */
    Handle ro = INVALID_HANDLE, rw = INVALID_HANDLE;
    const char* step = "svcCreateCodeMemory (read-only segments)";
    Result rc = cm_create(&ro, m->ro_src, m->ro_size);
    m->ro_handle = ro;
    if (R_SUCCEEDED(rc)) {
        step = "svcCreateCodeMemory (writable segments)";
        rc = cm_create(&rw, m->rw_src, m->rw_size);
        m->rw_handle = rw;
    }
    if (R_SUCCEEDED(rc)) {
        virtmemLock();
        uint64_t span = m->rw_start + m->rw_size + m->ro_size;
        uint8_t* base = (uint8_t*)virtmemFindCodeMemory(span, NXELF_PAGE);
        uint8_t* copy = base + m->rw_start + m->rw_size;
        step = "svcControlCodeMemory (MapOwner, read-only copy)";
        rc = svcControlCodeMemory(m->ro_handle, CodeMapOperation_MapOwner, copy, m->ro_size, Perm_Rw);
        if (R_SUCCEEDED(rc)) {
            m->ro_copy = copy;
            step = "svcControlCodeMemory (MapSlave, executable view)";
            rc = svcControlCodeMemory(m->ro_handle, CodeMapOperation_MapSlave, base, m->ro_size, Perm_Rx);
        }
        if (R_SUCCEEDED(rc)) {
            m->base = base;
            step = "svcControlCodeMemory (MapOwner, writable segments)";
            rc = svcControlCodeMemory(m->rw_handle, CodeMapOperation_MapOwner, base + m->rw_start, m->rw_size, Perm_Rw);
            if (R_FAILED(rc)) {
                int ok = 1;
                cm_unmap(m->ro_handle, CodeMapOperation_UnmapSlave, base, m->ro_size, &ok);
                m->base = NULL;
                if (!ok) m->ro_src = NULL; /* its view stays: those pages stay locked and never go back to malloc */
            }
        }
        virtmemUnlock();
    }
    if (R_FAILED(rc)) {
        int held = nxelf_cm_count();
        /* everything made so far goes back here (the callers did not all release a half-made mapping: each failure
         * used to leave one code memory object behind) */
        nxelf_unmap_jit(m);
        return fail(NXELF_E_MAP, err, errsz, "cannot map JIT code memory (error 0x%X in %s; code memory objects held: %d)",
                    (unsigned)rc, step, held);
    }
    return NXELF_OK;
}
#endif
