/* Nexvyn compat layer - virtual file descriptors (pipe, eventfd, /dev/null ...) and fd readiness (poll, select, fcntl,
 * ioctl).
 *
 * The descriptors live in a private newlib devoptab ("nxcfd:"), so read(), write(), close(), dup(), fstat() work on
 * them like on any file. poll() / select() look at every descriptor: virtual ones are checked here, sockets go to the
 * libnx poll (--wrap=poll keeps it reachable as __real_poll), anything else counts as always ready. */
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/ioctl.h>
#include <sys/iosupport.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <signal.h>
#include <stdio.h>

#include "nxc_internal.h"
#include "nxc_ring.h"

#define PIPE_CAP (64u * 1024u)
#define PIPE_ATOMIC 4096u
#define EVENT_MAX 0xfffffffffffffffeull

enum { ROLE_PIPE_R = 1, ROLE_PIPE_W = 2, ROLE_EVENT = 3, ROLE_DEV_NULL = 4, ROLE_DEV_ZERO = 5, ROLE_DEV_RANDOM = 6 };
#define IS_DEV(role) ((role) >= ROLE_DEV_NULL)

typedef struct nxc_chan {
    nxc_ring ring;       /* pipes */
    uint64_t counter;    /* eventfd */
    int semaphore;       /* eventfd: EFD_SEMAPHORE */
    int readers, writers; /* open pipe ends */
    int ends;            /* open descriptors (frees at 0) */
} nxc_chan;

typedef struct nxc_vfile {
    nxc_chan* ch;
    int role;
    int nonblock;
    int cloexec;
    int acc;             /* pseudo devices: O_RDONLY / O_WRONLY / O_RDWR */
} nxc_vfile;

int __real_fcntl(int fd, int cmd, ...);
int __real_poll(struct pollfd* fds, nfds_t nfds, int timeout);
int __real_ioctl(int fd, unsigned long req, ...);

/* ---- devoptab ---- */

static int g_dev = -1;

static int errno_r(struct _reent* r, int e) {
    r->_errno = e;
    return -1;
}

static ssize_t vf_read(struct _reent* r, void* fd, char* ptr, size_t len) {
    nxc_vfile* v = (nxc_vfile*)fd;
    nxc_chan* c = v->ch;
    if (v->role == ROLE_PIPE_W) return errno_r(r, EBADF);
    if (IS_DEV(v->role)) {
        if (v->acc == O_WRONLY) return errno_r(r, EBADF);
        if (v->role == ROLE_DEV_NULL) return 0; /* end of file */
        if (v->role == ROLE_DEV_ZERO) memset(ptr, 0, len);
        else randomGet(ptr, len); /* the console's CSPRNG: /dev/random and /dev/urandom never block */
        return (ssize_t)len;
    }
    if (len == 0) return 0;
    if (v->role == ROLE_EVENT && len < 8) return errno_r(r, EINVAL);
    mutexLock(&g_nxc_mu);
    for (;;) {
        if (v->role == ROLE_EVENT) {
            if (c->counter) {
                uint64_t val = c->semaphore ? 1 : c->counter;
                c->counter -= val;
                memcpy(ptr, &val, 8);
                nxc_wake_all();
                mutexUnlock(&g_nxc_mu);
                return 8;
            }
        } else {
            if (c->ring.len) {
                size_t n = nxc_ring_read(&c->ring, ptr, len);
                nxc_wake_all();
                mutexUnlock(&g_nxc_mu);
                return (ssize_t)n;
            }
            if (c->writers == 0) {
                mutexUnlock(&g_nxc_mu);
                return 0; /* end of file */
            }
        }
        if (v->nonblock) {
            mutexUnlock(&g_nxc_mu);
            return errno_r(r, EAGAIN);
        }
        if (nxc_block_locked(0, 0, 1) == NXC_WAIT_INTR) {
            mutexUnlock(&g_nxc_mu);
            return errno_r(r, EINTR);
        }
    }
}

