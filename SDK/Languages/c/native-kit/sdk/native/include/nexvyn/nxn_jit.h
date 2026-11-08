/* Nexvyn Native SDK - JIT code memory, fault handler, guard pages (NATIVE_KIT.en.md 3.2.11).
 *
 * For recompilers (emulators) and fastmem. Every path here is optional: check the capability bit first and keep an
 * interpreter / slow path as the fallback. Inside Nexvyn OS each path is behind a user setting that is off by default
 * (native.windowedJit, native.windowedFaultHandler, native.windowedGuardPages); with it off the calls answer
 * NXN_ERR_UNSUPPORTED and nothing else changes.
 *
 * JIT code memory (NXN_CAP_JIT):
 *
 *   nxn_jit* j;
 *   if (nxn_jit_create(4 << 20, &j) == NXN_OK) {
 *       nxn_jit_info in = {sizeof in};
 *       nxn_jit_get(j, &in);
 *       nxn_jit_begin_write(j);
 *       memcpy(in.rw, code, n);            // write through the rw view
 *       nxn_jit_end_write(j, 0, n);        // caches cleaned for that range
 *       ((int (*)(void))in.rx)();          // run from the rx view
 *   }
 *
 *  - The memory has two views at different addresses: rw (write, never execute) and rx (execute, never write). Code
 *    that uses pc-relative data must be written for the rx address.
 *  - nxn_jit_end_write cleans the data cache of [offset, offset + len) in rw and invalidates the instruction cache of
 *    the same range in rx (len 0: the whole buffer). Run code only after it.
 *  - Up to 256 MB per app in total, up to 64 buffers. Everything is given back when the app ends or crashes.
 *
 * Fault handler (NXN_CAP_FAULT_HANDLER), for fastmem:
 *  - A data abort (bad or guarded address) in app code calls the handler on the faulting thread, on that thread's own
 *    stack (512 bytes below the faulting sp). It gets every register; returning 1 resumes at f->pc with the registers
 *    in *f (change pc / x[] to skip or redo the access); returning 0 lets the fault end the app as before.
 *  - x17 (IP1) is NOT restored on resume: it carries the resume address. Code that may fault must not keep a live
 *    value in x17 across the access. FPCR / FPSR are not part of the record.
 *  - A fault inside the handler, inside a Nexvyn OS function, or of another kind (instruction abort, trap) always ends
 *    the app. The handler must not call nxn_* functions and must not block.
 *  - Faults of two threads at the very same moment share one system exception stack; keep handlers short.
 *
 * Guard pages (NXN_CAP_GUARD_PAGES): a page-aligned range inside a block from the app's own malloc / memalign can be
 * made inaccessible (or read-only). A touch faults (the handler above, or the app ends). The guard goes away when the
 * block is freed or reallocated, or with nxn_mem_guard(..., NXN_GUARD_OFF). Never pass a guarded range to an nxn_*
 * or C library function. Up to 32 guarded ranges per app. */
#ifndef NEXVYN_NXN_JIT_H
#define NEXVYN_NXN_JIT_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* ---------------------------------------------------------------- JIT code memory */

typedef struct nxn_jit nxn_jit; /* opaque */

typedef struct nxn_jit_info {
    uint32_t size; /* set by the caller: sizeof(nxn_jit_info) */
    uint32_t reserved;
    void* rw;       /* write view */
    void* rx;       /* execute view */
    uint64_t bytes; /* buffer size (a multiple of 4096) */
} nxn_jit_info;

/* Makes a buffer of `bytes` (rounded up to 4096). NXN_OK and *out, or NXN_ERR_UNSUPPORTED (setting off, no code memory
 * in this process), NXN_ERR_INVALID (bytes 0, out NULL), NXN_ERR_NO_MEMORY (limit reached or the system said no).
 * Thread: any app thread. Memory: *out is a library-owned handle, freed by nxn_jit_destroy or when the app ends. */
NXN_API nxn_result nxn_jit_create(uint64_t bytes, nxn_jit** out);
/* Fills min(out->size, sizeof(nxn_jit_info)) bytes (out->size set by the caller). Thread: any app thread. Memory: written
 * into the caller's struct; rw / rx stay valid until nxn_jit_destroy. */
NXN_API nxn_result nxn_jit_get(nxn_jit* j, nxn_jit_info* out);
/* Before writing code (cheap; keeps the contract when a later system needs a permission change).
 * Thread: the thread that writes the code. Memory: none. */
NXN_API nxn_result nxn_jit_begin_write(nxn_jit* j);
/* After writing code, before running it: cache maintenance of [offset, offset + len) (len 0: everything).
 * Thread: the thread that wrote the code. Memory: none. */
NXN_API nxn_result nxn_jit_end_write(nxn_jit* j, uint64_t offset, uint64_t len);
/* Gives the buffer back. No thread may run code in it any more. NULL is ignored.
 * Thread: any app thread. Memory: frees the handle and both views; none of them may be used afterwards. */
NXN_API void nxn_jit_destroy(nxn_jit* j);

/* ---------------------------------------------------------------- fault handler */

enum {
    NXN_FAULT_DATA_ABORT = 1 /* load / store at a bad, unmapped or guarded address (SIGSEGV / SIGBUS) */
};

typedef struct nxn_fault {
    uint32_t size; /* sizeof(nxn_fault) of the system; a handler reads only what it knows */
    uint32_t kind; /* NXN_FAULT_* */
    uint64_t addr; /* the faulting data address (FAR) */
    uint64_t esr;  /* the syndrome (ESR) */
    uint64_t pc;   /* the faulting instruction; set it to where execution goes on */
    uint64_t sp;
    uint64_t x[31]; /* x0..x30 (x29 = fp, x30 = lr); x17 is not restored */
    uint64_t pstate; /* NZCV in bits 31..28 are restored */
} nxn_fault;

/* Returns 1 to resume with *f, 0 to let the fault end the app. */
typedef int (*nxn_fault_fn)(nxn_fault* f, void* user);

/* Sets the app's one fault handler (NULL removes it). NXN_ERR_UNSUPPORTED when the setting is off.
 * Thread: any app thread (the handler then runs on whichever app thread faults). Memory: `user` is passed to the
 * handler as is and stays the app's; *f belongs to the system and is valid only during the handler call. */
NXN_API nxn_result nxn_fault_handler_set(nxn_fault_fn fn, void* user);

/* ---------------------------------------------------------------- guard pages */

enum {
    NXN_GUARD_OFF = 0,      /* back to read / write */
    NXN_GUARD_NOACCESS = 1, /* every touch faults */
    NXN_GUARD_READONLY = 2  /* writes fault */
};

/* block: a pointer the app's malloc / memalign returned; [block + offset, block + offset + len) page-aligned and inside
 * it. NXN_ERR_UNSUPPORTED (setting off, no own heap, or the system refuses the permission), NXN_ERR_INVALID (not such a
 * range), NXN_ERR_NO_MEMORY (32 ranges guarded already). Thread: any app thread. Memory: the block stays the app's;
 * freeing or reallocating it removes the guard. */
NXN_API nxn_result nxn_mem_guard(void* block, uint64_t offset, uint64_t len, uint32_t mode);

NXN_EXTERN_C_END

#endif
