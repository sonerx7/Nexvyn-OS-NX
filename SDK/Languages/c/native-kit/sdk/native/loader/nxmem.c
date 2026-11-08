/* Nexvyn heap page audit (nxmem.h). Valid C and C++. */
#include "nxmem.h"
#include <stdio.h>
#include <string.h>
#ifdef __SWITCH__
#include <switch.h>
#endif

int nxmem_dirty(const nxmem_block* b) {
    return (b->type & 0xFFu) != NXMEM_TYPE_HEAP || (b->perm & NXMEM_PERM_RW) != NXMEM_PERM_RW || b->attr != 0;
}

int nxmem_locked(const nxmem_block* b) {
    return (b->type & 0xFFu) != NXMEM_TYPE_HEAP || (b->perm & NXMEM_PERM_RW) != NXMEM_PERM_RW;
}

/* Keeps at most NXMEM_KEEP blocks: locked ones push out the others, the list stays in address order. */
static void keep(nxmem_report* r, const nxmem_block* b) {
    uint32_t at = r->kept;
    if (r->kept == NXMEM_KEEP) {
        if (!nxmem_locked(b)) return;
        int victim = -1;
        for (int i = NXMEM_KEEP - 1; i >= 0; i--)
            if (!nxmem_locked(&r->dirty[i])) {
                victim = i;
                break;
            }
        if (victim < 0) return;
        for (uint32_t i = (uint32_t)victim; i + 1 < NXMEM_KEEP; i++) r->dirty[i] = r->dirty[i + 1];
        at = NXMEM_KEEP - 1;
    } else {
        r->kept++;
    }
    r->dirty[at] = *b; /* scanned in address order: the new block is the highest */
}

static int in_skip(uint64_t x, const uint64_t* skip, int n_skip) {
    for (int i = 0; i < n_skip; i++)
        if (skip[2 * i] <= x && x < skip[2 * i + 1]) return 1;
    return 0;
}

/* The first skip boundary in (x, e), or e. */
static uint64_t next_cut(uint64_t x, uint64_t e, const uint64_t* skip, int n_skip) {
    uint64_t y = e;
    for (int i = 0; i < 2 * n_skip; i++)
        if (skip[i] > x && skip[i] < y) y = skip[i];
    return y;
}

uint32_t nxmem_scan(nxmem_query_fn query, void* user, uint64_t lo, uint64_t hi, const uint64_t* skip, int n_skip,
                    nxmem_report* out) {
    memset(out, 0, sizeof *out);
    out->lo = lo;
    out->hi = hi;
    out->complete = 1;
    uint64_t run_lo = lo, best_lo = lo, best_hi = lo, a = lo;
    while (a < hi) {
        nxmem_block b;
        memset(&b, 0, sizeof b);
        if (!query || !query(user, a, &b) || b.size == 0 || b.addr > a || b.addr + b.size <= a) {
            out->complete = 0;
            break;
        }
        uint64_t e = b.addr + b.size;
        if (e > hi || e < b.addr) e = hi;
        int dirty = nxmem_dirty(&b);
        for (uint64_t x = a; x < e;) {
            uint64_t y = next_cut(x, e, skip, n_skip);
            if (dirty && !in_skip(x, skip, n_skip)) {
                if (x - run_lo > best_hi - best_lo) {
                    best_lo = run_lo;
                    best_hi = x;
                }
                run_lo = y;
                nxmem_block d = b;
                d.addr = x;
                d.size = y - x;
                keep(out, &d);
                out->dirty_count++;
                out->dirty_bytes += y - x;
                if (nxmem_locked(&b)) {
                    out->locked_count++;
                    out->locked_bytes += y - x;
                }
            }
            x = y;
        }
        a = e;
    }
    uint64_t end = a < hi ? a : hi;
    if (end > run_lo && end - run_lo > best_hi - best_lo) {
        best_lo = run_lo;
        best_hi = end;
    }
    out->clean_lo = best_lo;
    out->clean_hi = best_hi;
    return out->dirty_count;
}

size_t nxmem_describe(const nxmem_report* r, char* out, size_t cap) {
    if (!out || cap == 0) return 0;
    int n = snprintf(out, cap, "%u dirty block(s), %llu KB, %u locked (%llu KB)%s", r->dirty_count,
                     (unsigned long long)(r->dirty_bytes >> 10), r->locked_count,
                     (unsigned long long)(r->locked_bytes >> 10), r->complete ? "" : " (scan stopped early)");
    size_t pos = n > 0 ? (size_t)n : 0;
    for (uint32_t i = 0; i < r->kept && pos + 1 < cap; i++) {
        const nxmem_block* d = &r->dirty[i];
        n = snprintf(out + pos, cap - pos, "%s +0x%llx %llu KB type 0x%x perm %u attr 0x%x", i ? "," : ":",
                     (unsigned long long)(d->addr - r->lo), (unsigned long long)(d->size >> 10), d->type & 0xFFu,
                     d->perm, d->attr);
        if (n < 0) break;
        pos += (size_t)n;
    }
    if (pos >= cap) pos = cap - 1;
    return pos;
}

