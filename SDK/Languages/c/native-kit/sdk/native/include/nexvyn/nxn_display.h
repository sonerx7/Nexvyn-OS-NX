/* Nexvyn Native SDK - display: one full-screen EGL surface with an OpenGL 4.x core or OpenGL ES 3.2 context.
 *
 * Inside Nexvyn OS the surface is the window's content (framebuffer 0), one display per app; the app draws with its own
 * context and Nexvyn OS shows the newest frame. Stand-alone .nro builds talk to EGL on the default native window
 * directly (no SDL video). Apps that already use SDL2 for their window keep doing so and simply do not call
 * nxn_display_open; everything else in nxn_* still works.
 *
 * Threads: the thread that calls nxn_display_open owns the display. Every GL call, nxn_display_swap,
 * nxn_display_size, nxn_display_resize and nxn_display_close must come from that one thread (the context is current
 * only there; another thread has no context). Memory: the nxn_display* handle is owned by the library and freed by
 * nxn_display_close, or when the app ends. */
#ifndef NEXVYN_NXN_DISPLAY_H
#define NEXVYN_NXN_DISPLAY_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_display nxn_display; /* opaque */

typedef enum nxn_gfx_api {
    NXN_GFX_GL_CORE = 0, /* desktop OpenGL, core profile (default 4.3) */
    NXN_GFX_GLES = 1     /* OpenGL ES (default 3.2) */
} nxn_gfx_api;

enum {
    NXN_DISPLAY_NO_VSYNC = 1u << 0, /* swap without waiting for the vertical blank */
    NXN_DISPLAY_DEBUG = 1u << 1     /* request a debug context */
};

typedef struct nxn_display_params {
    uint32_t size;
    uint32_t api;            /* nxn_gfx_api */
    uint32_t major, minor;   /* 0, 0: the default for the api */
    uint32_t width, height;  /* 0, 0: 1920x1080 when docked, 1280x720 handheld (at open time) */
    uint32_t depth_bits;     /* 0 = 24 */
    uint32_t stencil_bits;   /* 0 = 8 */
    uint32_t flags;          /* NXN_DISPLAY_* */
} nxn_display_params;

/* Creates the surface and context and makes it current on the calling thread. params may be NULL (GL 4.3 core).
 * Thread: the app thread that will render (usually the main thread); once. Memory: *out is a library-owned handle;
 * `params` is only read during the call. */
NXN_API nxn_result nxn_display_open(const nxn_display_params* params, nxn_display** out);
/* Thread: the display's thread. Memory: frees the handle; it must not be used afterwards. */
NXN_API void nxn_display_close(nxn_display* d);
/* Publishes the frame and paces to the display (counts as "alive" for the not-responding check).
 * Thread: the display's thread. Memory: none. */
NXN_API nxn_result nxn_display_swap(nxn_display* d);
/* Thread: the display's thread. Memory: written into the caller's variables (either may be NULL). */
NXN_API nxn_result nxn_display_size(nxn_display* d, uint32_t* width, uint32_t* height);
/* Gives the surface a new size (docked <-> handheld, see nxn_event.h): the EGL surface is recreated at width x height
 * (0, 0: the size of the current mode) and the same context stays current. Call it on the thread that owns the
 * context, between frames; reset glViewport afterwards. The size is never changed behind the app's back: an app that
 * does not call this keeps its surface and the system scales it. On failure the old size is restored when possible
 * (NXN_ERR_SYSTEM; nxn_last_error() says why). Thread: the display's thread. Memory: none. */
NXN_API nxn_result nxn_display_resize(nxn_display* d, uint32_t width, uint32_t height);
/* GL / GLES entry points for a loader (glad: gladLoadGLLoader((GLADloadproc)nxn_display_proc)).
 * Thread: call it, and the functions it returns, only on the display's thread. Memory: the returned pointers are
 * static for the life of the app and are never freed. */
NXN_API void* nxn_display_proc(const char* name);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_DISPLAY_H */
