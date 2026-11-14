/* Nexvyn Native SDK - windowed mode (NATIVE_KIT.md 3.2). Linked into every windowed app (.nxvmod) by the
 * kit (libnexvyn_window.a; `nxv-native build --windowed`, CMake nexvyn_add_windowed(), `make windowed`).
 *
 * In windowed mode the app runs inside Nexvyn OS's process and Nexvyn OS implements the nxn_* functions: the app
 * imports them (and the C library) from Nexvyn OS's host import set (sdk/native/toolchain/nxwin_imports.txt), so the
 * same source works in both modes. This object only carries what the module itself must have:
 *  - ".nxnwin": the module's identity, read by Nexvyn OS before anything is mapped. NXN_ABI_GEN and NXW_HOST_GEN are
 *    raised by hand only; nothing here follows the OS, SDK or build version.
 *  - __dso_handle: the handle __cxa_atexit() registers the app's static destructors under (they run when the app ends,
 *    on its own thread, while its code is still mapped). */
#include <nexvyn/nxn_base.h>

/* Host generation the module was built for (source/runtimes/nxwin_rules.h kHostGen in Nexvyn OS). */
#define NXW_HOST_GEN 1
#define NXW_STR2(x) #x
#define NXW_STR(x) NXW_STR2(x)

/* nothing references it: the link keeps it with -Wl,--undefined=nxnwin_identity (a --gc-sections root) */
__attribute__((section(".nxnwin"), used, aligned(1), visibility("hidden")))
const char nxnwin_identity[] = "nxnwin;abi=" NXW_STR(NXN_ABI_GEN) ";host=" NXW_STR(NXW_HOST_GEN);

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