static ssize_t vf_write(struct _reent* r, void* fd, const char* ptr, size_t len) {
    nxc_vfile* v = (nxc_vfile*)fd;
    nxc_chan* c = v->ch;
    if (v->role == ROLE_PIPE_R) return errno_r(r, EBADF);
    if (IS_DEV(v->role)) return v->acc == O_RDONLY ? errno_r(r, EBADF) : (ssize_t)len; /* a sink: everything is accepted */
    if (len == 0) return 0;
    if (v->role == ROLE_EVENT) {
        uint64_t val;
        if (len < 8) return errno_r(r, EINVAL);
        memcpy(&val, ptr, 8);
        if (val == UINT64_MAX) return errno_r(r, EINVAL);
        mutexLock(&g_nxc_mu);
        for (;;) {
            if (val <= EVENT_MAX - c->counter) {
                c->counter += val;
                nxc_wake_all();
                mutexUnlock(&g_nxc_mu);
                return 8;
            }
            if (v->nonblock) {
                mutexUnlock(&g_nxc_mu);
                return errno_r(r, EAGAIN);
            }
            if (nxc_block_locked(0, 0, 1) == NXC_WAIT_INTR) {
                mutexUnlock(&g_nxc_mu);
                return errno_r(r, EINTR);
            }
        }
    }
    size_t done = 0;
    mutexLock(&g_nxc_mu);
    while (done < len) {
        if (c->readers == 0) {
            mutexUnlock(&g_nxc_mu);
            raise(SIGPIPE); /* ignored unless the program installed a handler */
            return done ? (ssize_t)done : errno_r(r, EPIPE);
        }
        size_t room = nxc_ring_free(&c->ring);
        size_t want = len - done;
        /* writes up to PIPE_ATOMIC bytes go in one piece; bigger ones may be split */
        int ready = want <= PIPE_ATOMIC ? room >= want : room > 0;
        if (ready) {
            done += nxc_ring_write(&c->ring, ptr + done, want);
            nxc_wake_all();
            continue;
        }
        if (v->nonblock) {
            mutexUnlock(&g_nxc_mu);
            return done ? (ssize_t)done : errno_r(r, EAGAIN);
        }
        if (nxc_block_locked(0, 0, 1) == NXC_WAIT_INTR) {
            mutexUnlock(&g_nxc_mu);
            return done ? (ssize_t)done : errno_r(r, EINTR);
        }
    }
    mutexUnlock(&g_nxc_mu);
    return (ssize_t)done;
}

static int vf_close(struct _reent* r, void* fd) {
    nxc_vfile* v = (nxc_vfile*)fd;
    nxc_chan* c = v->ch;
    int last;
    mutexLock(&g_nxc_mu);
    if (v->role == ROLE_PIPE_R) c->readers--;
    if (v->role == ROLE_PIPE_W) c->writers--;
    last = --c->ends == 0;
    nxc_wake_all();
    mutexUnlock(&g_nxc_mu);
    if (last) {
        free(c->ring.buf);
        free(c);
    }
    v->ch = NULL;
    return 0;
}

/* Linux numbers: null 1:3, zero 1:5, random 1:8, urandom 1:9 (random and urandom share a role). */
static dev_t dev_rdev(int role) { return role == ROLE_DEV_NULL ? (1u << 8 | 3u) : role == ROLE_DEV_ZERO ? (1u << 8 | 5u) : (1u << 8 | 9u); }

static int vf_fstat(struct _reent* r, void* fd, struct stat* st) {
    nxc_vfile* v = (nxc_vfile*)fd;
    memset(st, 0, sizeof *st);
    if (IS_DEV(v->role)) {
        st->st_mode = S_IFCHR | 0666;
        st->st_rdev = dev_rdev(v->role);
        st->st_blksize = 4096;
        st->st_nlink = 1;
        return 0;
    }
    st->st_mode = S_IFIFO | 0600;
    st->st_blksize = 4096;
    st->st_nlink = 1;
    return 0;
}

static off_t vf_seek(struct _reent* r, void* fd, off_t pos, int dir) {
    if (IS_DEV(((nxc_vfile*)fd)->role)) return 0; /* the position of a character device is always 0 */
    r->_errno = ESPIPE;
    return -1;
}

