/* Nexvyn Native SDK library - the app's folders (nxn_fs.h). */
#include "nxn_internal.h"
#include <errno.h>
#include <stdio.h>
#include <string.h>

/* The result for a failed open / create: what the file system said, not a guess (nxn_fs.h lists the codes). */
static nxn_result err_from_errno(int e) {
    switch (e) {
        case ENOENT: case ENOTDIR: return NXN_ERR_NOT_FOUND;
        case EACCES: case EPERM: case EROFS: return NXN_ERR_DENIED;
        case ENOMEM: return NXN_ERR_NO_MEMORY;
        default: return NXN_ERR_IO;
    }
}

static const char* root_of(nxn_dir dir) {
    switch (dir) {
        case NXN_DIR_DATA: return g_nxn.data;
        case NXN_DIR_CACHE: return g_nxn.cache;
        case NXN_DIR_BUNDLE: return g_nxn.bundle;
        default: return NULL;
    }
}

nxn_result nxn_fs_path(nxn_dir dir, const char* rel, char* out, size_t out_size) {
    if (!out || !out_size) return NXN_ERR_INVALID;
    out[0] = 0;
    if (!g_nxn.inited) return NXN_ERR_NOT_READY;
    const char* root = root_of(dir);
    if (!root || !root[0]) return NXN_ERR_INVALID;
    if (!rel) rel = "";
    if (!nxn__rel_ok(rel)) return NXN_ERR_DENIED;
    int n = rel[0] ? snprintf(out, out_size, "%s/%s", root, rel) : snprintf(out, out_size, "%s", root);
    if (n < 0 || (size_t)n >= out_size) {
        out[0] = 0;
        return NXN_ERR_TOO_SMALL;
    }
    return NXN_OK;
}

nxn_result nxn_fs_mkdirs(nxn_dir dir, const char* rel) {
    if (dir == NXN_DIR_BUNDLE) return NXN_ERR_DENIED;
    char path[NXN__PATH];
    nxn_result r = nxn_fs_path(dir, rel, path, sizeof path);
    if (r != NXN_OK) return r;
    return nxn__mkdirs(path) ? NXN_OK : NXN_ERR_IO;
}

nxn_result nxn_fs_write(nxn_dir dir, const char* rel, const void* data, size_t bytes) {
    if (dir == NXN_DIR_BUNDLE) return NXN_ERR_DENIED;
    if (!rel || !rel[0] || (!data && bytes)) return NXN_ERR_INVALID;
    char path[NXN__PATH], tmp[NXN__PATH + 8];
    nxn_result r = nxn_fs_path(dir, rel, path, sizeof path);
    if (r != NXN_OK) return r;
    char* slash = strrchr(path, '/');
    if (slash) {
        *slash = 0;
        nxn__mkdirs(path);
        *slash = '/';
    }
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    FILE* f = fopen(tmp, "wb");
    if (!f) {
        int e = errno;
        nxn__set_error("cannot write %s", tmp);
        nxn_result er = err_from_errno(e);
        return er == NXN_ERR_NOT_FOUND ? NXN_ERR_IO : er;  /* the parent folder could not be made: an I/O failure */
    }
    int ok = bytes == 0 || fwrite(data, 1, bytes, f) == bytes;
    ok = fclose(f) == 0 && ok;
    if (ok) {
        remove(path);
        ok = rename(tmp, path) == 0;
    }
    if (!ok) {
        remove(tmp);
        nxn__set_error("cannot write %s", path);
        return NXN_ERR_IO;
    }
    return NXN_OK;
}

nxn_result nxn_fs_read(nxn_dir dir, const char* rel, void* buf, size_t cap, size_t* read_bytes) {
    if (!rel || !rel[0] || (!buf && cap)) return NXN_ERR_INVALID;
    if (read_bytes) *read_bytes = 0;
    char path[NXN__PATH];
    nxn_result r = nxn_fs_path(dir, rel, path, sizeof path);
    if (r != NXN_OK) return r;
    FILE* f = fopen(path, "rb");
    if (!f) return err_from_errno(errno);
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size < 0) {
        fclose(f);
        return NXN_ERR_IO;
    }
    if (read_bytes) *read_bytes = (size_t)size;
    if ((size_t)size > cap) {
        fclose(f);
        return NXN_ERR_TOO_SMALL;
    }
    size_t got = fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (got != (size_t)size) return NXN_ERR_IO;
    return NXN_OK;
}
