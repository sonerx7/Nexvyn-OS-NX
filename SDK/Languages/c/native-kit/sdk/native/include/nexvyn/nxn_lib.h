/* Nexvyn Native SDK - shared libraries (.nxvlib) loaded at run time (docs/NATIVE_KIT.md, "Shared libraries").
 *
 * Static linking stays the default. A library many ports use (SDL2, a big runtime, a codec) can instead be built once
 * as a .nxvlib (`nxv-native lib`, CMake nexvyn_add_lib()) and loaded here. A library takes the C library, libstdc++
 * and libnx from the app that loads it (one newlib, one heap): the app exports them (CMake nexvyn_export_symbols()).
 *
 *   nxn_lib* lib;
 *   if (nxn_lib_open("greet", "1.0", &lib) != NXN_OK) { nxn_log(NXN_LOG_ERROR, "%s", nxn_lib_error()); ... }
 *   const char* (*hello)(void) = (const char* (*)(void))nxn_lib_sym(lib, "greet_hello");
 *
 * Rules:
 *  - Only C functions and plain data cross the boundary (extern "C"). No C++ type, exception or thread_local.
 *  - name: a path ("sdmc:/x/y.nxvlib", "./plugins/a.so"), or a bare name ("greet", "libgreet.so") looked up next to
 *    the app's .nro and in <data>/lib/ as <name>.nxvlib (a "lib" prefix and a ".so" suffix are tried without them).
 *  - Identity: NXN_LIB_ABI_GEN of the library (it must equal this header's) and its semver. min_version "1.2" accepts
 *    1.2.0 up to 1.x.y; another major is refused. NULL or "" accepts any version.
 *  - Opening the same file again returns the same handle (counted). A library stays mapped until the app ends, also
 *    after its last nxn_lib_close (function pointers and atexit handlers into it stay valid); its destructors run at
 *    exit.
 *  - Every failure returns an error and leaves the app running; nxn_lib_error() says why in one line.
 *  - Loading needs JIT code memory: NXN_CAP_SHARED_LIBS in nxn_caps_get(). Inside Nexvyn OS this is not available yet
 *    (NXN_ERR_UNSUPPORTED).
 *  - Thread: every nxn_lib_* function may be called from any app thread; the library's own initializers run on the
 *    thread that first opened it. Memory: nxn_lib* handles and every string or pointer returned here belong to the
 *    library and are never freed by the caller (they stay valid until the app ends, see the rules above). */
#ifndef NEXVYN_NXN_LIB_H
#define NEXVYN_NXN_LIB_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* Library ABI generation: raised by hand only when the contract between a library and the app that loads it changes
 * incompatibly (never with the OS, SDK or library version). A library carries the value it was built with. */
#define NXN_LIB_ABI_GEN "1"

typedef struct nxn_lib nxn_lib; /* opaque */

/* Loads (or finds the loaded) library. NXN_OK and *out, or:
 *   NXN_ERR_NOT_FOUND    no such file
 *   NXN_ERR_IO           the file cannot be read
 *   NXN_ERR_INVALID      not a Nexvyn library (bad ELF, another machine, no identity, text relocations)
 *   NXN_ERR_UNSUPPORTED  another ABI generation, a version too old or of another major, an import the app does not
 *                        export, thread_local variables, or no JIT code memory (applet mode)
 *   NXN_ERR_NO_MEMORY / NXN_ERR_SYSTEM */
NXN_API nxn_result nxn_lib_open(const char* name, const char* min_version, nxn_lib** out);

/* Address of an exported symbol of the library; NULL when it has none. lib NULL: the app's own exports, then every
 * open library in load order (dlsym(RTLD_DEFAULT, ...)). */
NXN_API void* nxn_lib_sym(nxn_lib* lib, const char* name);

/* Drops one reference (see the rules above: the code stays mapped until the app ends). */
NXN_API nxn_result nxn_lib_close(nxn_lib* lib);

/* The last nxn_lib_* failure of the calling thread ("" when none). */
NXN_API const char* nxn_lib_error(void);

/* The version ("1.4.2") and name of an open library ("" for NULL). */
NXN_API const char* nxn_lib_version(nxn_lib* lib);
NXN_API const char* nxn_lib_name(nxn_lib* lib);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_LIB_H */