static devoptab_t g_devtab = {
    .name = "nxcfd",
    .structSize = sizeof(nxc_vfile),
    .close_r = vf_close,
    .write_r = vf_write,
    .read_r = vf_read,
    .seek_r = vf_seek,
    .fstat_r = vf_fstat,
};

#if NXC_WINDOWED
/* The device table is process-wide and holds pointers into this module. Every window gets a device of its own, named
 * after the module's address (two loaded modules never overlap), and removes it when the app ends: a second app never
 * reaches the first one's code, and nothing points into an unmapped module. */
static char g_devname[24];
#endif

static int ensure_dev(void) {
    mutexLock(&g_nxc_mu);
    if (g_dev < 0) {
#if NXC_WINDOWED
        snprintf(g_devname, sizeof g_devname, "nxc%08x", (unsigned)((uintptr_t)&g_devtab >> 12));
        g_devtab.name = g_devname;
        char probe[sizeof g_devname + 2];
        snprintf(probe, sizeof probe, "%s:", g_devname);
        g_dev = AddDevice(&g_devtab);
        if (g_dev < 0) g_dev = FindDevice(probe);
        if (g_dev >= 0) nxc__win_register_exit();
#else
        g_dev = FindDevice("nxcfd:");
        if (g_dev < 0) g_dev = AddDevice(&g_devtab);
#endif
    }
    int d = g_dev;
    mutexUnlock(&g_nxc_mu);
    return d;
}

static nxc_vfile* vfile_of(int fd) {
    if (g_dev < 0) return NULL;
    __handle* h = __get_handle(fd);
    return (h && h->refcount && (int)h->device == g_dev) ? (nxc_vfile*)h->fileStruct : NULL;
}

int nxc_fd_is_virtual(int fd) { return vfile_of(fd) != NULL; }

static int new_fd(nxc_chan* c, int role, int nonblock, int cloexec) {
    int dev = ensure_dev();
    if (dev < 0) return -1;
    int fd = __alloc_handle(dev);
    if (fd < 0) return -1;
    nxc_vfile* v = (nxc_vfile*)__get_handle(fd)->fileStruct;
    v->ch = c;
    v->role = role;
    v->nonblock = nonblock;
    v->cloexec = cloexec;
    return fd;
}

int pipe2(int fds[2], int flags) {
    if (!fds) return NXC_FAIL(EFAULT);
    nxc_chan* c = (nxc_chan*)calloc(1, sizeof *c);
    void* store = malloc(PIPE_CAP);
    if (!c || !store) {
        free(c);
        free(store);
        return NXC_FAIL(ENFILE);
    }
    nxc_ring_init(&c->ring, store, PIPE_CAP);
    c->readers = c->writers = 1;
    c->ends = 2;
    int nb = (flags & O_NONBLOCK) != 0, ce = (flags & O_CLOEXEC) != 0;
    int r = new_fd(c, ROLE_PIPE_R, nb, ce);
    int w = r >= 0 ? new_fd(c, ROLE_PIPE_W, nb, ce) : -1;
    if (r < 0 || w < 0) {
        if (r >= 0) __release_handle(r);
        free(store);
        free(c);
        return NXC_FAIL(EMFILE);
    }
    fds[0] = r;
    fds[1] = w;
    return 0;
}

int pipe(int fds[2]) { return pipe2(fds, 0); }

int eventfd(unsigned int initval, int flags) {
    nxc_chan* c = (nxc_chan*)calloc(1, sizeof *c);
    if (!c) return NXC_FAIL(ENFILE);
    c->counter = initval;
    c->semaphore = (flags & EFD_SEMAPHORE) != 0;
    c->ends = 1;
    int fd = new_fd(c, ROLE_EVENT, (flags & EFD_NONBLOCK) != 0, (flags & EFD_CLOEXEC) != 0);
    if (fd < 0) {
        free(c);
        return NXC_FAIL(EMFILE);
    }
    return fd;
}

