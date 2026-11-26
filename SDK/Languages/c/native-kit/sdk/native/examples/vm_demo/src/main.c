#include <nexvyn/nxn_vm.h>

#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define G NXN_VM_COMMIT_GRANULE
#define PAGE NXN_VM_PROTECT_GRANULE
#define MIB (1ull << 20)

enum { WRITERS = 4, FULL_STRESS_GRANULES = 600 * (1 << 20) / G, CHURN_PER_WRITER = 256 };

typedef struct {
    nxn_vm_region* vm;
    uint8_t* base;
    size_t granules;
    unsigned id;
    int ok;
} Writer;

static int filled(const uint8_t* base, size_t size, uint8_t expected) {
    for (size_t i = 0; i < size; i++)
        if (base[i] != expected) return 0;
    return 1;
}

static void* write_shard(void* arg) {
    Writer* w = arg;
    const size_t count = w->granules;
    const size_t first = (size_t)w->id * count;
    uint8_t* expected = malloc(count);
    if (!expected) return NULL;
    uint32_t seed = 1234u + w->id;
    for (size_t g = 0; g < count; g++) {
        expected[g] = 1 + (uint8_t)((g + w->id) % 255);
        memset(w->base + (first + g) * G, expected[g], G);
    }
    for (unsigned n = 0; n < CHURN_PER_WRITER; n++) {
        seed = seed * 1664525u + 1013904223u;
        size_t g = seed % count;
        size_t offset = (first + g) * G;
        uint8_t* p = w->base + offset;
        if (!filled(p, G, expected[g]) || nxn_vm_decommit(w->vm, offset, G) != NXN_OK ||
            nxn_vm_commit(w->vm, offset, G) != NXN_OK || !filled(p, G, 0)) {
            free(expected);
            return NULL;
        }
        expected[g] = 1 + (uint8_t)((seed >> 16) % 255);
        memset(p, expected[g], G);
    }
    for (size_t g = 0; g < count; g++) {
        if (!filled(w->base + (first + g) * G, G, expected[g])) {
            free(expected);
            return NULL;
        }
    }
    free(expected);
    w->ok = 1;
    return NULL;
}

static int stress(nxn_vm_region* vm, uint8_t* base, size_t total_granules) {
    size_t per_writer = total_granules / WRITERS;
    size_t used = per_writer * WRITERS;
    if (!used) return 1;
    nxn_result r = nxn_vm_commit(vm, 0, (uint64_t)used * G);
    printf("VMDEMO stress_mib=%llu commit_rc=%d\n", (unsigned long long)(((uint64_t)used * G) / MIB), r);
    if (r != NXN_OK) return 0;
    pthread_t threads[WRITERS];
    Writer writers[WRITERS];
    unsigned started = 0;
    while (started < WRITERS) {
        writers[started] = (Writer){.vm = vm, .base = base, .granules = per_writer, .id = started};
        if (pthread_create(&threads[started], NULL, write_shard, &writers[started])) break;
        started++;
    }
    int ok = started == WRITERS;
    for (unsigned i = 0; i < started; i++) {
        if (pthread_join(threads[i], NULL) || !writers[i].ok) ok = 0;
    }
    printf("VMDEMO writers=%u churn_per_writer=%u verified=%d\n", started, CHURN_PER_WRITER, ok);
    return ok;
}

static int protect_page(nxn_vm_region* vm, uint8_t* base) {
    if (nxn_vm_protect(vm, PAGE, PAGE, NXN_VM_PROT_R) != NXN_OK || base[PAGE] != 0 ||
        nxn_vm_protect(vm, PAGE, PAGE, NXN_VM_PROT_NONE) != NXN_OK) return 0;
    base[PAGE - 1] = 0x11;
    base[2 * PAGE] = 0x22;
    return nxn_vm_protect(vm, PAGE, PAGE, NXN_VM_PROT_RW) == NXN_OK && base[PAGE] == 0 &&
        base[PAGE - 1] == 0x11 && base[2 * PAGE] == 0x22;
}

