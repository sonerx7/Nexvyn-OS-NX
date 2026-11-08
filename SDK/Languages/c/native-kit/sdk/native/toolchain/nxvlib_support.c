/* Linked into every Nexvyn shared library (.nxvlib) by the kit (CMake nexvyn_add_lib(), `nxv-native lib`), in place
 * of crtbeginS.o. Compile it with -DNXVLIB_NAME="name" -DNXVLIB_VERSION="1.2.3".
 *  - ".nxvlib": the library's identity, read by the loader before anything is mapped (sdk/native/lib/src/nxn_lib_id.h).
 *  - __dso_handle: the handle __cxa_atexit() registers the library's static destructors under. Libraries stay mapped
 *    until the app ends, so those destructors run then with the code still there. */
#include <nexvyn/nxn_lib.h>

#ifndef NXVLIB_NAME
#error "build with -DNXVLIB_NAME=\"<name>\" -DNXVLIB_VERSION=\"<major.minor.patch>\" (the kit does this)"
#endif
#ifndef NXVLIB_VERSION
#error "build with -DNXVLIB_VERSION=\"<major.minor.patch>\""
#endif

/* nothing references it: the link keeps it with -Wl,--undefined=nxvlib_identity (a --gc-sections root) */
__attribute__((section(".nxvlib"), used, aligned(1), visibility("hidden")))
const char nxvlib_identity[] = "nxvlib;abi=" NXN_LIB_ABI_GEN ";name=" NXVLIB_NAME ";version=" NXVLIB_VERSION;

__attribute__((visibility("hidden"))) void* __dso_handle = &__dso_handle;

/* C++ exceptions in windowed mode (W2a). The object carries its own unwinder (libgcc, hidden), whose frame registry is
 * empty: it is linked without crtbegin.o. Nexvyn OS calls this function (when setting native.windowedEh is on) with
 * the .eh_frame of every object of the app (the module and its .nxvlib libraries), so a throw finds the frames of all
 * of them; on = 0 takes a frame list out again before the code is unmapped. object: 128 zeroed bytes per call, owned
 * by Nexvyn OS. The kit links crtend.o last, which ends .eh_frame with the zero word the registry needs.
 * Returns 1 when this object has an unwinder (it uses exceptions), 0 when there is nothing to register with. */
extern void __register_frame_info(const void* begin, void* object) __attribute__((weak, visibility("hidden")));
extern void* __deregister_frame_info(const void* begin) __attribute__((weak, visibility("hidden")));

__attribute__((visibility("default"), used)) int nxw_rt_eh_frames(const void* begin, void* object, int on) {
    if (!__register_frame_info || !__deregister_frame_info || !begin) return 0;
    if (on) __register_frame_info(begin, object);
    else __deregister_frame_info(begin);
    return 1;
}
