/* Nexvyn Native SDK - streaming reads of big files (disc images, data packs, ROMs) without loading them whole.
 *
 *   nxn_stream* s;
 *   uint64_t size;
 *   if (nxn_stream_open(NXN_DIR_DATA, "games/disc.iso", &s, &size) == NXN_OK) {
 *       nxn_stream_prefetch(s, 0, 1 << 20);            // the first megabyte, loaded in the background
 *       uint64_t got;
 *       nxn_stream_read(s, 0x8000, buf, 2048, 0, &got); // waits for the data if needed
 *       nxn_stream_close(s);
 *   }
 *
 * Inside Nexvyn OS (windowed mode, NXN_CAP_STREAM) every app shares one block cache of the system: recently read
 * blocks stay in memory, the oldest go first when the cache is full, and the system shrinks the cache when memory runs
 * low. In a stand-alone .nro there is no shared cache: reads go to the file directly and NXN_STREAM_NOWAIT is ignored.
 *
 * Paths: `rel` inside `dir` exactly like nxn_fs.h (no "..", no leading "/", no drive). Streams are read-only.
 * Threads: every call may be made from any app thread, also on the same stream at once. Memory: the caller owns `buf`;
 * the handle belongs to the system until nxn_stream_close (or the app's end, which closes every stream left open). */
#ifndef NEXVYN_NXN_STREAM_H
#define NEXVYN_NXN_STREAM_H

#include "nxn_base.h"
#include "nxn_fs.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_stream nxn_stream; /* opaque */

enum {
    NXN_STREAM_NOWAIT = 1 /* nxn_stream_read: only data already in memory; NXN_ERR_BUSY (and a background load of the
                             rest) otherwise. For a render or audio thread that must not wait for the card. */
};

/* Opens rel inside dir for streaming. *size_out (may be NULL) gets the file size. NXN_ERR_NOT_FOUND, NXN_ERR_DENIED
 * (a path outside the app's folders), NXN_ERR_IO, NXN_ERR_LIMIT (64 streams open), NXN_ERR_UNSUPPORTED (switched off).
 * Thread: any app thread. Memory: *out is a system-owned handle, freed by nxn_stream_close or at the app's end. */
NXN_API nxn_result nxn_stream_open(nxn_dir dir, const char* rel, nxn_stream** out, uint64_t* size_out);
/* Reads [offset, offset + len) into buf. *got (may be NULL) gets the bytes read: fewer than len only at the end of the
 * file, or with NXN_ERR_BUSY (NXN_STREAM_NOWAIT, the rest is not in memory yet; try again later). NXN_ERR_IO when the
 * medium failed. Thread: any app thread. Memory: written into the caller's buf. */
NXN_API nxn_result nxn_stream_read(nxn_stream* s, uint64_t offset, void* buf, uint64_t len, uint32_t flags,
                                   uint64_t* got);
/* Starts loading a range in the background and returns at once (a hint: the system may load less when memory is low).
 * Windowed host: duplicate cached/queued blocks share the existing job. NXN_ERR_BUSY means the shared admission
 * budget cannot accept the rest yet; part may already be queued. Retry later; do not spin on the render/audio thread.
 * Blocking reads still work, and NXN_STREAM_NOWAIT continues to return cached bytes or Busy while requesting the rest.
 * Thread: any app thread. Memory: no caller buffer; the host retains charged work through cancellation/close. */
NXN_API nxn_result nxn_stream_prefetch(nxn_stream* s, uint64_t offset, uint64_t len);
/* Closes the stream; its cached blocks are given back. NULL is ignored. Thread: any app thread, after every read on
 * it returned. Memory: the handle may not be used afterwards. */
NXN_API void nxn_stream_close(nxn_stream* s);

/* Range cancel (N6 add-on): takes back prefetch work queued for blocks that overlap [offset, offset + len) and
 * have not started loading. *blocks (may be NULL) gets the number of blocks cancelled. It does NOT interrupt a read that
 * is already running (a blocking nxn_stream_read, a block already loading) and does not remove cached blocks; a later
 * nxn_stream_prefetch of the same range requests it again. Overlapping hints share blocks, so a cancel applies to all
 * hints on that stream and range. Use it when the app seeks away (a streaming video, a level
 * change) so the card does not load what nobody needs. NXN_ERR_UNSUPPORTED where the host lacks it.
 * Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_stream_cancel(nxn_stream* s, uint64_t offset, uint64_t len, uint64_t* blocks);

NXN_EXTERN_C_END

#endif
