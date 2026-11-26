/* Nexvyn compat layer - POSIX file timestamp no-ops, 64-bit positional I/O / seek, and readdir d_type consistency.
 *
 * Horizon FAT filesystems do not expose writable file timestamps through newlib's devoptab, so utime/utimes/futimens/
 * utimensat validate the target path or descriptor and return 0 as a documented no-op that preserves existing times
 * (returning ENOENT/EBADF/EINVAL otherwise, never ENOSYS).
 *
 * pread/pwrite/pread64/pwrite64 preserve the file offset across seek+read/write under g_pos_mu, supporting 64-bit
 * offsets above 2 GiB alongside lseek64. */
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/iosupport.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <utime.h>

#include "nexvyn/compat_posix.h"
#include "nxc_internal.h"
#include "nxc_path.h"

_Static_assert(sizeof(off_t) == 8 && sizeof(off64_t) == 8, "64-bit off_t/off64_t required");

struct dirent* __real_readdir(DIR* dirp);

static Mutex g_pos_mu;

static int valid_timespec(const struct timespec times[2]) {
    if (!times) return 1;
    for (int i = 0; i < 2; i++) {
        long ns = times[i].tv_nsec;
        if (ns == UTIME_NOW || ns == UTIME_OMIT) continue;
        if (ns < 0 || ns >= 1000000000L) return 0;
    }
    return 1;
}

static int valid_timeval(const struct timeval times[2]) {
    if (!times) return 1;
    for (int i = 0; i < 2; i++) {
        if (times[i].tv_usec < 0 || times[i].tv_usec >= 1000000L) return 0;
    }
    return 1;
}

static int has_drive_prefix(const char* path) {
    return ((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z')) && path[1] == ':';
}

/* ---- timestamp no-ops (existing path/fd -> 0, preserving FAT timestamps) ---- */

int __wrap_utime(const char* path, const struct utimbuf* times) {
    (void)times;
    if (!path) return NXC_FAIL(EFAULT);
    if (!*path) return NXC_FAIL(ENOENT);
    struct stat st;
    return stat(path, &st) == 0 ? 0 : -1;
}

int __wrap_utimes(const char* path, const struct timeval times[2]) {
    if (!path) return NXC_FAIL(EFAULT);
    if (!*path) return NXC_FAIL(ENOENT);
    if (!valid_timeval(times)) return NXC_FAIL(EINVAL);
    struct stat st;
    return stat(path, &st) == 0 ? 0 : -1;
}

int futimens(int fd, const struct timespec times[2]) {
    if (!valid_timespec(times)) return NXC_FAIL(EINVAL);
    if (fd < 0) return NXC_FAIL(EBADF);
    __handle* h = __get_handle(fd);
    if (!h || !h->refcount) return NXC_FAIL(EBADF);
    struct stat st;
    if (fstat(fd, &st) == 0) return 0;
    return errno == ENOSYS ? 0 : -1;
}

int utimensat(int dirfd, const char* path, const struct timespec times[2], int flags) {
    if (flags & ~AT_SYMLINK_NOFOLLOW) return NXC_FAIL(EINVAL);
    if (!valid_timespec(times)) return NXC_FAIL(EINVAL);
    if (!path) return NXC_FAIL(EFAULT);
    if (path[0] == '\0') return NXC_FAIL(ENOENT);
    if (dirfd == AT_FDCWD || path[0] == '/' || path[0] == '\\' ||
        nxc_path_device_len(path) > 0 || has_drive_prefix(path)) {
        struct stat st;
        return (flags & AT_SYMLINK_NOFOLLOW) ? lstat(path, &st) : stat(path, &st);
    }
    __handle* h = dirfd >= 0 ? __get_handle(dirfd) : NULL;
    if (!h || !h->refcount) return NXC_FAIL(EBADF);
    return NXC_FAIL(ENOTDIR);
}

/* ---- 64-bit seek and positional I/O ---- */

off64_t lseek64(int fd, off64_t offset, int whence) {
    mutexLock(&g_pos_mu);
    off64_t result = lseek(fd, offset, whence);
    mutexUnlock(&g_pos_mu);
    return result;
}

static ssize_t pos_io(int fd, void* rbuf, const void* wbuf, size_t count, off_t offset) {
    if (offset < 0) return NXC_FAIL(EINVAL);
    if (!rbuf && !wbuf && count) return NXC_FAIL(EFAULT);
    if (fd < 0) return NXC_FAIL(EBADF);
    __handle* h = __get_handle(fd);
    if (!h || !h->refcount) return NXC_FAIL(EBADF);

    mutexLock(&g_pos_mu);
    off_t save = lseek(fd, 0, SEEK_CUR);
    if (save < 0) {
        int e = errno == ENOSYS ? ESPIPE : errno;
        mutexUnlock(&g_pos_mu);
        return NXC_FAIL(e);
    }
    if (count == 0) {
        mutexUnlock(&g_pos_mu);
        return 0;
    }
    if (rbuf) {  /* POSIX: a read at or past the end returns 0; the libnx file layer answers EIO there */
        struct stat st;
        if (fstat(fd, &st) == 0 && offset >= st.st_size) {
            mutexUnlock(&g_pos_mu);
            return 0;
        }
    }
    if (lseek(fd, offset, SEEK_SET) < 0) {
        int e = errno;
        lseek(fd, save, SEEK_SET);
        mutexUnlock(&g_pos_mu);
        return NXC_FAIL(e);
    }
    ssize_t n = wbuf ? write(fd, wbuf, count) : read(fd, rbuf, count);
    int io_err = (n < 0) ? errno : 0;
    off_t restored = lseek(fd, save, SEEK_SET);
    int restore_err = errno;
    mutexUnlock(&g_pos_mu);
    if (n < 0) return NXC_FAIL(io_err);
    if (restored < 0) return NXC_FAIL(restore_err);
    return n;
}

ssize_t pread(int fd, void* buf, size_t count, off_t offset) {
    return pos_io(fd, buf, NULL, count, offset);
}

ssize_t pwrite(int fd, const void* buf, size_t count, off_t offset) {
    return pos_io(fd, NULL, buf, count, offset);
}

ssize_t pread64(int fd, void* buf, size_t count, off64_t offset) {
    return pos_io(fd, buf, NULL, count, (off_t)offset);
}

ssize_t pwrite64(int fd, const void* buf, size_t count, off64_t offset) {
    return pos_io(fd, NULL, buf, count, (off_t)offset);
}

/* ---- readdir d_type consistency ---- */

struct dirent* __wrap_readdir(DIR* dirp) {
    if (!dirp) {
        errno = EBADF;
        return NULL;
    }
    struct dirent* e = __real_readdir(dirp);
    if (!e) return NULL;
    switch (e->d_type) {
        case DT_UNKNOWN:
        case DT_FIFO:
        case DT_CHR:
        case DT_DIR:
        case DT_BLK:
        case DT_REG:
        case DT_LNK:
        case DT_SOCK:
        case DT_WHT:
            break;
        default:
            e->d_type = DT_UNKNOWN;
            break;
    }
    return e;
}
