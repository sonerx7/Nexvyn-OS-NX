/* Nexvyn compat layer - mmap family on top of the heap.
 *
 * A mapping is a 4 KiB aligned heap block. File mappings read the file into it; MAP_SHARED + PROT_WRITE writes the
 * block back on msync() and munmap(). Partial munmap() keeps the block until every page of it is released.
 * MAP_FIXED works inside memory that mmap() returned earlier; protections are recorded but not enforced;
 * PROT_EXEC is refused (the JIT service is a later Native SDK feature). Windowed ports may opt in to sparse
 * anonymous private MAP_NORESERVE mappings with NEXVYN_VM_MMAP=1. */
#include <errno.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#include "nxc_internal.h"

#if NXC_WINDOWED && (defined(__SWITCH__) || defined(NXC_TEST_VM))
#define NXC_VM_MMAP 1
#include <nexvyn/nxn_vm.h>
#ifdef __SWITCH__
#pragma weak nxn_vm_reserve
#pragma weak nxn_vm_get
#pragma weak nxn_vm_decommit
#pragma weak nxn_vm_protect
#pragma weak nxn_vm_release
#endif
#else
#define NXC_VM_MMAP 0
#endif

typedef struct nxc_map {
    struct nxc_map* next;
    uint8_t* base;
    size_t len;          /* page multiple */
    int prot;
    int shared_file;     /* write back to fd on msync / munmap */
    int fd;              /* dup'ed descriptor of a shared writable file mapping, else -1 */
    off_t off;
    size_t file_bytes;   /* bytes of the mapping that belong to the file (the rest is zero tail) */
    uint8_t* live;       /* one bit per page: not unmapped yet */
    size_t live_pages;
#if NXC_VM_MMAP
    nxn_vm_region* vm;
#endif
} nxc_map;

static Mutex g_map_mu;
static nxc_map* g_maps;

static size_t round_up(size_t n) { return (n + NXC_PAGE - 1) & ~(size_t)(NXC_PAGE - 1); }

static nxc_map* find_locked(const uint8_t* p) {
    for (nxc_map* m = g_maps; m; m = m->next) {
        if (p >= m->base && p < m->base + m->len) return m;
    }
    return NULL;
}

static int live_get(const nxc_map* m, size_t page) { return (m->live[page >> 3] >> (page & 7)) & 1; }

static void live_clear(nxc_map* m, size_t page) {
    if (live_get(m, page)) {
        m->live[page >> 3] &= (uint8_t)~(1u << (page & 7));
        m->live_pages--;
    }
}

static void live_set_range(nxc_map* m, size_t first, size_t count) {
    for (size_t i = first; i < first + count; i++) {
        if (!live_get(m, i)) {
            m->live[i >> 3] |= (uint8_t)(1u << (i & 7));
            m->live_pages++;
        }
    }
}

static int read_file_into(int fd, off_t off, uint8_t* dst, size_t len, size_t* got) {
    off_t save = lseek(fd, 0, SEEK_CUR);
    if (save < 0 || lseek(fd, off, SEEK_SET) < 0) return -1;
    size_t total = 0;
    while (total < len) {
        ssize_t n = read(fd, dst + total, len - total);
        if (n < 0) {
            if (errno == EINTR) continue;
            lseek(fd, save, SEEK_SET);
            return -1;
        }
        if (n == 0) break;
        total += (size_t)n;
    }
    lseek(fd, save, SEEK_SET);
    *got = total;
    return 0;
}

static int write_back(int fd, off_t off, const uint8_t* src, size_t len) {
    off_t save = lseek(fd, 0, SEEK_CUR);
    if (save < 0 || lseek(fd, off, SEEK_SET) < 0) return -1;
    size_t total = 0;
    while (total < len) {
        ssize_t n = write(fd, src + total, len - total);
        if (n <= 0) {
            if (n < 0 && errno == EINTR) continue;
            lseek(fd, save, SEEK_SET);
            return -1;
        }
        total += (size_t)n;
    }
    lseek(fd, save, SEEK_SET);
    return 0;
}

