/* Shared SDK file commit policy, used by the hosted and exclusive adapters.
 * Callers serialize helper reads/writes for their app with a dedicated I/O mutex.
 * The fallback is recoverable, not a filesystem-wide atomic replace or fsync guarantee.
 * .tmp and .nxn-old~ siblings are reserved for this operation. */
#ifndef NXN_FILE_IO_INTERNAL_H
#define NXN_FILE_IO_INTERNAL_H
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

static int nxn__file_names(const char* path, char* tmp, size_t nt, char* old, size_t no) {
    int a = snprintf(tmp, nt, "%s.tmp", path);
    int b = snprintf(old, no, "%s.nxn-old~", path);
    if (a < 0 || (size_t)a >= nt || b < 0 || (size_t)b >= no) { errno = ENAMETOOLONG; return 0; }
    return 1;
}

static FILE* nxn__file_open_read(const char* path) {
    FILE* f = fopen(path, "rb");
    if (f || errno != ENOENT) return f;
    char old[800], tmp[800];
    if (!nxn__file_names(path, tmp, sizeof tmp, old, sizeof old)) return NULL;
    /* An interrupted two-rename commit can leave the old complete file here.
     * Never read .tmp: a process interruption may have left it partially written. */
    return fopen(old, "rb");
}

static int nxn__file_write(const char* path, const void* data, size_t bytes) {
    char tmp[800], old[800];
    struct stat st, prior;
    if (!nxn__file_names(path, tmp, sizeof tmp, old, sizeof old)) return 0;
    int target = stat(path, &st) == 0;
    if (!target && errno != ENOENT) return 0;
    if (target && !S_ISREG(st.st_mode)) { errno = EISDIR; return 0; }
    int backup = stat(old, &prior) == 0;
    if (!backup && errno != ENOENT) return 0;
    if (backup) {
        if (!S_ISREG(prior.st_mode)) { errno = EISDIR; return 0; }
        if (!target) {
            if (rename(old, path) != 0) return 0;
            target = 1;
        } else if (remove(old) != 0) return 0;
    }
    FILE* f = fopen(tmp, "wb");
    if (!f) return 0;
    int ok = bytes == 0 || fwrite(data, 1, bytes, f) == bytes;
    int e = ok ? 0 : (errno ? errno : EIO);
    if (fclose(f) != 0) { if (!e) e = errno ? errno : EIO; ok = 0; }
    if (!ok) { remove(tmp); errno = e; return 0; }
    /* Prefer a single atomic replacement on filesystems which support it. */
    if (rename(tmp, path) == 0) return 1;
    e = errno;
    if (!target) { errno = e; return 0; } /* complete temp retained; no old file to lose */
    /* FAT/Horizon may reject replacement of an existing destination. Move the
     * old complete bytes aside instead of deleting them before activation. */
    if (rename(path, old) != 0) return 0;
    if (rename(tmp, path) == 0) { remove(old); return 1; }
    e = errno;
    /* Failure to roll back must preserve the old sibling. Helper readers can
     * still open it and the next writer restores it before touching .tmp. */
    (void)rename(old, path);
    errno = e;
    return 0;
}
#endif
