/* Nexvyn Native SDK library - nxn_stream.h in a stand-alone .nro: no shared cache, so a stream is a file read in
 * place (one lock per stream keeps the file position of concurrent readers apart). NXN_STREAM_NOWAIT is ignored and
 * nxn_stream_prefetch is a no-op. Inside Nexvyn OS (windowed mode) the system's block cache serves these calls
 * (source/runtimes/nxwin_stream.cpp). */
#include "nxn_internal.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

struct nxn_stream {
    FILE* f;
    uint64_t size;
    Mutex mu;
};

nxn_result nxn_stream_open(nxn_dir dir, const char* rel, nxn_stream** out, uint64_t* size_out) {
    if (out) *out = NULL;
    if (size_out) *size_out = 0;
    if (!out || !rel || !rel[0]) return NXN_ERR_INVALID;
    char path[768];
    nxn_result r = nxn_fs_path(dir, rel, path, sizeof path);
    if (r != NXN_OK) return r;
    FILE* f = fopen(path, "rb");
    if (!f) {
        switch (errno) {
            case ENOENT: case ENOTDIR: return NXN_ERR_NOT_FOUND;
            case EACCES: case EPERM: return NXN_ERR_DENIED;
            case ENOMEM: return NXN_ERR_NO_MEMORY;
            default: return NXN_ERR_IO;
        }
    }
    nxn_stream* s = (nxn_stream*)calloc(1, sizeof *s);
    if (!s || fseeko(f, 0, SEEK_END) != 0) {
        free(s);
        fclose(f);
        return s ? NXN_ERR_IO : NXN_ERR_NO_MEMORY;
    }
    off_t n = ftello(f);
    if (n < 0) {
        free(s);
        fclose(f);
        return NXN_ERR_IO;
    }
    s->f = f;
    s->size = (uint64_t)n;
    mutexInit(&s->mu);
    if (size_out) *size_out = s->size;
    *out = s;
    return NXN_OK;
}

nxn_result nxn_stream_read(nxn_stream* s, uint64_t offset, void* buf, uint64_t len, uint32_t flags, uint64_t* got) {
    (void)flags;
    if (got) *got = 0;
    if (!s || (!buf && len)) return NXN_ERR_INVALID;
    if (offset >= s->size || !len) return NXN_OK;
    if (len > s->size - offset) len = s->size - offset;
    mutexLock(&s->mu);
    size_t n = 0;
    if (fseeko(s->f, (off_t)offset, SEEK_SET) == 0) n = fread(buf, 1, (size_t)len, s->f);
    mutexUnlock(&s->mu);
    if (got) *got = n;
    return n == len ? NXN_OK : NXN_ERR_IO;
}

nxn_result nxn_stream_prefetch(nxn_stream* s, uint64_t offset, uint64_t len) {
    (void)offset;
    (void)len;
    return s ? NXN_OK : NXN_ERR_INVALID;
}

void nxn_stream_close(nxn_stream* s) {
    if (!s) return;
    fclose(s->f);
    free(s);
}

/* N6 add-on: reads here go to the file directly, nothing is queued, so there is nothing to cancel. */
nxn_result nxn_stream_cancel(nxn_stream* s, uint64_t offset, uint64_t len, uint64_t* blocks) {
    (void)offset;
    (void)len;
    if (blocks) *blocks = 0;
    return s ? NXN_OK : NXN_ERR_INVALID;
}
