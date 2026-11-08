/* Nexvyn Native SDK library - the heap guard at the app's start: the same one Nexvyn OS applies to itself
 * (sdk/native/loader/nxmem.c, one implementation).
 *
 * The homebrew loader runs Nexvyn OS and the app in one process with one heap. What Nexvyn OS (or any program before
 * the app) left locked there, a thread stack, transfer memory, JIT code, faults the app's first write to it. And the
 * loader reads the next program's image (Nexvyn OS, about 70 MB) into the first bytes of that heap when the app ends:
 * a page the app leaves locked there keeps Nexvyn OS from starting (console 2026-11-04: greetlib's library code pages
 * were there, and Nexvyn OS did not come back). So, before malloc exists, the app's malloc gets:
 *   - nothing of the first NXMEM_LOADER_RESERVE (128 MB) of the heap the loader handed over (heaps of 1 GB or more),
 *   - of the rest, the largest clean run when the program before left pages locked there.
 * Every allocation comes from that range: malloc, thread stacks (libnx's threadCreate allocates them with memalign),
 * the shared-library loader's JIT memory (nxelf_map_jit), the audio and GPU buffers. An app with its own
 * __libnx_initheap keeps it (ours is weak), and the guard is off then. */
#include "nxn_internal.h"
#include "nxmem.h"
#include <stdio.h>

static nxmem_heap g_heap;
static int g_heap_guarded;
volatile unsigned nxn__leftover_faults;

/* Weak like libnx's; ours is linked first (libnexvyn comes before libnx), so it replaces libnx's default. */
__attribute__((weak)) void __libnx_initheap(void) {
    nxmem_initheap(&g_heap, NXMEM_MIN_CLEAN);
    g_heap_guarded = 1;
}

void nxn__heap_log(void) {
    if (!g_heap_guarded) {
        nxn_log(NXN_LOG_INFO, "heap: the app sets its heap up itself, the heap guard is off");
        return;
    }
    if (!g_heap.chained) return; /* the kernel's heap: nobody was here before */
    const nxmem_heap* h = &g_heap;
    nxn_log(NXN_LOG_INFO, "heap: %llu MB from the loader, malloc uses +0x%llx..+0x%llx (%llu MB); the first %llu MB stay "
            "free for the next program's image", (unsigned long long)((h->offer_hi - h->offer_lo) >> 20),
            (unsigned long long)(h->lo - h->offer_lo), (unsigned long long)(h->hi - h->offer_lo),
            (unsigned long long)((h->hi - h->lo) >> 20), (unsigned long long)(h->reserved >> 20));
    if (!h->start.dirty_count) return;
    nxmem_report r = h->start;
    r.lo = h->offer_lo; /* offsets from the start of the heap */
    char d[420];
    nxmem_describe(&r, d, sizeof d);
    nxn_log(NXN_LOG_WARN, "heap: the program before left %s; %s", d,
            h->limited ? "malloc uses the largest clean run" : "no clean run of 256 MB, the rest of the heap is used");
}
