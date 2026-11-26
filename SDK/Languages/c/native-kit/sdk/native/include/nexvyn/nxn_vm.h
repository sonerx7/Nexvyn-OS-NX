/* Nexvyn Native SDK - sparse virtual memory (N6 P1, docs/NATIVE_KIT.md "Virtual memory").
 *
 * For emulators and runtimes that need a large, fixed address range (a guest address space, a GC heap) but only back
 * the parts they touch. This API is available to windowed native modules.
 *
 *   nxn_vm_region* vm;
 *   if (nxn_vm_reserve(1ull << 30, NXN_VM_NEED_SPARSE, &vm) == NXN_OK) {
 *       nxn_vm_info in = {sizeof in};
 *       if (nxn_vm_get(vm, &in) == NXN_OK &&
 *           nxn_vm_commit(vm, 0, 2 * NXN_VM_COMMIT_GRANULE) == NXN_OK) {
 *           memset(in.base, 1, 2 * NXN_VM_COMMIT_GRANULE);
 *           nxn_vm_decommit(vm, 0, NXN_VM_COMMIT_GRANULE);
 *       }
 *       nxn_vm_release(vm);
 *   }
 *
 * Memory contract:
 *  - A region is one fixed range [base, base + bytes); base never moves. bytes is rounded up to 64 KiB.
 *  - commit / decommit work in units of nxn_vm_info.commit_granule. By default the unit is 64 KiB. A committed
 *    granule reads zero the first time and after every decommit + commit; committing an already committed granule
 *    keeps its contents. A failed commit rolls back its new granules. NXN_ERR_SYSTEM means the kernel refused part of
 *    the rollback.
 *  - Touching an uncommitted granule is undefined: it faults with the P and A backends (the app ends unless its fault
 *    handler takes it) and reads stale / zero data with the H backend. Never pass an uncommitted or protected range to
 *    an nxn_* or C library function.
 *  - protect works in 4 KiB pages (NXN_VM_PROTECT_GRANULE) of committed granules: NXN_VM_PROT_NONE, _R or _RW. A
 *    decommit puts the pages back to RW. Without NXN_VM_CAN_PROTECT protect answers NXN_ERR_UNSUPPORTED.
 *  - RAM charge: the committed bytes (P, A) or the whole region from reserve (H) count against the app's manifest
 *    "memory" (when declared) and must leave Nexvyn OS its reserve; each granule is charged once.
 *  - Everything (backing, address range, charge) goes back with nxn_vm_release or when the host confirms the app's
 *    threads have ended. Quarantined threads can delay reclamation.
 *  - Emulators may not enforce page permissions; a fault test proves protection only on the console.
 *
 * Thread contract: any app thread. Calls on one region are serialized by the system (a commit and a decommit of the
 * same region from two threads do not corrupt its state). Allocations share process-wide memory admission. The app must
 * not touch a granule while another of its threads decommits it, and must not use a region after nxn_vm_release.
 *
 * Backends (nxn_vm_info.backend), picked at reserve:
 *  - NXN_VM_BACKEND_PHYS: address range in the alias region, physical memory mapped per granule. Sparse RAM and
 *    4 KiB protection. Needs a kernel that allows it (checked once by a self-test).
 *  - NXN_VM_BACKEND_MAP: address range in the stack region, heap pages mapped per granule. Sparse RAM, no protection;
 *    the size is limited by the largest free run of that region (a few hundred MiB).
 *  - NXN_VM_BACKEND_HEAP: one heap block of the whole size, held from reserve. 4 KiB protection; decommit zeroes and
 *    keeps the RAM.
 *  Order: NXN_VM_NEED_PROTECT -> PHYS, else HEAP. Otherwise PHYS, else MAP, else HEAP. NXN_VM_NEED_SPARSE never picks
 *  HEAP. */
#ifndef NEXVYN_NXN_VM_H
#define NEXVYN_NXN_VM_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_vm_region nxn_vm_region; /* opaque region handle */

#define NXN_VM_COMMIT_GRANULE 0x10000u  /* commit / decommit unit: 64 KiB */
#define NXN_VM_PROTECT_GRANULE 0x1000u  /* protect unit: 4 KiB */

/* nxn_vm_reserve flags */
#define NXN_VM_NEED_PROTECT 0x1u /* only a backend with NXN_VM_CAN_PROTECT */
#define NXN_VM_NEED_SPARSE 0x2u  /* only a backend with NXN_VM_SPARSE_RAM (no heap block of the whole size) */