/* Writes the part of m that lies in [from, to) back to its file. Lock held. */
static int flush_range_locked(nxc_map* m, const uint8_t* from, const uint8_t* to) {
    if (!m->shared_file || m->fd < 0) return 0;
    size_t a = (size_t)(from - m->base), b = (size_t)(to - m->base);
    if (a >= m->file_bytes) return 0;
    if (b > m->file_bytes) b = m->file_bytes;
    if (b <= a) return 0;
    return write_back(m->fd, m->off + (off_t)a, m->base + a, b - a);
}

static void free_map(nxc_map* m) {
    if (m->fd >= 0) close(m->fd);
#if NXC_VM_MMAP
    if (m->vm) nxn_vm_release(m->vm);
    else
#endif
    free(m->base);
    free(m->live);
    free(m);
}

static void unlink_locked(nxc_map* m) {
    for (nxc_map** p = &g_maps; *p; p = &(*p)->next) {
        if (*p == m) {
            *p = m->next;
            return;
        }
    }
}

#if NXC_VM_MMAP
static int vm_errno(nxn_result r) {
    if (r == NXN_OK) return 0;
    if (r == NXN_ERR_UNSUPPORTED) return ENOTSUP;
    if (r == NXN_ERR_INVALID) return EINVAL;
    if (r == NXN_ERR_SYSTEM) return EIO;
    if (r == NXN_ERR_IO) return EFAULT; /* Permissions could not be restored; app cannot continue using this region. */
    return ENOMEM;
}

static uint32_t vm_prot(int prot) {
    if (prot & PROT_WRITE) return NXN_VM_PROT_RW;
    return (prot & PROT_READ) ? NXN_VM_PROT_R : NXN_VM_PROT_NONE;
}

static int vm_apply(nxc_map* m, size_t at, size_t len, uint32_t prot) {
    return vm_errno(nxn_vm_protect(m->vm, at, len, NXN_VM_PROT_COMMIT | prot));
}

static void* vm_mmap(size_t len, int prot) {
#ifdef __SWITCH__
    if (!nxn_vm_reserve || !nxn_vm_get || !nxn_vm_decommit || !nxn_vm_protect || !nxn_vm_release)
        return (errno = ENOTSUP, MAP_FAILED);
#endif
    nxn_vm_region* region = NULL;
    nxn_result r = nxn_vm_reserve(len, NXN_VM_NEED_PAGE_COMMIT, &region);
    if (r != NXN_OK) return (errno = vm_errno(r), MAP_FAILED);
    nxn_vm_info info = {.size = sizeof info};
    r = nxn_vm_get(region, &info);
    if (r != NXN_OK || !(info.abilities & NXN_VM_CAN_PAGE_COMMIT) || info.commit_granule != NXC_PAGE) {
        nxn_vm_release(region);
        return (errno = r == NXN_OK ? ENOTSUP : vm_errno(r), MAP_FAILED);
    }
    nxc_map* m = calloc(1, sizeof *m);
    if (!m) {
        nxn_vm_release(region);
        return (errno = ENOMEM, MAP_FAILED);
    }
    const size_t pages = len / NXC_PAGE;
    m->fd = -1;
    m->vm = region;
    m->base = info.base;
    m->len = len;
    m->prot = prot;
    m->live = calloc((pages + 7) / 8, 1);
    int err = m->live ? 0 : ENOMEM;
    if (!err && vm_prot(prot) != NXN_VM_PROT_NONE) err = vm_apply(m, 0, len, vm_prot(prot));
    if (err) {
        free_map(m);
        return (errno = err, MAP_FAILED);
    }
    live_set_range(m, 0, pages);
    mutexLock(&g_map_mu);
    m->next = g_maps;
    g_maps = m;
    mutexUnlock(&g_map_mu);
    return info.base;
}
#endif

