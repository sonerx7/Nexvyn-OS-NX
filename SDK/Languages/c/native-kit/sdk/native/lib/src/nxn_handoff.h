/* Nexvyn Native SDK library - the hand-off and return record formats (NATIVE_KIT.md, "Hand-off").
 * Pure C without libnx, so the host unit tests (tests/test_native.cpp) compile it next to Nexvyn OS's own writer and
 * reader (source/runtimes/native_handoff.cpp) and check that both sides agree.
 *
 * Both files are UTF-8 text: a header line ("nxn-handoff 1" / "nxn-return 1"), then key=value lines. Unknown keys
 * are ignored, keys are only ever added; a reader accepts any version >= 1 with the same header word. */
#ifndef NEXVYN_NXN_HANDOFF_H
#define NEXVYN_NXN_HANDOFF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NXN_HANDOFF_VERSION 1
#define NXN_RETURN_VERSION 1
#define NXN_HANDOFF_ARG "--nxn-handoff="
#define NXN__PATH 512

typedef struct nxn__handoff {
    int version;  /* 0 = not read */
    char host[32];
    char host_nro[NXN__PATH]; /* where to return ("" = no return) */
    char os_version[32], sdk_version[16], native_version[16];
    char app_id[128], app_version[32];
    char bundle[NXN__PATH], data[NXN__PATH], cache[NXN__PATH], log[NXN__PATH], ret[NXN__PATH];
    char user[64], language[16], theme[8], launch_id[32];
    uint32_t accent;
    uint64_t confirm, cancel;
} nxn__handoff;

typedef struct nxn__return_rec {
    int version;
    char launch_id[32];
    char state[12];   /* running | exited | crashed */
    char reason[12];  /* normal | user | error | crash */
    int32_t code;
    char message[256];
    char crash_kind[64];
    char crash_thread[48];
    uint64_t crash_pc, crash_lr, crash_far; /* pc / lr as offsets from the .nro's load address */
    int64_t time;
} nxn__return_rec;

/* Parses a hand-off file's text. Returns 1 when the header is right (fields not in the text stay as they were). */
int nxn__handoff_parse(const char* text, size_t len, nxn__handoff* out);
/* Parses / formats a return record. format returns the length written (always NUL-terminated), 0 if cap is too small. */
int nxn__return_parse(const char* text, size_t len, nxn__return_rec* out);
size_t nxn__return_format(const nxn__return_rec* r, char* out, size_t cap);

/* The value of argv's --nxn-handoff=<path>, or NULL. */
const char* nxn__handoff_arg(int argc, char** argv);
/* 1 when rel is a safe relative path (no "..", no leading '/' or '\\', no ':'). */
int nxn__rel_ok(const char* rel);

#ifdef __cplusplus
}
#endif

#endif /* NEXVYN_NXN_HANDOFF_H */