int eventfd_read(int fd, eventfd_t* value) { return read(fd, value, 8) == 8 ? 0 : -1; }
int eventfd_write(int fd, eventfd_t value) { return write(fd, &value, 8) == 8 ? 0 : -1; }

/* mkfifo has no meaning on FAT: say so instead of creating a plain file */
int mkfifo(const char* path, mode_t mode) {
    nxc_unsupported("mkfifo", "named pipes do not exist on the SD card; use pipe() inside one process");
    return NXC_FAIL(ENOSYS);
}

/* ---- fcntl / ioctl ---- */

/* F_DUPFD: the lowest free descriptor >= arg, found by duplicating until one is high enough. */
static int dup_from(int fd, long arg) {
    int tmp[64], n = 0, res = -1;
    for (; n < 64; n++) {
        int d = dup(fd);
        if (d < 0) break;
        if (d >= (int)arg) { /* the argument is an int */
            res = d;
            break;
        }
        tmp[n] = d;
    }
    while (n-- > 0) close(tmp[n]);
    return res < 0 ? NXC_FAIL(EMFILE) : res;
}

/* A descriptor that is neither ours nor a socket (the SD card, romfs, stdio): libnx's fcntl asks the socket service and
 * fails (ENOTSOCK / EBADF), so answer here. The kernel keeps no open flags for these, so the access mode is a guess:
 * stdin reads, stdout and stderr write, anything else is reported O_RDWR. */
static int fcntl_plain(int fd, int cmd, long arg) {
    __handle* h = fd >= 0 ? __get_handle(fd) : NULL;
    if (!h || !h->refcount) return NXC_FAIL(EBADF);
    const devoptab_t* dt = devoptab_list[h->device];
    if (dt && dt->name && strcmp(dt->name, "soc") == 0) return __real_fcntl(fd, cmd, arg);
    switch (cmd) {
        case F_GETFL: return fd == 0 ? O_RDONLY : fd <= 2 ? O_WRONLY : O_RDWR;
        case F_SETFL: return 0; /* there is no non-blocking mode on a file; accepted, nothing changes */
        case F_GETFD:
        case F_SETFD: return 0;
        case F_DUPFD:
#ifdef F_DUPFD_CLOEXEC
        case F_DUPFD_CLOEXEC:
#endif
            return dup_from(fd, arg);
        default: return NXC_FAIL(EINVAL);
    }
}

int __wrap_fcntl(int fd, int cmd, ...) {
    va_list ap;
    va_start(ap, cmd);
    long arg = va_arg(ap, long);
    va_end(ap);
    nxc_vfile* v = vfile_of(fd);
    if (!v) return fcntl_plain(fd, cmd, arg);
    switch (cmd) {
        case F_GETFL:
            if (IS_DEV(v->role)) return v->acc | (v->nonblock ? O_NONBLOCK : 0);
            return (v->role == ROLE_PIPE_R ? O_RDONLY : v->role == ROLE_PIPE_W ? O_WRONLY : O_RDWR) | (v->nonblock ? O_NONBLOCK : 0);
        case F_SETFL: v->nonblock = ((int)arg & O_NONBLOCK) != 0; return 0;
        case F_GETFD: return v->cloexec ? FD_CLOEXEC : 0;
        case F_SETFD: v->cloexec = ((int)arg & FD_CLOEXEC) != 0; return 0;
        case F_DUPFD:
#ifdef F_DUPFD_CLOEXEC
        case F_DUPFD_CLOEXEC:
#endif
            return dup_from(fd, arg);
        default: return NXC_FAIL(EINVAL);
    }
}

int __wrap_ioctl(int fd, unsigned long req, ...) {
    va_list ap;
    va_start(ap, req);
    void* arg = va_arg(ap, void*);
    va_end(ap);
    nxc_vfile* v = vfile_of(fd);
    if (!v) return __real_ioctl(fd, req, arg);
    if ((unsigned int)req == (unsigned int)FIONBIO && arg) {
        v->nonblock = *(int*)arg != 0;
        return 0;
    }
    if ((unsigned int)req == (unsigned int)FIONREAD && arg) {
        mutexLock(&g_nxc_mu);
        *(int*)arg = v->role == ROLE_PIPE_R ? (int)v->ch->ring.len : v->role == ROLE_EVENT && v->ch->counter ? 8 : 0;
        mutexUnlock(&g_nxc_mu);
        return 0;
    }
    return NXC_FAIL(ENOTTY);
}