void* mmap(void* addr, size_t length, int prot, int flags, int fd, off_t offset) {
    if (length == 0) return (errno = EINVAL, MAP_FAILED);
    int shared = flags & MAP_SHARED, priv = flags & MAP_PRIVATE;
    if ((shared != 0) == (priv != 0)) return (errno = EINVAL, MAP_FAILED);
    if (prot & PROT_EXEC) {
        nxc_unsupported("mmap(PROT_EXEC)", "executable memory needs the JIT service (a later Native SDK release); the call fails with ENOTSUP");
        return (errno = ENOTSUP, MAP_FAILED);
    }
    int anon = (flags & MAP_ANONYMOUS) != 0;
    if (!anon && fd < 0) return (errno = EBADF, MAP_FAILED);
    if (!anon && (offset < 0 || (offset & (NXC_PAGE - 1)))) return (errno = EINVAL, MAP_FAILED);
    size_t len = round_up(length);
    if (len < length) return (errno = ENOMEM, MAP_FAILED);
#if NXC_VM_MMAP
    if (anon && priv && (flags & MAP_NORESERVE) && !(flags & MAP_FIXED)) {
        const char* opt_in = getenv("NEXVYN_VM_MMAP");
        if (opt_in && !strcmp(opt_in, "1")) return vm_mmap(len, prot);
    }
#endif

    /* MAP_FIXED: only inside memory this layer handed out earlier (same block, zero-filled / re-read in place). */
    uint8_t* base = NULL;
    int fixed_in_place = 0;
    if (flags & MAP_FIXED) {
        if ((uintptr_t)addr & (NXC_PAGE - 1)) return (errno = EINVAL, MAP_FAILED);
        mutexLock(&g_map_mu);
        nxc_map* m = find_locked((uint8_t*)addr);
        int inside = m && len <= (size_t)(m->base + m->len - (uint8_t*)addr);
#if NXC_VM_MMAP
        if (inside && m->vm) {
            int err = ENOTSUP;
            if (anon && priv) {
                size_t at = (size_t)((uint8_t*)addr - m->base);
                err = vm_apply(m, at, len, vm_prot(prot) | NXN_VM_PROT_REPLACE);
                if (!err) live_set_range(m, at / NXC_PAGE, len / NXC_PAGE);
            }
            mutexUnlock(&g_map_mu);
            if (err == EFAULT) abort();
            return err ? (errno = err, MAP_FAILED) : addr;
        }
#endif
        if (inside) {
            size_t first = (size_t)((uint8_t*)addr - m->base) / NXC_PAGE;
            if (m->shared_file) flush_range_locked(m, (uint8_t*)addr, (uint8_t*)addr + len);
            live_set_range(m, first, len / NXC_PAGE);
        }
        mutexUnlock(&g_map_mu);
        if (!inside) {
            nxc_unsupported("mmap(MAP_FIXED)", "only addresses inside an earlier mmap() block can be replaced; reserve the whole range first");
            return (errno = ENOMEM, MAP_FAILED);
        }
        base = (uint8_t*)addr;
        fixed_in_place = 1;
    } else {
        base = (uint8_t*)aligned_alloc(NXC_PAGE, len);
        if (!base) return (errno = ENOMEM, MAP_FAILED);
    }

    size_t got = 0;
    if (!anon) {
        if (read_file_into(fd, offset, base, len, &got) != 0) {
            int e = errno ? errno : EIO;
            if (!fixed_in_place) free(base);
            return (errno = e, MAP_FAILED);
        }
    }
    memset(base + got, 0, len - got);
    if (fixed_in_place) return base;

    nxc_map* m = (nxc_map*)calloc(1, sizeof *m);
    size_t pages = len / NXC_PAGE;
    uint8_t* live = (uint8_t*)calloc((pages + 7) / 8, 1);
    if (!m || !live) {
        free(m);
        free(live);
        free(base);
        return (errno = ENOMEM, MAP_FAILED);
    }
    m->base = base;
    m->len = len;
    m->prot = prot;
    m->fd = -1;
    m->off = offset;
    m->live = live;
    m->file_bytes = got;
    live_set_range(m, 0, pages);
    if (!anon && shared && (prot & PROT_WRITE)) {
        m->fd = dup(fd);
        if (m->fd < 0) {
            int e = errno;
            free_map(m); /* Not published: release all backing without closing the caller's fd. */
            return (errno = e, MAP_FAILED);
        }
        m->shared_file = 1;
    }
    mutexLock(&g_map_mu);
    m->next = g_maps;
    g_maps = m;
    mutexUnlock(&g_map_mu);
    return base;
}