int main(void) {
    nxn_vm_region* vm = NULL;
    nxn_vm_region* guard = NULL;
    nxn_vm_info info = NXN_STRUCT_INIT(nxn_vm_info);
    nxn_result r = nxn_vm_reserve(1024 * MIB, NXN_VM_NEED_SPARSE, &vm);
    int full = r == NXN_OK;
    int ok = 0;
    printf("VMDEMO reserve_mib=1024 rc=%d\n", r);
    if (!full) {
        static const uint64_t fallbacks[] = {256 * MIB, 128 * MIB, 64 * MIB, 2 * G};
        for (size_t i = 0; i < sizeof fallbacks / sizeof fallbacks[0]; i++) {
            r = nxn_vm_reserve(fallbacks[i], NXN_VM_NEED_SPARSE, &vm);
            printf("VMDEMO fallback_kib=%llu rc=%d\n", (unsigned long long)(fallbacks[i] >> 10), r);
            if (r == NXN_OK) break;
        }
        if (r != NXN_OK) {
            puts("VMDEMO END status=UNSUPPORTED");
            fflush(stdout);
            return 0;
        }
    }
    if (nxn_vm_get(vm, &info) != NXN_OK) goto done;
    printf("VMDEMO backend=%u abilities=%u bytes=%llu initial_charge=%llu\n",
           info.backend, info.abilities, (unsigned long long)info.bytes, (unsigned long long)info.charged);
    if (info.charged || info.committed || nxn_vm_commit(vm, 0, 2 * G) != NXN_OK) goto done;
    uint8_t* base = info.base;
    const uint8_t payload[] = {1, 8, 3, 9, 7, 2, 5, 4};
    memcpy(base + G - 4, payload, sizeof payload);
    if (memcmp(base + G - 4, payload, sizeof payload) || nxn_vm_decommit(vm, G, G) != NXN_OK ||
        nxn_vm_commit(vm, G, G) != NXN_OK || !filled(base + G, G, 0))
        goto done;
    if (nxn_vm_get(vm, &info) != NXN_OK || info.charged != 2 * G || info.committed != 2 * G) goto done;
    puts("VMDEMO cross_granule_copy=PASS recommit_zero=PASS");
    if (info.abilities & NXN_VM_CAN_PROTECT) {
        if (!protect_page(vm, base)) goto done;
        printf("VMDEMO protect_4k=PASS backend=%u\n", info.backend);
    } else {
        if (nxn_vm_protect(vm, PAGE, PAGE, NXN_VM_PROT_R) != NXN_ERR_UNSUPPORTED) goto done;
        nxn_vm_info guard_info = NXN_STRUCT_INIT(nxn_vm_info);
        if (nxn_vm_reserve(G, NXN_VM_NEED_PROTECT, &guard) != NXN_OK ||
            nxn_vm_get(guard, &guard_info) != NXN_OK || !(guard_info.abilities & NXN_VM_CAN_PROTECT) ||
            nxn_vm_commit(guard, 0, G) != NXN_OK || !protect_page(guard, guard_info.base))
            goto done;
        printf("VMDEMO protect_4k=PASS backend=%u\n", guard_info.backend);
        nxn_vm_release(guard);
        guard = NULL;
    }
    size_t stress_granules = full ? (size_t)FULL_STRESS_GRANULES : (info.bytes >= 64 * MIB ? (size_t)(info.bytes / G) : 0);
    if (stress_granules > (size_t)FULL_STRESS_GRANULES) stress_granules = (size_t)FULL_STRESS_GRANULES;
    ok = stress(vm, base, stress_granules);
done:
    nxn_vm_release(guard);
    nxn_vm_release(vm);
    printf("VMDEMO END status=%s\n", ok ? (full ? "PASS" : "LIMITED") : "FAIL");
    fflush(stdout);
    return ok ? 0 : 1;
}
