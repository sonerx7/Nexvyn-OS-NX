/* NexGFX backend table: how the kit's ngfx_* shell (sdk/native/nexgfx/nexgfx_native.cpp) reaches a renderer that Nexvyn OS
 * provides. Apps do not call this; they call nexgfx_native.h, whose functions and behaviour stay the same whichever renderer
 * answers (NATIVE_KIT.md 3.2.5 "NexGFX in a native app").
 *
 * Rules: the import name, NXN_NGFX_BACKEND_GEN and the table layout are part of the frozen-to-be ABI.
 *  - nxn_ngfx_backend(gen) returns the table of generation `gen`, or NULL: the system has no backend, the user turned it off
 *    (setting native.ngfxHost), or it does not serve that generation. The shell then uses the renderer compiled into the app.
 *    The shell imports it weakly, so an app built with it still loads on a system that does not have the function.
 *  - The generation is raised by hand only for a change an older shell cannot follow (never derived from an OS, SDK or
 *    build version). Within a generation the table only grows at the end: `size` says how much the host filled, a function
 *    exists when `size` covers its field. The table is the host's (static, never freed, never written by the app).
 *  - The drawing target is a surface, not "the app's GL framebuffer": `surfaces` says which kinds render() can draw into
 *    and the shell asks for one at device_create. Today's backend draws with OpenGL into a GL framebuffer of the app's
 *    current context (NGFX_SURFACE_GL_FBO). A backend that cannot draw into the app's GL context (deko3d) would offer a
 *    surface Nexvyn OS composes itself; an app that needs a GL framebuffer then keeps its own renderer.
 *  - Every function runs on the calling app thread, in the app's GL context, under the same rules as nexgfx_native.h; the
 *    backend never touches Nexvyn OS's own GL context or state. Errors are NGFX_ERR_*; error() has the text of the last
 *    failure on this thread. Structs follow nxn_base.h: `size` first, fields only appended, no field in implicit padding. */
#ifndef NEXGFX_BACKEND_H
#define NEXGFX_BACKEND_H
#include "nxn_base.h"
#include "nexgfx_native.h"

#ifdef __cplusplus
extern "C" {
#endif

#define NXN_NGFX_BACKEND_GEN 1

/* Surface kinds (one bit each; ngfx_surface.kind holds one, nxn_ngfx_table.surfaces the set a backend can draw into). */
enum {
    NGFX_SURFACE_GL_FBO = 1u,  /* a framebuffer object of the app's current GL context; handle = its name (0 = default) */
    NGFX_SURFACE_WINDOW = 2u   /* reserved: the app's window content, composed by Nexvyn OS (not offered yet) */
};

typedef struct ngfx_surface {
    uint32_t size;      /* sizeof(ngfx_surface) */
    uint32_t kind;      /* NGFX_SURFACE_* */
    uint32_t width, height; /* pixels */
    uint64_t handle;    /* meaning by kind (GL_FBO: the framebuffer name) */
    uint32_t flags;     /* 0 */
    uint32_t reserved;  /* 0 */
} ngfx_surface;

typedef struct ngfx_backend_impl ngfx_backend_impl; /* a backend's device; opaque to the app */

typedef struct nxn_ngfx_table {
    uint32_t size;        /* bytes the host filled */
    uint32_t gen;         /* NXN_NGFX_BACKEND_GEN of this table */
    uint32_t api_version; /* (major << 16) | minor of the ngfx_* behaviour the backend implements */
    uint32_t surfaces;    /* NGFX_SURFACE_* kinds render() can draw into */
    const char* name;     /* short backend name for logs ("gl") */
    const char* (*error)(void);
    int (*device_create)(const ngfx_device_desc* desc, uint32_t surface_kind, ngfx_backend_impl** out);
    void (*device_destroy)(ngfx_backend_impl* dev);
    int (*device_caps_get)(ngfx_backend_impl* dev, ngfx_device_caps* out);
    int (*device_prepare)(ngfx_backend_impl* dev, uint32_t* done, uint32_t* total);
    int (*scene_load)(ngfx_backend_impl* dev, const ngfx_scene_desc* desc, ngfx_scene* out);
    int (*scene_step)(ngfx_backend_impl* dev, ngfx_scene scene, uint64_t budget_ns, ngfx_scene_status* out);
    int (*scene_info_get)(ngfx_backend_impl* dev, ngfx_scene scene, ngfx_scene_info* out);
    int (*scene_chunk_bounds)(ngfx_backend_impl* dev, ngfx_scene scene, uint32_t index, float bmin[3], float bmax[3]);
    void (*scene_free)(ngfx_backend_impl* dev, ngfx_scene scene);
    int (*render)(ngfx_backend_impl* dev, ngfx_scene scene, const ngfx_view* view, const ngfx_surface* target,
                  ngfx_frame_stats* stats);
} nxn_ngfx_table;

/* Thread: any app thread. Memory: the table belongs to Nexvyn OS. */
NXN_API const nxn_ngfx_table* nxn_ngfx_backend(uint32_t gen);

#ifdef __cplusplus
}
#endif
#endif /* NEXGFX_BACKEND_H */