int munmap(void* addr, size_t length) {
    if (((uintptr_t)addr & (NXC_PAGE - 1)) || length == 0) return NXC_FAIL(EINVAL);
    size_t len = round_up(length);
    if (len < length || len > UINTPTR_MAX - (uintptr_t)addr) return NXC_FAIL(EINVAL);
    uint8_t* a = (uint8_t*)addr;
    int rc = 0;
    mutexLock(&g_map_mu);
    for (size_t done = 0; done < len;) {
        nxc_map* m = find_locked(a + done);
        if (!m) {
            done += NXC_PAGE; /* POSIX: unmapping an unmapped page is not an error */
            continue;
        }
        size_t first = (size_t)(a + done - m->base) / NXC_PAGE;
        size_t end = (size_t)((a + len) - m->base) / NXC_PAGE;
        if (end > m->len / NXC_PAGE) end = m->len / NXC_PAGE;
#if NXC_VM_MMAP
        if (m->vm) {
            size_t at = first * NXC_PAGE;
            size_t bytes = (end - first) * NXC_PAGE;
            int err = vm_apply(m, at, bytes, NXN_VM_PROT_NONE);
            if (err == EFAULT) {
                mutexUnlock(&g_map_mu);
                abort();
            }
            if (err || nxn_vm_decommit(m->vm, at, bytes) != NXN_OK) {
                rc = -1;
                done += bytes;
                continue;  /* Keep the mapping and its live pages available for a retry. */
            }
        }
#endif
        if (flush_range_locked(m, m->base + first * NXC_PAGE, m->base + end * NXC_PAGE) != 0) rc = -1;
        for (size_t p = first; p < end; p++) live_clear(m, p);
        done += (end - first) * NXC_PAGE;
        if (m->live_pages == 0) {
            unlink_locked(m);
            free_map(m);
        }
    }
    mutexUnlock(&g_map_mu);
    if (rc) errno = EIO;
    return rc;
}

int mprotect(void* addr, size_t length, int prot) {
    if ((uintptr_t)addr & (NXC_PAGE - 1)) return NXC_FAIL(EINVAL);
    if (prot & PROT_EXEC) {
        nxc_unsupported("mprotect(PROT_EXEC)", "executable memory needs the JIT service (a later Native SDK release); the call fails with ENOTSUP");
        return NXC_FAIL(ENOTSUP);
    }
    if (length == 0) return 0;
    size_t len = round_up(length);
    if (len < length || len > UINTPTR_MAX - (uintptr_t)addr) return NXC_FAIL(EINVAL);
    mutexLock(&g_map_mu);
    for (size_t check = 0; check < len; check += NXC_PAGE) {
        nxc_map* m = find_locked((uint8_t*)addr + check);
        if (!m || !live_get(m, (size_t)((uint8_t*)addr + check - m->base) / NXC_PAGE)) {
            mutexUnlock(&g_map_mu);
            return NXC_FAIL(ENOMEM);
        }
    }
    for (size_t done = 0; done < len; done += NXC_PAGE) {
        nxc_map* m = find_locked((uint8_t*)addr + done);
#if NXC_VM_MMAP
        if (m->vm) {
            size_t at = (size_t)((uint8_t*)addr + done - m->base);
            size_t end = at + NXC_PAGE;
            while (end < m->len && done + end - at < len && live_get(m, end / NXC_PAGE))
                end += NXC_PAGE;
            int err = vm_apply(m, at, end - at, vm_prot(prot));
            if (err) {
                mutexUnlock(&g_map_mu);
                if (err == EFAULT) abort();
                return NXC_FAIL(err);
            }
            done += end - at - NXC_PAGE;
        }
#endif
        m->prot = prot; /* advisory: recorded, never enforced for heap mappings */
    }
    mutexUnlock(&g_map_mu);
    return 0;
}