void nxmem_heap_plan(nxmem_heap* h, nxmem_query_fn query, void* user, uint64_t lo, uint64_t hi, int chained,
                     uint64_t min_clean) {
    memset(h, 0, sizeof *h);
    h->offer_lo = h->lo = lo;
    h->offer_hi = h->hi = hi;
    h->chained = chained;
    /* a heap the program got from the kernel itself holds nobody's leftovers, and no loader reads into it */
    if (!chained || hi <= lo) return;
    if (hi - lo >= NXMEM_RESERVE_MIN_HEAP) h->reserved = NXMEM_LOADER_RESERVE;
    uint64_t start = lo + h->reserved;
    h->lo = start;
    if (h->reserved) {
        nxmem_report r; /* only the totals: what sits in the reserve is reported, it never reaches malloc */
        nxmem_scan(query, user, lo, start, NULL, 0, &r);
        h->reserve_dirty = r.dirty_count;
        h->reserve_dirty_bytes = r.dirty_bytes;
    }
    nxmem_scan(query, user, start, hi, NULL, 0, &h->start);
    if (h->start.dirty_count && h->start.clean_hi - h->start.clean_lo >= min_clean) {
        h->lo = h->start.clean_lo;
        h->hi = h->start.clean_hi;
        h->limited = 1;
    }
}

#ifdef __SWITCH__
extern char* fake_heap_start;
extern char* fake_heap_end;
extern size_t __nx_heap_size;

static uint64_t s_main_tid, s_first_tid;

static void probe_entry(void* arg) { (void)arg; }

/* The main thread's id and the first id this program can get: a thread made here and never started (nothing runs on
 * its stack pointer, the handle is closed at once). */
static void mark_threads(void) {
    u64 id = 0;
    if (R_SUCCEEDED(svcGetThreadId(&id, CUR_THREAD_HANDLE))) s_main_tid = id;
    s32 prio = 0x2C;
    svcGetThreadPriority(&prio, CUR_THREAD_HANDLE);
    static u8 probe_stack[0x100] __attribute__((aligned(16)));
    Handle h = INVALID_HANDLE;
    if (R_SUCCEEDED(svcCreateThread(&h, (void*)probe_entry, NULL, probe_stack + sizeof probe_stack, prio, -2))) {
        if (R_SUCCEEDED(svcGetThreadId(&id, h)) && id > s_main_tid) s_first_tid = id;
        svcCloseHandle(h);
    }
}

int nxmem_thread_is_leftover(void) {
    if (!s_first_tid) return 0;
    u64 id = 0;
    if (R_FAILED(svcGetThreadId(&id, CUR_THREAD_HANDLE))) return 0;
    return id != s_main_tid && id < s_first_tid;
}

void nxmem_initheap(nxmem_heap* h, uint64_t min_clean) {
    mark_threads();
    void* addr = NULL;
    size_t size = 0;
    int chained = envHasHeapOverride();
    if (chained) {
        addr = envGetHeapOverrideAddr();
        size = envGetHeapOverrideSize();
    } else {
        /* libnx's own __libnx_initheap */
        if (__nx_heap_size == 0) {
            u64 avail = 0, used = 0;
            svcGetInfo(&avail, InfoType_TotalMemorySize, CUR_PROCESS_HANDLE, 0);
            svcGetInfo(&used, InfoType_UsedMemorySize, CUR_PROCESS_HANDLE, 0);
            if (avail > used + 0x200000) size = (avail - used - 0x200000) & ~(u64)0x1FFFFF;
            if (size == 0) size = 0x2000000 * 16;
        } else {
            size = __nx_heap_size;
        }
        if (R_FAILED(svcSetHeapSize(&addr, size))) diagAbortWithResult(MAKERESULT(Module_Libnx, LibnxError_HeapAllocFailed));
    }
    uint64_t lo = (uint64_t)(uintptr_t)addr;
    nxmem_heap_plan(h, nxmem_query_svc, NULL, lo, lo + size, chained, min_clean);
    fake_heap_start = (char*)(uintptr_t)h->lo;
    fake_heap_end = (char*)(uintptr_t)h->hi;
}

int nxmem_query_svc(void* user, uint64_t addr, nxmem_block* out) {
    (void)user;
    MemoryInfo mi;
    u32 pi = 0;
    if (R_FAILED(svcQueryMemory(&mi, &pi, addr))) return 0;
    out->addr = mi.addr;
    out->size = mi.size;
    out->type = mi.type;
    out->attr = mi.attr;
    out->perm = mi.perm;
    return 1;
}
#endif
