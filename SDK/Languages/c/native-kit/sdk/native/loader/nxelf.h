/* Nexvyn ELF loader core: maps, relocates and links an AArch64 shared object (an OS module .nxvmod or a native shared
 * library .nxvlib) inside a running NRO. One implementation, compiled unchanged by Nexvyn OS (source/runtimes/nxvmod.cpp,
 * C++) and by libnexvyn_native (sdk/native/lib/src/nxn_lib.c, C), so an exclusive-mode app can load libraries while
 * Nexvyn OS is not in memory. Plain C11, no libstdc++; the desktop tests compile it too (tests/test_nxelf.cpp).
 *
 * Steps for a caller:
 *   1. nxelf_layout_of(): checks the file (ELF64 little endian, AArch64, ET_DYN, no PT_TLS) and returns the layout.
 *      nxelf_layout_ex(NXELF_F_TLS) accepts PT_TLS too and reports the TLS image (windowed apps, Native W2): the caller
 *      then sets nxelf_mem.tls_module before nxelf_link(), which fills R_AARCH64_TLS_DTPMOD64 / DTPREL64 for
 *      __tls_get_addr (objects compiled with -mtls-dialect=trad; TLSDESC and TPREL are refused with a message).
 *   2. map the layout (on the console nxelf_map_jit(): JIT code memory, an RX view at the object's address 0 and an
 *      RW view of the same pages for writing; the writable segments in a second code memory object, mapped RW).
 *   3. nxelf_link(): copies the segments, applies RELATIVE / GLOB_DAT / JUMP_SLOT / ABS64 / RELR relocations and
 *      flushes the caches. A symbol is looked up in the host first (the caller's lookup function: the NRO's own
 *      .dynsym), then in the object's own definitions; an undefined weak symbol becomes 0, any other unresolved
 *      symbol is an error that names it. Text relocations are refused.
 *   4. run DT_INIT and .init_array (the caller does it: Nexvyn OS guards them, a native app calls them directly).
 * Every error is a return value with a message; nothing here aborts. */
#ifndef NEXVYN_NXELF_H
#define NEXVYN_NXELF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NXELF_PAGE 0x1000

enum {
    NXELF_OK = 0,
    NXELF_E_FORMAT = 1,  /* not an AArch64 shared object, truncated or inconsistent tables */
    NXELF_E_TLS = 2,     /* thread_local variables (PT_TLS) */
    NXELF_E_TEXTREL = 3, /* text relocations (built without -fPIC) */
    NXELF_E_SYMBOL = 4,  /* an imported symbol nobody defines */
    NXELF_E_RELOC = 5,   /* an unsupported relocation type */
    NXELF_E_NOJIT = 6,   /* JIT code memory is not available (applet mode, no homebrew loader hints) */
    NXELF_E_MEMORY = 7,  /* out of memory */
    NXELF_E_MAP = 8      /* the kernel refused to map code memory */
};

/* Where the segments go, relative to the object's address 0: read-only segments in [0, ro_size), writable ones in
 * [rw_start, rw_start + rw_size) (rw_start >= ro_size, page aligned). */
typedef struct nxelf_layout {
    uint64_t ro_size;
    uint64_t rw_start, rw_size;
    uint64_t dyn;  /* address of the dynamic section (inside the writable segment) */
    /* PT_TLS (only with NXELF_F_TLS; all 0 without one): the initial image [tls_vaddr, +tls_filesz), the block size
     * tls_memsz (the rest is zero) and its alignment */
    uint64_t tls_vaddr, tls_filesz, tls_memsz, tls_align;
} nxelf_layout;

#define NXELF_F_TLS 1u /* nxelf_layout_ex: accept a PT_TLS segment */

/* The mapped object. base: executable view (address 0 of the object); ro_copy: writable view of the read-only pages
 * (the same memory as base on the desktop tests). Handles are libnx CodeMemory handles (0 = none). */
typedef struct nxelf_mem {
    uint32_t ro_handle, rw_handle;
    void* ro_src;
    void* rw_src;
    uint8_t* base;
    uint8_t* ro_copy;
    uint64_t ro_size, rw_start, rw_size;
    /* set by the caller after mapping (0: thread_local relocations are refused): the value R_AARCH64_TLS_DTPMOD64
     * stores, i.e. what the caller's __tls_get_addr receives as the module of a tls_index */
    uint64_t tls_module;
} nxelf_mem;