int msync(void* addr, size_t length, int flags) {
    if (((uintptr_t)addr & (NXC_PAGE - 1)) || ((flags & MS_ASYNC) && (flags & MS_SYNC))) return NXC_FAIL(EINVAL);
    size_t len = round_up(length);
    int rc = 0, found = 0;
    mutexLock(&g_map_mu);
    for (size_t done = 0; done < len;) {
        nxc_map* m = find_locked((uint8_t*)addr + done);
        if (!m) {
            done += NXC_PAGE;
            continue;
        }
        found = 1;
        const uint8_t* from = (uint8_t*)addr + done;
        const uint8_t* to = (uint8_t*)addr + len;
        if (to > m->base + m->len) to = m->base + m->len;
        if (flush_range_locked(m, from, to) != 0) rc = -1;
        done += (size_t)(to - from);
    }
    mutexUnlock(&g_map_mu);
    if (!found && length) return NXC_FAIL(ENOMEM);
    return rc ? NXC_FAIL(EIO) : 0;
}

int madvise(void* addr, size_t length, int advice) {
    if ((uintptr_t)addr & (NXC_PAGE - 1)) return NXC_FAIL(EINVAL);
    if (advice == MADV_DONTNEED && length) {
        size_t len = round_up(length);
        mutexLock(&g_map_mu);
        for (size_t done = 0; done < len; done += NXC_PAGE) {
            nxc_map* m = find_locked((uint8_t*)addr + done);
#if NXC_VM_MMAP
            if (m && m->vm) continue;  /* The caller may advise an inaccessible page. */
#endif
            if (m && !m->shared_file && m->file_bytes == 0) memset((uint8_t*)addr + done, 0, NXC_PAGE);
        }
        mutexUnlock(&g_map_mu);
    }
    return 0; /* everything else is a hint */
}

int posix_madvise(void* addr, size_t length, int advice) {
    int r = madvise(addr, length, advice == POSIX_MADV_DONTNEED ? MADV_NORMAL : advice); /* POSIX flavour never zeroes */
    return r ? errno : 0;
}

int mlock(const void* addr, size_t length) { (void)addr; (void)length; return 0; }
int munlock(const void* addr, size_t length) { (void)addr; (void)length; return 0; }
int mlockall(int flags) { (void)flags; return 0; }
int munlockall(void) { return 0; }

void* mremap(void* old_addr, size_t old_size, size_t new_size, int flags, ...) {
    if (new_size == 0 || ((uintptr_t)old_addr & (NXC_PAGE - 1)) || (flags & MREMAP_FIXED)) return (errno = EINVAL, MAP_FAILED);
    size_t olds = round_up(old_size), news = round_up(new_size);
    mutexLock(&g_map_mu);
    nxc_map* m = find_locked((uint8_t*)old_addr);
#if NXC_VM_MMAP
    if (m && m->vm) {
        mutexUnlock(&g_map_mu);
        return (errno = ENOTSUP, MAP_FAILED);
    }
#endif
    int ok = m && m->base == (uint8_t*)old_addr && m->len == olds && !m->shared_file && m->file_bytes == 0 && m->live_pages == olds / NXC_PAGE;
    int prot = ok ? m->prot : 0;
    mutexUnlock(&g_map_mu);
    if (!ok) return (errno = EINVAL, MAP_FAILED);
    if (news == olds) return old_addr;
    if (news < olds) {
        munmap((uint8_t*)old_addr + news, olds - news);
        return old_addr;
    }
    if (!(flags & MREMAP_MAYMOVE)) return (errno = ENOMEM, MAP_FAILED);
    void* p = mmap(NULL, news, prot, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) return p;
    memcpy(p, old_addr, olds);
    munmap(old_addr, olds);
    return p;
}

#if NXC_WINDOWED
/* App end (atexit): write back and free heap-backed mappings. VM-backed mappings are left for the host (vmSweep)
 * to reclaim after kernel thread termination is confirmed, because worker threads may still run during atexit. */
void nxc__mman_releaseall(void) {
    mutexLock(&g_map_mu);
    nxc_map** p = &g_maps;
    while (*p) {
        nxc_map* m = *p;
#if NXC_VM_MMAP
        if (m->vm) {
            p = &m->next;
            continue;
        }
#endif
        flush_range_locked(m, m->base, m->base + m->len);
        *p = m->next;
        free_map(m);
    }
    mutexUnlock(&g_map_mu);
}
#endif
