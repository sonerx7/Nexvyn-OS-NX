/* Nexvyn Native SDK library - the identity of a shared library (.nxvlib) and semver rules. Pure C with no libnx, so
 * the desktop tests compile it too (tests/test_nxelf.cpp).
 *
 * A library carries its identity in an allocated ".nxvlib" section (sdk/native/toolchain/nxvlib_support.c writes it):
 *   "nxvlib;abi=<NXN_LIB_ABI_GEN>;name=<name>;version=<major.minor.patch>"
 * The ABI generation is a hand-raised number; the version is the library's own semver. Neither comes from the OS
 * version, a build or a header digest. */
#ifndef NEXVYN_NXN_LIB_ID_H
#define NEXVYN_NXN_LIB_ID_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct nxn__semver {
    unsigned major, minor, patch;
    int pre; /* 1 for a pre-release ("1.2.0-beta.1" < "1.2.0") */
} nxn__semver;

typedef struct nxn__lib_id {
    char abi[16];
    char name[64];
    char version[32];
    nxn__semver ver;
} nxn__lib_id;

/* "1", "1.2", "1.2.3", "1.2.3-beta.1" (a "+build" suffix is ignored). 1 when valid. */
int nxn__semver_parse(const char* s, nxn__semver* out);
/* <0, 0, >0 like strcmp. */
int nxn__semver_cmp(const nxn__semver* a, const nxn__semver* b);
/* Reads the identity from a library file image: 0 ok, 1 no ".nxvlib" section, 2 a section that does not parse. */
int nxn__lib_id_read(const unsigned char* img, size_t size, nxn__lib_id* out);
/* Parses the identity text itself (n bytes, may end with NULs). 1 when valid. */
int nxn__lib_id_parse(const char* text, size_t n, nxn__lib_id* out);

#ifdef __cplusplus
}
#endif
#endif /* NEXVYN_NXN_LIB_ID_H */