/* Requires PHYS and selects independently backed 4 KiB pages (see nxn_vm_info.commit_granule). */
#define NXN_VM_NEED_PAGE_COMMIT 0x4u

/* nxn_vm_info.backend */
enum {
    NXN_VM_BACKEND_NONE = 0,
    NXN_VM_BACKEND_PHYS = 1, /* P: alias region + physical memory */
    NXN_VM_BACKEND_MAP = 2,  /* A: stack region + mapped heap pages */
    NXN_VM_BACKEND_HEAP = 3  /* H: one heap block */
};

/* nxn_vm_info.abilities */
#define NXN_VM_CAN_PROTECT 0x1u /* nxn_vm_protect works at 4 KiB */
#define NXN_VM_SPARSE_RAM 0x2u  /* decommit gives the RAM back; reserve takes none */
#define NXN_VM_CAN_PAGE_COMMIT 0x4u /* page backing with combined commit and protect */

/* nxn_vm_protect */
enum { NXN_VM_PROT_NONE = 0, NXN_VM_PROT_R = 1, NXN_VM_PROT_RW = 3 };

/* Optional nxn_vm_protect flags on PAGE_COMMIT regions. COMMIT backs only the requested accessible pages;
 * NONE skips unbacked pages. REPLACE also gives the requested pages fresh zeroed contents. */
#define NXN_VM_PROT_COMMIT 0x100u
#define NXN_VM_PROT_REPLACE 0x200u /* requires NXN_VM_PROT_COMMIT */

typedef struct nxn_vm_info {
    uint32_t size;      /* set by the caller: sizeof(nxn_vm_info) */
    uint32_t backend;   /* NXN_VM_BACKEND_* */
    uint32_t abilities; /* NXN_VM_CAN_PROTECT | NXN_VM_SPARSE_RAM */
    uint32_t reserved;
    void* base;               /* first byte of the region */
    uint64_t bytes;           /* region size (a multiple of commit_granule) */
    uint64_t commit_granule;  /* NXN_VM_COMMIT_GRANULE, or 4 KiB with NXN_VM_CAN_PAGE_COMMIT */
    uint64_t protect_granule; /* NXN_VM_PROTECT_GRANULE */
    uint64_t committed;       /* bytes committed now */
    uint64_t charged;         /* bytes this region counts against the app's memory now */
} nxn_vm_info;

/* Reserves `bytes` of address space (rounded up to 64 KiB; at most 32 GiB). NXN_OK and *out, or NXN_ERR_INVALID (bytes 0,
 * out NULL, unknown flag), NXN_ERR_NOT_READY (calling thread is not a live windowed app or prior app instance is retiring),
 * NXN_ERR_UNSUPPORTED (no backend matches the flags), NXN_ERR_NO_MEMORY (no address range or, for HEAP, no RAM),
 * NXN_ERR_LIMIT (64 regions per app). Thread: any app thread. Memory: *out is a system-owned handle, freed by
 * nxn_vm_release or when the app ends. */
NXN_API nxn_result nxn_vm_reserve(uint64_t bytes, uint32_t flags, nxn_vm_region** out);
/* Fills min(out->size, sizeof(nxn_vm_info)) bytes (out->size set by the caller). NXN_ERR_INVALID (bad handle or out),
 * NXN_ERR_NOT_READY (not an app thread or region released). Thread: any app thread. Memory: written into the caller's
 * struct; base stays valid until nxn_vm_release. */
NXN_API nxn_result nxn_vm_get(nxn_vm_region* vm, nxn_vm_info* out);
/* Backs [offset, offset + bytes) (commit_granule units) with zeroed RW memory; committed granules keep their contents.
 * NXN_ERR_INVALID (handle or range), NXN_ERR_NOT_READY (not an app thread or region released), NXN_ERR_NO_MEMORY (budget
 * or system; nothing changed), NXN_ERR_SYSTEM (rollback incomplete). Thread: any app thread. Memory: the range is usable
 * until it is decommitted or the region released. */