/* A dynamic symbol table (SysV hash) and the address its values are relative to. */
typedef struct nxelf_symtab {
    const void* syms;      /* Elf64_Sym[] */
    const char* strs;
    const uint32_t* hash;  /* DT_HASH: nbucket, nchain, buckets, chains */
    uint32_t nsyms;
    uintptr_t base;
} nxelf_symtab;

/* What nxelf_link() found: the object's own symbols and its constructors / destructors (absolute addresses). */
typedef struct nxelf_info {
    nxelf_symtab symtab;
    uintptr_t init, init_array;
    size_t init_count;
    uintptr_t fini, fini_array;
    size_t fini_count;
} nxelf_info;

/* Looks a name up in the host: 1 and *addr when found, 0 otherwise. */
typedef int (*nxelf_lookup_fn)(void* ctx, const char* name, uint64_t* addr);

/* A symbol another object may bind to: global, weak or unique, defined, not a section / file / TLS symbol. The same
 * rule as tools/build_modules.py exported(). */
int nxelf_exportable(uint8_t info, uint16_t shndx, const char* name);

/* Checks the ELF header and program headers and fills the layout. kind names the object in messages: "module" (the
 * default) or "library". Returns NXELF_OK or an NXELF_E_* code with a message in err. */
int nxelf_layout_of(const uint8_t* img, size_t size, const char* kind, nxelf_layout* out, char* err, size_t errsz);
/* The same with flags (NXELF_F_TLS). nxelf_layout_of() is nxelf_layout_ex(..., 0, ...). */
int nxelf_layout_ex(const uint8_t* img, size_t size, const char* kind, unsigned flags, nxelf_layout* out, char* err,
                    size_t errsz);

/* Copies the image into the mapped memory, relocates it and fills info (step 3 above). */
int nxelf_link(const uint8_t* img, size_t size, const nxelf_mem* m, nxelf_lookup_fn lookup, void* ctx, nxelf_info* info,
               char* err, size_t errsz);

/* Finds a section by name in the file image: 1 with its file offset and size, 0 when absent or out of bounds. */
int nxelf_section(const uint8_t* img, size_t size, const char* name, uint64_t* offset, uint64_t* bytes);
/* The same, giving the section's address in the object (sh_addr) instead of its file offset. */
int nxelf_section_addr(const uint8_t* img, size_t size, const char* name, uint64_t* addr, uint64_t* bytes);

/* The symbol table of a loaded dynamic section. base: the object's load address; table addresses below base are
 * link-time values (the NRO is linked at 0) and get base added. 1 when the table has DT_SYMTAB, DT_STRTAB and DT_HASH. */
int nxelf_symtab_of(const void* dynamic, uintptr_t base, nxelf_symtab* out);

/* Calls fn for every exportable symbol of the table, in table order (absolute address). */
void nxelf_symtab_each(const nxelf_symtab* t, void (*fn)(void* ctx, const char* name, uintptr_t addr), void* ctx);

/* Hash lookup of an exportable symbol: 1 and its absolute address, 0 when the table does not define it. */
int nxelf_symtab_find(const nxelf_symtab* t, const char* name, uintptr_t* addr);

#ifdef __SWITCH__
/* Maps the layout in JIT code memory (the m->* fields are filled; on failure everything is released again and m is
 * cleared, so a later nxelf_unmap_jit() on it does nothing). The message names the call that failed. */
int nxelf_map_jit(nxelf_mem* m, const nxelf_layout* l, char* err, size_t errsz);
/* Releases what nxelf_map_jit() mapped and clears m. Never call it while code of the object may still run. */
void nxelf_unmap_jit(nxelf_mem* m);
/* 1 when this process may create JIT code memory (svcCreateCodeMemory / svcControlCodeMemory are hinted). */
int nxelf_jit_available(void);
/* Code memory objects are a kernel object kind with a fixed count for the whole system (10 on the console; error
 * 0xCE01 when none is left; emulators have no limit). nxelf counts the ones it makes; a caller that makes its own
 * (libnx jitCreate, svcCreateCodeMemory) notes +1 / -1 with nxelf_cm_note. */
void nxelf_cm_note(int delta);
int nxelf_cm_count(void);
/* Test only (emulators): refuse a new object (0xCE01) while n are held; 0 turns it off. */
void nxelf_cm_set_test_limit(int n);
int nxelf_cm_test_refuses(void);
/* One line for a log: code memory objects held, kernel resource memory and the process's resource limits. */
void nxelf_resource_report(char* out, size_t cap);
#endif

#ifdef __cplusplus
}
#endif
#endif /* NEXVYN_NXELF_H */
