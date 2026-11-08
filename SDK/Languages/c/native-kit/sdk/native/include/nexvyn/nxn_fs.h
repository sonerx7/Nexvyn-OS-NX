/* Nexvyn Native SDK - files: the app's own folders.
 *
 *   NXN_DIR_DATA    read-write, kept (the app's folder in the user's Library/Application Support)
 *   NXN_DIR_CACHE   read-write, may be cleared by the system to free space
 *   NXN_DIR_BUNDLE  read-only: the installed package (the .nro, assets shipped with it)
 *
 * `rel` is a relative path inside that folder: no "..", no leading "/", no drive ("sdmc:"). Native code is not
 * sandboxed by the kernel; these helpers keep a well-behaved app inside its folders, and Store review checks that
 * apps use them.
 *
 * Threads: every function may be called from any app thread; two threads writing the same file race like any file
 * access (nxn_fs_write replaces the whole file atomically, so a reader sees the old or the new content). Memory: the
 * caller owns every buffer it passes in; the library keeps none of them and returns no allocation. */
#ifndef NEXVYN_NXN_FS_H
#define NEXVYN_NXN_FS_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef enum nxn_dir {
    NXN_DIR_DATA = 0,
    NXN_DIR_CACHE = 1,
    NXN_DIR_BUNDLE = 2
} nxn_dir;

/* Errors: NXN_ERR_DENIED for a rel outside the folders ("..", leading "/", a drive), for writing NXN_DIR_BUNDLE and for
 * "permission denied" / "read-only" from the file system; NXN_ERR_NOT_FOUND only when the file or folder does not exist
 * (nxn_fs_read); NXN_ERR_NO_MEMORY when the system is out of memory; NXN_ERR_IO for any other file system failure;
 * NXN_ERR_INVALID for NULL / empty arguments; NXN_ERR_NOT_READY before nxn_init.
 *
 * Full path ("sdmc:/...") of rel inside dir, for stdio / POSIX calls. rel may be "" (the folder itself). */
NXN_API nxn_result nxn_fs_path(nxn_dir dir, const char* rel, char* out, size_t out_size);
/* Creates the folder rel (and its parents) inside a writable dir. */
NXN_API nxn_result nxn_fs_mkdirs(nxn_dir dir, const char* rel);
/* Writes a whole file atomically (temporary file, then rename). Refused for NXN_DIR_BUNDLE. */
NXN_API nxn_result nxn_fs_write(nxn_dir dir, const char* rel, const void* data, size_t bytes);
/* Reads a whole file into buf. *read_bytes gets the size; NXN_ERR_TOO_SMALL when it does not fit (nothing read). */
NXN_API nxn_result nxn_fs_read(nxn_dir dir, const char* rel, void* buf, size_t cap, size_t* read_bytes);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_FS_H */
