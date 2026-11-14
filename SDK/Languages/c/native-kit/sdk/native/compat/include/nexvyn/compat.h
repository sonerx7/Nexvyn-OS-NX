/* Nexvyn Native SDK - compatibility layer (libnexvyn_compat.a), the part that is not plain POSIX.
 *
 * The POSIX calls themselves (mmap, pipe, poll, sigaction, getcontext, ...) keep their normal names and headers
 * (<sys/mman.h>, <ucontext.h>, <sys/eventfd.h>, <dlfcn.h>, <sys/utsname.h>). This header holds what has no POSIX name:
 * setup, signal polling, coroutines, path mapping and the dlsym registry. Plain C, usable from C++.
 * Guide: docs/NATIVE_COMPAT.md. */
#ifndef NEXVYN_COMPAT_H
#define NEXVYN_COMPAT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NXC_VERSION_MAJOR 1
#define NXC_VERSION_MINOR 0
#define NXC_VERSION_STRING "1.0"

/* Optional. Idempotent. Moves the working directory into the app's data folder (nxn_fs_path(NXN_DIR_DATA) when the
 * Nexvyn ABI is linked, else sdmc:/switch) so relative paths work like on a PC. Every other call in this layer also
 * works without it. Returns 0. */
int nxc_init(void);
const char* nxc_version(void);
/* Optional. Stops the layer's helper thread (the signal timer) and disarms the timers. The native runtime calls it from
 * nxn_shutdown when both are linked. Idempotent; the layer starts its thread again if a timer is armed later. */
void nxc_shutdown(void);
/* Sleeps up to ns nanoseconds, delivering pending emulated signals on this thread. Returns 0 after the full time, or -1
 * with errno = EINTR when a handler ran (the sleep is cut short, like nanosleep). The native runtime uses it in
 * nxn_sleep_ns. */
int nxc_sleep_interruptible(uint64_t ns);

/* ---- signals (emulation, see the guide) ---- */

/* Runs the handlers of pending, unblocked signals on the calling thread. Returns how many handlers ran.
 * Call it once per frame / loop pass: alarm() and setitimer() deliver only at such safe points and inside blocking
 * compat calls (sleep, poll, select, pipe reads, sigsuspend, sigwait). raise() and kill(getpid(), sig) run the
 * handler before they return. */
int nxc_signal_poll(void);

/* ---- coroutines (small API on top of the same context switch as <ucontext.h>) ---- */

typedef struct nxc_coro nxc_coro;
typedef void (*nxc_coro_fn)(void* arg);

#define NXC_CORO_DEFAULT_STACK (64 * 1024)

/* Creates a suspended coroutine. stack_bytes 0 = NXC_CORO_DEFAULT_STACK (rounded up to 16, at least 8 KiB).
 * The stack is heap memory with a guard pattern at its low end that is checked at every switch. NULL on failure. */
nxc_coro* nxc_coro_create(nxc_coro_fn fn, void* arg, size_t stack_bytes);
/* Runs the coroutine until it yields or returns. 1 = yielded, 0 = finished, -1 = error (finished already, running
 * already, stack overflow detected). Resuming from inside another coroutine nests: control comes back here. */
int nxc_coro_resume(nxc_coro* c);
/* Inside a coroutine: suspends it and returns to the resumer. Outside one: does nothing. */
void nxc_coro_yield(void);
int nxc_coro_done(const nxc_coro* c);
/* The running coroutine of this thread, NULL on the thread's own stack. */
nxc_coro* nxc_coro_current(void);
/* Bytes of the coroutine's stack that were never touched (high-water mark), 0 if unknown. */
size_t nxc_coro_stack_free(const nxc_coro* c);
/* The stack block of a coroutine (debugging, tests). Its lowest 128 bytes are the overflow guard. */
void nxc_coro_stack_info(const nxc_coro* c, void** base, size_t* size);
/* Frees the stack. A suspended coroutine is simply dropped (its C++ destructors do not run). */
void nxc_coro_destroy(nxc_coro* c);

/* ---- paths (opt-in, see nexvyn_compat_fsmap() in the CMake helper) ----
 * Translates a PC style path to a Switch path: "\" to "/", "C:\x" to <drive dir>/x, "/x" to <root>/x when NXC_FS_VROOT
 * is on. Paths that already carry a device ("sdmc:/...", "romfs:/...") are left alone. */
#define NXC_FS_CASEFOLD  0x01u /* open/stat/fopen/... find the file when only the letter case differs */
#define NXC_FS_BACKSLASH 0x02u /* "\" is a separator */
#define NXC_FS_DRIVES    0x04u /* "C:" ... "Z:" prefixes map to a folder (default: the root) */
#define NXC_FS_VROOT     0x08u /* "/x" means <root>/x, getcwd() reports "/..." */
#define NXC_FS_ALL       0x0Fu

void nxc_fs_enable(unsigned flags);          /* replaces the flag set (0 = everything off) */
unsigned nxc_fs_flags(void);
/* The folder that "/" and drive letters map to. Default: the data folder (see nxc_init). Not NULL, no trailing "/". */
void nxc_fs_set_root(const char* real_dir);
const char* nxc_fs_root(void);
/* Maps one drive letter to its own folder, e.g. nxc_fs_map_drive('D', "romfs:/game"). 0 on success. */
int nxc_fs_map_drive(char letter, const char* real_dir);
/* The translation alone (no case search). Returns 0, or -1 when the result does not fit in cap. */
int nxc_fs_translate(const char* in, char* out, size_t cap);

/* ---- dlsym registry ---- */

/* dlopen() of a library is not possible in exclusive mode. dlopen(NULL) and dlsym(RTLD_DEFAULT, name) look names up in
 * this table instead, so ports that probe for optional functions get a clean answer. 0 on success. */
int nxc_dl_register(const char* name, void* address);

/* ---- strict mode ----
 * -DNXC_STRICT=1 turns calls to fork(), exec*, system(), popen(), posix_spawn(), ... into compile-time warnings,
 * -DNXC_STRICT=2 into errors (the CMake helper: nexvyn_use_compat(target STRICT)). */

#ifdef __cplusplus
}
#endif

#endif /* NEXVYN_COMPAT_H */
