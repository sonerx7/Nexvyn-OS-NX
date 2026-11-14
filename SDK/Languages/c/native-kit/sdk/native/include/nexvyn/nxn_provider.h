/* Nexvyn Native SDK - Runtime Provider ABI v1 (docs/NATIVE_KIT.md "Runtime providers").
 *
 * A runtime provider is a library package (app.json `"type": "lib"`, catalog `"kind": "runtime"`, and a `"provider"`
 * object, core/pkgv2.h) that runs apps of one language. The OS Runtime Resolver (core/compmgr.h) reads the identity
 * from the manifest and never executes code to choose a provider; only after the identity matches does the OS load the
 * package and call the entry points below.
 *
 * Rules:
 *  - C only. No C++ type, exception or thread_local crosses the boundary.
 *  - Every struct starts with `uint32_t size` = sizeof(the struct the caller compiled against); fields are only added
 *    at the end. NXN_PROVIDER_ABI_GEN is raised by hand only on an incompatible change, never with the OS, SDK or
 *    provider version.
 *  - The provider exports exactly these C symbols (NXN_PROVIDER_*_SYMBOL). nxn_provider_query writes the identity and
 *    must not allocate, start a thread or touch the card; the resolver may call it before anything else.
 *  - nxn_provider_create is called once with the host table and a NUL-terminated UTF-8 JSON object (the app's
 *    manifest subset); the provider keeps no pointer to `config` after the call returns. start/stop may be called again
 *    after a stop; destroy is called once and releases everything the provider allocated.
 *  - A provider that cannot serve the request returns an nxn_result and leaves the app untouched. A failure never stops
 *    the OS or another provider.
 *  - An installed provider for a runtime owns that runtime: the OS never falls back to a different engine for the same
 *    runtime. A provider of another ABI generation is refused with a clean message (NXN_ERR_UNSUPPORTED).
 *  - Memory: the provider owns every pointer it returns; the host owns the host table, the config buffer and the
 *    instance handle slot. Nothing here is freed by the other side.
 *  - Thread: query may be called from any thread. create/start/stop/destroy follow the app's main thread unless the
 *    provider documents otherwise. */
#ifndef NEXVYN_NXN_PROVIDER_H
#define NEXVYN_NXN_PROVIDER_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* Runtime Provider ABI generation this header describes. A package carries the value it was built with. */
#define NXN_PROVIDER_ABI_GEN 1

/* Exported entry point names of a provider package. */
#define NXN_PROVIDER_QUERY_SYMBOL "nxn_provider_query"
#define NXN_PROVIDER_CREATE_SYMBOL "nxn_provider_create"
#define NXN_PROVIDER_START_SYMBOL "nxn_provider_start"
#define NXN_PROVIDER_STOP_SYMBOL "nxn_provider_stop"
#define NXN_PROVIDER_DESTROY_SYMBOL "nxn_provider_destroy"

typedef enum nxn_provider_kind {
    NXN_PROVIDER_RUNTIME = 1, /* runs one script language */
    NXN_PROVIDER_COMPAT = 2,  /* compatibility framework a legacy runtime needs (docs/NATIVE_SDK_N2_PLANI.md 9.8) */
} nxn_provider_kind;

/* Identity of a provider. `runtime` is the canonical runtime id it serves ("lua", "js", "python", ...);
 * `capabilities` is a NULL-terminated list of lower-case ids (may be NULL). Both strings live as long as the
 * provider package stays loaded. */
typedef struct nxn_provider_info {
    uint32_t size;         /* sizeof(nxn_provider_info) */
    uint32_t abi_gen;      /* NXN_PROVIDER_ABI_GEN the provider implements */
    const char* id;        /* "nexvyn.runtime.lua" */
    const char* version;   /* provider/engine version, "5.4.7" */
    nxn_provider_kind kind;
    const char* runtime;   /* canonical runtime id */
    const char* const* capabilities;
} nxn_provider_info;

typedef struct nxn_provider nxn_provider; /* opaque instance */

/* What the OS gives a provider. `api_gen` equals NXN_PROVIDER_ABI_GEN; `user` is passed back to log unchanged. The
 * logging call may be NULL; a provider then reports through its return codes only. Reserved fields are zero in v1. */
typedef struct nxn_provider_host {
    uint32_t size;   /* sizeof(nxn_provider_host) */
    uint32_t api_gen;
    void* user;
    void (*log)(void* user, int level, const char* message); /* level: 0 info, 1 warning, 2 error */
    void (*reserved[4])(void);
} nxn_provider_host;

/* Writes the provider identity. Called by the resolver before create; must not allocate or start threads. */
typedef nxn_result (*nxn_provider_query_fn)(uint32_t abi_gen, nxn_provider_info* out);

/* Creates one instance for one app. `config` is a NUL-terminated UTF-8 JSON object; `config_size` includes the NUL. */
typedef nxn_result (*nxn_provider_create_fn)(const nxn_provider_host* host, const char* config, size_t config_size,
                                             nxn_provider** out);

/* Starts or resumes the app. */
typedef nxn_result (*nxn_provider_start_fn)(nxn_provider* provider);

/* Pauses the app; may be NULL. A stop without a start is a no-op. */
typedef void (*nxn_provider_stop_fn)(nxn_provider* provider);

/* Releases the instance; may be NULL only when create never succeeded. */
typedef void (*nxn_provider_destroy_fn)(nxn_provider* provider);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_PROVIDER_H */