/* ---- poll / select ---- */

enum { K_BAD = 0, K_VIRTUAL, K_SOCKET, K_STDIN, K_OTHER };

/* ---- pseudo devices ---- */

static const struct { const char* path; int role; } k_devs[] = {
    {"/dev/null", ROLE_DEV_NULL},
    {"/dev/zero", ROLE_DEV_ZERO},
    {"/dev/random", ROLE_DEV_RANDOM},
    {"/dev/urandom", ROLE_DEV_RANDOM},
};

/* 0 = not a device path, ROLE_* for a device, -1 for the /dev folder itself. */
static int dev_lookup(const char* path) {
    if (!path || strncmp(path, "/dev", 4) != 0) return 0;
    if (path[4] == 0 || (path[4] == '/' && path[5] == 0)) return -1;
    for (size_t i = 0; i < sizeof k_devs / sizeof k_devs[0]; i++) {
        if (strcmp(path, k_devs[i].path) == 0) return k_devs[i].role;
    }
    return 0;
}

int nxc__dev_match(const char* path) { return dev_lookup(path) != 0; }

int nxc__dev_open(const char* path, int flags) {
    int role = dev_lookup(path);
    if (role < 0) return NXC_FAIL(EISDIR);
    if (role == 0) return NXC_FAIL(ENOENT);
    nxc_chan* c = (nxc_chan*)calloc(1, sizeof *c);
    if (!c) return NXC_FAIL(ENFILE);
    c->ends = 1;
    int fd = new_fd(c, role, (flags & O_NONBLOCK) != 0, (flags & O_CLOEXEC) != 0);
    if (fd < 0) {
        free(c);
        return NXC_FAIL(EMFILE);
    }
    ((nxc_vfile*)__get_handle(fd)->fileStruct)->acc = flags & O_ACCMODE;
    return fd;
}

FILE* nxc__dev_fopen(const char* path, const char* mode) {
    int acc = O_RDONLY;
    if (!mode || !mode[0] || !strchr("rwa", mode[0])) return (errno = EINVAL, NULL);
    if (mode[0] != 'r') acc = O_WRONLY;
    if (strchr(mode, '+')) acc = O_RDWR;
    int fd = nxc__dev_open(path, acc);
    if (fd < 0) return NULL;
    FILE* f = fdopen(fd, mode);
    if (!f) {
        int e = errno;
        close(fd);
        errno = e;
    }
    return f;
}

int nxc__dev_stat(const char* path, struct stat* st) {
    int role = dev_lookup(path);
    if (!st) return NXC_FAIL(EFAULT);
    memset(st, 0, sizeof *st);
    st->st_nlink = 1;
    st->st_blksize = 4096;
    if (role < 0) {
        st->st_mode = S_IFDIR | 0755;
        return 0;
    }
    st->st_mode = S_IFCHR | 0666;
    st->st_rdev = dev_rdev(role);
    return 0;
}

int nxc__dev_access(const char* path, int mode) {
    int role = dev_lookup(path);
    if (role > 0 && (mode & X_OK)) return NXC_FAIL(EACCES);
    return 0;
}

static int kind_of(int fd) {
    if (fd < 0) return K_BAD;
    __handle* h = __get_handle(fd);
    if (!h || !h->refcount) return K_BAD;
    if (g_dev >= 0 && (int)h->device == g_dev) return K_VIRTUAL;
    const devoptab_t* dt = devoptab_list[h->device];
    if (dt && dt->name && strcmp(dt->name, "soc") == 0) return K_SOCKET;
    if (fd == 0) return K_STDIN;
    return K_OTHER;
}

