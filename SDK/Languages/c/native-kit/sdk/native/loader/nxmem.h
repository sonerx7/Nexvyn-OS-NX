/* Nexvyn heap page audit: finds the pages of a heap range that a program cannot use as plain memory. One
 * implementation, compiled unchanged by Nexvyn OS (source/core/heapguard.cpp, C++) and by libnexvyn_native
 * (sdk/native/lib/src/nxn_teardown.c, C). Plain C11; the desktop tests compile it too (tests/test_native.cpp).
 *
 * Why: a native app runs in Nexvyn OS's process (the homebrew loader chain-loads it and Nexvyn OS again), so both
 * programs get the same heap. Kernel objects the app leaves open keep pages of that heap locked: a thread that was
 * never closed (libnx maps its stack with svcMapMemory, the heap source becomes Perm_None + IsBorrowed), transfer memory
 * a service still holds (Perm_None + IsBorrowed), JIT code memory, device or IPC mappings, uncached GPU buffers. The
 * next program's malloc hands those pages out and the first write is a translation fault.
 *
 * A page is "dirty" when its block is not plain heap with read/write permission and no attribute. */
#ifndef NEXVYN_NXMEM_H
#define NEXVYN_NXMEM_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NXMEM_TYPE_HEAP 0x05u /* MemType_Heap */
#define NXMEM_PERM_RW 0x03u   /* Perm_Rw */
#define NXMEM_KEEP 8          /* dirty blocks kept in a report (the totals count all of them) */

typedef struct nxmem_block {
    uint64_t addr, size;
    uint32_t type, attr, perm;
} nxmem_block;

/* The memory block that contains addr (svcQueryMemory on the console). 1 on success. */
typedef int (*nxmem_query_fn)(void* user, uint64_t addr, nxmem_block* out);

typedef struct nxmem_report {
    uint64_t lo, hi;              /* the scanned range */
    uint32_t dirty_count;         /* dirty blocks, all of them */
    uint64_t dirty_bytes;
    uint32_t locked_count;        /* the dirty blocks a write faults on (not mapped read/write: nxmem_locked) */
    uint64_t locked_bytes;
    nxmem_block dirty[NXMEM_KEEP]; /* clipped to the range, by address; locked blocks are kept before the others */
    uint32_t kept;                /* entries used in dirty[] */
    uint64_t clean_lo, clean_hi;  /* the largest run of clean pages (the whole range when nothing is dirty) */
    int complete;                 /* 0: a query failed, the scan stopped early (the totals cover what was read) */
} nxmem_report;

/* 1 when the block cannot be used as plain heap memory. */
int nxmem_dirty(const nxmem_block* b);
/* 1 when a write to the block faults (not plain heap, or not read/write): the dangerous kind of dirty block. The others
 * (device mapped, uncached, IPC mapped) can be written but still belong to a device or a service. */
int nxmem_locked(const nxmem_block* b);

/* Walks [lo, hi) block by block. skip: n_skip [lo, hi) pairs that count as clean (the caller's own thread stack).
 * Never allocates; safe in a crash handler and before the heap exists. Returns dirty_count. */
uint32_t nxmem_scan(nxmem_query_fn query, void* user, uint64_t lo, uint64_t hi, const uint64_t* skip, int n_skip,
                    nxmem_report* out);

/* One line for a log: "3 dirty block(s), 1088 KB, 1 locked (260 KB): +0x1c000 260 KB type 0x5 perm 0 attr 0x1, ..."
 * (offsets from r->lo). */
size_t nxmem_describe(const nxmem_report* r, char* out, size_t cap);

/* ------------------------------------------------------------------ the heap guard (both programs, at their start)
 * The homebrew loader reads the next program's image into the start of the heap (hbloader: the file goes to the heap's
 * first bytes, then svcMapProcessCodeMemory maps it from there; the program gets the rest as its heap). A page that
 * stays locked there (a JIT library, a thread stack, transfer memory) makes that read fail: the next program, often
 * Nexvyn OS itself, does not start. So a heap the loader hands over keeps its first NXMEM_LOADER_RESERVE bytes out of
 * malloc (Nexvyn OS's image is about 70 MB), and of the rest malloc gets the largest clean run when the program before
 * left pages locked there. */
#define NXMEM_LOADER_RESERVE (128ull << 20)
#define NXMEM_RESERVE_MIN_HEAP (1024ull << 20) /* smaller heaps (applet mode) keep no reserve */
#define NXMEM_MIN_CLEAN (256ull << 20)         /* below this the whole rest is used, as before the guard */

typedef struct nxmem_heap {
    uint64_t offer_lo, offer_hi; /* the heap the loader handed over (or svcSetHeapSize gave) */
    uint64_t lo, hi;             /* what malloc gets */
    uint64_t reserved;           /* bytes at offer_lo kept out of malloc for the loader */
    int chained;                 /* the heap came from the loader (another program may have used it) */
    int limited;                 /* dirty blocks above the reserve: malloc got the largest clean run */
    nxmem_report start;          /* chained: the scan of [offer_lo + reserved, offer_hi) */
    uint32_t reserve_dirty;      /* chained: dirty blocks inside the reserve (harmless to malloc) */
    uint64_t reserve_dirty_bytes;
} nxmem_heap;

/* Picks malloc's range for a heap [lo, hi) (see above). Not chained: the whole heap. Pure: the desktop tests run it. */
void nxmem_heap_plan(nxmem_heap* h, nxmem_query_fn query, void* user, uint64_t lo, uint64_t hi, int chained,
                     uint64_t min_clean);

#ifdef __SWITCH__
/* svcQueryMemory as an nxmem_query_fn (user is unused). */
int nxmem_query_svc(void* user, uint64_t addr, nxmem_block* out);

/* The body of a program's __libnx_initheap: libnx's steps (the loader's heap override, else svcSetHeapSize), then
 * nxmem_heap_plan, then fake_heap_start/end. Runs before malloc and before any constructor; allocates nothing. It also
 * notes which threads already exist (nxmem_thread_is_leftover). */
void nxmem_initheap(nxmem_heap* h, uint64_t min_clean);

/* 1 when the calling thread was started by a program before this one: it outlived that program and now runs (or
 * faults) in code that is gone. An exception handler ends such a thread with svcExitThread and touches nothing of it
 * (its thread variables point into the old program). Thread ids only grow, so "started before" is an id below the
 * first id this program could get (a never-started probe thread made in nxmem_initheap). 0 when that was unknown. */
int nxmem_thread_is_leftover(void);
#endif

#ifdef __cplusplus
}
#endif

#endif /* NEXVYN_NXMEM_H */
