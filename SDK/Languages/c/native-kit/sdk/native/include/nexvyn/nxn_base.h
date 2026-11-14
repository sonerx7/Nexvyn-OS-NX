/* Nexvyn Native SDK - base types shared by every nxn_* header (NATIVE_KIT.md).
 *
 * ABI rules (ABI v1, frozen on 2026-11-09; the frozen surface is sdk/native/toolchain/nxn_abi_v1.json and every later
 * version is checked against it: names, signatures, struct layouts and constant values are only ever added):
 *  - C only. No C++ type crosses the boundary.
 *  - Every struct passed across the boundary starts with `uint32_t size` = sizeof(the struct the caller compiled
 *    against). The library reads/writes only min(size, its own sizeof); fields are only ever added at the end, so an
 *    app built against an older header keeps working with a newer library and the other way round.
 *    A new field never goes into implicit padding (a uint32_t after a struct's last uint32_t when the struct is 8-byte
 *    aligned): sizeof would not change and the size could not tell an old caller from a new one. Tail padding is
 *    written out as a `reserved` field (0) instead; a later version may give that field a meaning only where 0 keeps
 *    the old behaviour. Every layout is pinned by tests/test_nxwin.cpp (nxn_abi_layout).
 *  - Objects are opaque handles (pointers to incomplete structs).
 *  - Functions are only added, never removed or changed. A behaviour change goes behind a new function or flag.
 *  - NXN_ABI_GEN is raised by hand only on an incompatible change (it never follows the OS or SDK version).
 *  - Optional features are discovered with nxn_caps_get(); a missing feature is a clean NXN_ERR_UNSUPPORTED.
 *  - An app that calls a function added in a later Native SDK version raises its app.json "minNative" to that version:
 *    an older Nexvyn OS refuses to load a module that imports an nxn_* name it does not have (a clean message, no crash).
 *  - Enum constants stay inside the int range (C11), so every enum type is 4 bytes wide. 64-bit masks (NXN_CAP_*) are
 *    macros of type uint64_t, never enum constants.
 *
 * Threads and memory (every function in the nxn_* headers says "Thread:" and "Memory:"; this is the rule behind them):
 *  - Thread: unless a function says otherwise it may be called from any thread that belongs to the app: the thread
 *    main() / nxn_run runs on, and every thread started with nxn_thread_start, pthread_create, std::thread or
 *    threadCreate. Inside Nexvyn OS a thread that does not belong to the app gets NXN_ERR_NOT_READY (or nothing happens).
 *    "Main thread" below means the app's main thread. Handles (display, audio, thread, library) are used by the thread(s)
 *    their function names, never by two threads at once unless the text says so.
 *  - Memory: nothing is allocated for the caller to free. Out-parameters are written into the caller's own struct or
 *    buffer; every const char* the library returns belongs to the library and must not be freed or modified (its
 *    lifetime is stated per function); a handle returned through `out` is released by the matching close / join call or
 *    when the app ends. The caller owns every buffer and struct it passes in; the library never keeps a pointer to them
 *    after the call returns, except the ones a function documents (an audio callback's `user`, a thread's `arg`). */
#ifndef NEXVYN_NXN_BASE_H
#define NEXVYN_NXN_BASE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
#define NXN_EXTERN_C_BEGIN extern "C" {
#define NXN_EXTERN_C_END }
#else
#define NXN_EXTERN_C_BEGIN
#define NXN_EXTERN_C_END
#endif

#define NXN_API

/* Native SDK version of these headers ("minNative" in app.json is compared against the system's version). */
#define NXN_VERSION_MAJOR 1
#define NXN_VERSION_MINOR 2
#define NXN_VERSION_STRING "1.2"

/* ABI generation: raised by hand only when a struct layout or calling convention changes incompatibly. */
#define NXN_ABI_GEN 1

/* Fills the leading size field of a versioned struct: `nxn_caps c = NXN_STRUCT_INIT(nxn_caps);` */
#ifdef __cplusplus
/* C++: `type{size}` initialized the first member only, so -Wextra warned "missing initializer" at every use. The helper
 * value-initializes the struct (every field zero) and then sets the `size` field every versioned struct starts with. */
template <typename T>
inline T nxn__struct_init() {
    T v = T();
    v.size = static_cast<uint32_t>(sizeof(T));
    return v;
}
#define NXN_STRUCT_INIT(type) nxn__struct_init<type>()
#else
/* C: a designated initializer (the other fields are zero) does not trigger -Wextra "missing initializer". */
#define NXN_STRUCT_INIT(type) {.size = (uint32_t)sizeof(type)}
#endif

typedef int32_t nxn_result;
enum {
    NXN_OK = 0,
    NXN_ERR_INVALID = -1,      /* bad argument (NULL, size 0, an unknown enum value...) */
    NXN_ERR_UNSUPPORTED = -2,  /* this system / library does not have the feature (see nxn_caps_get) */
    NXN_ERR_NOT_READY = -3,    /* nxn_init was not called, or the object is closed */
    NXN_ERR_IO = -4,           /* file system error (the disk is full, the medium failed...) */
    NXN_ERR_DENIED = -5,       /* refused: a path outside the app's folders ("..", absolute, "sdmc:"), writing the
                                  read-only bundle, or the file system said "permission denied" / "read-only" */
    NXN_ERR_NO_MEMORY = -6,
    NXN_ERR_TOO_SMALL = -7,    /* the output buffer is too small (nothing was truncated silently) */
    NXN_ERR_NOT_FOUND = -8,
    NXN_ERR_SYSTEM = -9,       /* a system service (EGL, audio, ...) failed; nxn_last_error() says which */
    NXN_ERR_CANCELLED = -10,   /* the user dismissed a dialog (nxn_pick); nothing is wrong */
    /* Reserved before the ABI freeze (add-only; no call returns them yet, apps may already handle them). Treat any
       other negative value as a plain failure: later versions may add codes below -14. ngfx_* (nexgfx_native.h) has
       its own NGFX_ERR_* codes; the same number means something else there. */
    NXN_ERR_TIMEOUT = -11,     /* a wait ran out of time; trying again can work */
    NXN_ERR_BUSY = -12,        /* the resource is in use right now; try again later */
    NXN_ERR_EXISTS = -13,      /* the target already exists (create without overwrite) */
    NXN_ERR_LIMIT = -14        /* a system or app limit was reached (open handles, queue size...) */
};

#endif /* NEXVYN_NXN_BASE_H */