/* Readiness of a virtual fd, lock held. */
static short virtual_events(const nxc_vfile* v, short want) {
    const nxc_chan* c = v->ch;
    short rev = 0;
    if (IS_DEV(v->role)) {
        rev = POLLIN | POLLOUT; /* never blocks */
    } else if (v->role == ROLE_PIPE_R) {
        if (c->ring.len) rev |= POLLIN;
        else if (c->writers == 0) rev |= POLLHUP;
    } else if (v->role == ROLE_PIPE_W) {
        if (c->readers == 0) rev |= POLLERR;
        else if (nxc_ring_free(&c->ring) >= PIPE_ATOMIC) rev |= POLLOUT;
    } else {
        if (c->counter) rev |= POLLIN;
        if (c->counter < EVENT_MAX) rev |= POLLOUT;
    }
    return (short)(rev & (want | POLLERR | POLLHUP | POLLNVAL));
}

int __wrap_poll(struct pollfd* fds, nfds_t nfds, int timeout) {
    if (nfds && !fds) return NXC_FAIL(EFAULT);
    if (nfds > 4096) return NXC_FAIL(EINVAL);
    uint64_t deadline = timeout > 0 ? nxc_now_ns() + (uint64_t)timeout * 1000000ull : 0;
    struct pollfd* socks = NULL;
    nfds_t* sock_idx = NULL;
    nfds_t nsock = 0;
    int kinds_known = 0;
    unsigned char* kinds = (unsigned char*)malloc(nfds ? nfds : 1);
    if (!kinds) return NXC_FAIL(ENOMEM);
    int result = 0;

    for (;;) {
        int count = 0;
        nsock = 0;
        mutexLock(&g_nxc_mu);
        for (nfds_t i = 0; i < nfds; i++) {
            int fd = fds[i].fd;
            fds[i].revents = 0;
            if (fd < 0) continue;
            int k = kind_of(fd);
            kinds[i] = (unsigned char)k;
            if (k == K_BAD) {
                fds[i].revents = POLLNVAL;
            } else if (k == K_VIRTUAL) {
                fds[i].revents = virtual_events((nxc_vfile*)__get_handle(fd)->fileStruct, fds[i].events);
            } else if (k == K_OTHER) {
                fds[i].revents = fds[i].events & (POLLIN | POLLOUT);
            } else if (k == K_SOCKET) {
                nsock++;
            }
            if (fds[i].revents) count++;
        }
        kinds_known = 1;
        if (count == 0 && (timeout != 0)) {
            /* nothing ready: wait for a state change before looking at the sockets again */
        }
        mutexUnlock(&g_nxc_mu);

        if (nsock) {
            if (!socks) {
                socks = (struct pollfd*)malloc(nsock * sizeof *socks);
                sock_idx = (nfds_t*)malloc(nsock * sizeof *sock_idx);
                if (!socks || !sock_idx) {
                    result = NXC_FAIL(ENOMEM);
                    break;
                }
            }
            nfds_t n = 0;
            for (nfds_t i = 0; i < nfds; i++) {
                if (fds[i].fd >= 0 && kinds[i] == K_SOCKET) {
                    socks[n] = fds[i];
                    sock_idx[n++] = i;
                }
            }
            int sr = __real_poll(socks, n, 0);
            if (sr < 0) {
                result = -1;
                break;
            }
            for (nfds_t j = 0; j < n; j++) {
                if (socks[j].revents && !fds[sock_idx[j]].revents) count++;
                fds[sock_idx[j]].revents = socks[j].revents;
            }
        }
        if (count > 0 || timeout == 0) {
            result = count;
            break;
        }
        if (deadline && nxc_now_ns() >= deadline) {
            result = 0;
            break;
        }

        mutexLock(&g_nxc_mu);
        /* re-check the virtual descriptors under the lock that guards the wait: no lost wake-up */
        int ready = 0;
        for (nfds_t i = 0; i < nfds && !ready; i++) {
            if (fds[i].fd >= 0 && kinds[i] == K_VIRTUAL) {
                nxc_vfile* v = vfile_of(fds[i].fd);
                if (v && virtual_events(v, fds[i].events)) ready = 1;
            }
        }
        int w = ready ? NXC_WAIT_OK : nxc_block_locked(deadline, nsock ? 2000000ull : 0, 0);
        mutexUnlock(&g_nxc_mu);
        if (w == NXC_WAIT_INTR) {
            result = NXC_FAIL(EINTR);
            break;
        }
    }
    (void)kinds_known;
    free(kinds);
    free(socks);
    free(sock_idx);
    return result;
}