NXN_API nxn_result nxn_vm_commit(nxn_vm_region* vm, uint64_t offset, uint64_t bytes);
/* Takes the backing of [offset, offset + bytes) (commit_granule units) away; uncommitted granules are skipped.
 * NXN_ERR_INVALID (handle or range), NXN_ERR_NOT_READY (not an app thread or region released), NXN_ERR_SYSTEM
 * (the kernel refused; that granule stays committed). Thread: any app thread; no thread may touch the range during or
 * after the call. Memory: RAM back with NXN_VM_SPARSE_RAM, else zeroed and kept. */
NXN_API nxn_result nxn_vm_decommit(nxn_vm_region* vm, uint64_t offset, uint64_t bytes);
/* Sets the permission of [offset, offset + bytes) (4 KiB units, inside committed granules) to prot (NXN_VM_PROT_*).
 * NXN_ERR_UNSUPPORTED without NXN_VM_CAN_PROTECT, NXN_ERR_INVALID (handle, range not committed, bad prot),
 * NXN_ERR_NOT_READY (not an app thread or region released), NXN_ERR_NO_MEMORY (metadata allocation failed; nothing
 * changed), NXN_ERR_SYSTEM (the kernel refused; earlier permissions are restored), NXN_ERR_IO (the kernel also
 * refused permission rollback; the region must be discarded). With COMMIT, a rollback may temporarily retain
 * inaccessible backing and its charge. With REPLACE, an unsuccessful call may already have zeroed target data.
 * Thread: any app thread; quiesce readers and writers of the target during COMMIT or REPLACE. */
NXN_API nxn_result nxn_vm_protect(nxn_vm_region* vm, uint64_t offset, uint64_t bytes, uint32_t prot);
/* Gives the region back: backing, address range and charge. NULL is ignored. Thread: any app thread; no thread may
 * touch the region any more. Memory: the handle and base are invalid afterwards. */
NXN_API void nxn_vm_release(nxn_vm_region* vm);

/* Write-watch (4 KiB) requires NXN_VM_CAN_PROTECT and native.windowedFaultHandler. No app fault callback is needed.
 * Arms a page-aligned range of committed RW pages. A direct store's permission fault marks the page dirty, leaves
 * it RW, and retries the store before dispatching any other faults to the app callback. Rearm with nxn_vm_watch;
 * rearming preserves pending marks. NXN_ERR_SYSTEM can leave earlier pages in the range armed. NXN_ERR_NO_MEMORY
 * means watch metadata could not be allocated. NXN_ERR_UNSUPPORTED means protection or fault handling is unavailable.
 * A fault that cannot lift protection takes the normal crash path. The handler never waits on a page lock.
 * The resume path clobbers x17. Compiled code rarely uses x17 in a memory instruction. A faulting instruction that
 * uses x17 cannot be safely replayed, so JIT code accessing watched pages must avoid x17 in those instructions.
 * the emulator may accept permission changes without enforcing them. Verify direct store faults on the console.
 * Thread: any app thread outside a fault handler. Quiesce direct access before changing a range's backing or
 * using nxn_vm_protect on it. Successful plain protect, decommit, or release removes the affected watches and marks.
 * COMMIT/REPLACE protection flags require disarming the affected pages first. */
NXN_API nxn_result nxn_vm_watch(nxn_vm_region* vm, uint64_t offset, uint64_t bytes);

/* Copies up to max dirty page offsets (bytes from base, ascending) and clears only those marks. *count is the
 * number copied, including any copied before an error. max=0 is allowed. Collection does not rearm pages.
 * Use writable output storage outside watched pages. Thread: any app thread outside a fault handler. Quiesce writers
 * and backing changes to collect a stable snapshot of completed stores. A raw fault marks before its store retries. */
NXN_API nxn_result nxn_vm_watch_collect(nxn_vm_region* vm, uint64_t* offsets, size_t max, size_t* count);

/* Copies a nonempty byte range into watched pages. src must be readable for bytes bytes and must not overlap the
 * destination. Synchronize overlapping memory accesses at the application level. The host takes each page's lock,
 * lifts protection if needed, copies, restores R, and marks dirty after the restore attempt. Concurrent direct
 * stores while the page was RW are covered by that mark. NXN_ERR_SYSTEM can leave a prefix copied. If a restore
 * fails, that page stays RW and dirty. Rearm it with nxn_vm_watch. Thread: any app thread outside a fault handler. */
NXN_API nxn_result nxn_vm_write(nxn_vm_region* vm, uint64_t offset, const void* src, uint64_t bytes);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_VM_H */
