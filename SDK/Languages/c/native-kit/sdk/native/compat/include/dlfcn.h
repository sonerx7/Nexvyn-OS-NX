/* Nexvyn compat: <dlfcn.h>. dlopen(file) loads a Nexvyn shared library (.nxvlib) through nxn_lib_open (needs
 * libnexvyn_native; "libfoo.so" also finds libfoo.nxvlib / foo.nxvlib); a failure leaves a clear dlerror() text.
 * The mode flags are accepted; RTLD_NOLOAD only returns a library dlopen opened before. dlopen(NULL) /
 * dlsym(RTLD_DEFAULT, ...) search the table filled by nxc_dl_register(), then the app's exports and open libraries. */
#ifndef NEXVYN_COMPAT_DLFCN_H
#define NEXVYN_COMPAT_DLFCN_H

#ifdef __cplusplus
extern "C" {
#endif

#define RTLD_LAZY     0x1
#define RTLD_NOW      0x2
#define RTLD_GLOBAL   0x100
#define RTLD_LOCAL    0
#define RTLD_NOLOAD   0x4
#define RTLD_NODELETE 0x1000
#define RTLD_DEFAULT  ((void*)0)
#define RTLD_NEXT     ((void*)-1)

typedef struct {
    const char* dli_fname;
    void* dli_fbase;
    const char* dli_sname;
    void* dli_saddr;
} Dl_info;

void* dlopen(const char* file, int mode);
void* dlsym(void* handle, const char* name);
int dlclose(void* handle);
char* dlerror(void);
int dladdr(const void* addr, Dl_info* info);

#ifdef __cplusplus
}
#endif
#endif