int ppoll(struct pollfd* fds, nfds_t nfds, const struct timespec* ts, const sigset_t* mask) {
    int ms = -1;
    if (ts) {
        long long t = (long long)ts->tv_sec * 1000 + (ts->tv_nsec + 999999) / 1000000;
        ms = t > INT_MAX ? INT_MAX : (int)t;
    }
    return __wrap_poll(fds, nfds, ms);
}

int __wrap_select(int nfds, fd_set* rd, fd_set* wr, fd_set* ex, struct timeval* tv) {
    if (nfds < 0 || nfds > FD_SETSIZE) return NXC_FAIL(EINVAL);
    struct pollfd* p = (struct pollfd*)calloc((size_t)nfds + 1, sizeof *p);
    if (!p) return NXC_FAIL(ENOMEM);
    nfds_t n = 0;
    for (int fd = 0; fd < nfds; fd++) {
        short ev = 0;
        if (rd && FD_ISSET(fd, rd)) ev |= POLLIN;
        if (wr && FD_ISSET(fd, wr)) ev |= POLLOUT;
        if (ex && FD_ISSET(fd, ex)) ev |= POLLPRI;
        if (ev) {
            p[n].fd = fd;
            p[n].events = ev;
            n++;
        }
    }
    int ms = -1;
    if (tv) {
        long long t = (long long)tv->tv_sec * 1000 + (tv->tv_usec + 999) / 1000;
        ms = t > INT_MAX ? INT_MAX : (int)t;
    }
    int r = __wrap_poll(p, n, ms);
    if (r < 0) {
        free(p);
        return -1;
    }
    if (rd) FD_ZERO(rd);
    if (wr) FD_ZERO(wr);
    if (ex) FD_ZERO(ex);
    int bits = 0;
    for (nfds_t i = 0; i < n; i++) {
        short re = p[i].revents;
        if (re & POLLNVAL) {
            free(p);
            return NXC_FAIL(EBADF);
        }
        int fd = p[i].fd;
        if (rd && (re & (POLLIN | POLLHUP | POLLERR)) && (p[i].events & POLLIN)) { FD_SET(fd, rd); bits++; }
        if (wr && (re & (POLLOUT | POLLERR)) && (p[i].events & POLLOUT)) { FD_SET(fd, wr); bits++; }
        if (ex && (re & POLLPRI)) { FD_SET(fd, ex); bits++; }
    }
    free(p);
    return bits;
}

int pselect(int nfds, fd_set* rd, fd_set* wr, fd_set* ex, const struct timespec* ts, const sigset_t* mask) {
    struct timeval tv, *tvp = NULL;
    if (ts) {
        tv.tv_sec = ts->tv_sec;
        tv.tv_usec = (suseconds_t)((ts->tv_nsec + 999) / 1000);
        tvp = &tv;
    }
    return __wrap_select(nfds, rd, wr, ex, tvp);
}

#if NXC_WINDOWED
/* App end: close every descriptor of this layer (the app may have left pipes open), then drop the device. */
void nxc__fd_releaseall(void) {
    if (g_dev < 0) return;
    for (int fd = 3; fd < 1024; fd++) {
        if (vfile_of(fd)) close(fd);
    }
    /* The ":" matters: FindDevice() of a name without one answers with the DEFAULT device (sdmc:), and RemoveDevice()
     * would unregister that instead of ours: Nexvyn OS then lost its SD card paths (null device entry, a crash in the next
     * mkdir / stat) and ours stayed registered, pointing into the module that goes away. */
    char probe[sizeof g_devname + 2];
    snprintf(probe, sizeof probe, "%s:", g_devname);
    RemoveDevice(probe);
    mutexLock(&g_nxc_mu);
    g_dev = -1;
    mutexUnlock(&g_nxc_mu);
}
#endif
