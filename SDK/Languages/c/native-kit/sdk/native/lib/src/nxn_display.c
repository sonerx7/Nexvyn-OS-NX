/* Nexvyn Native SDK library - EGL surface + GL core / GLES context on the default native window (nxn_display.h). */
#include "nxn_internal.h"
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <stdlib.h>
#include <string.h>

struct nxn_display {
    EGLDisplay dpy;
    EGLSurface surf;
    EGLContext ctx;
    EGLConfig cfg;
    uint32_t w, h;
    int vsync;
};

static nxn_display* g_open; /* one display per process */

static nxn_result fail(nxn_display* d, const char* what) {
    nxn__set_error("%s failed (EGL 0x%x)", what, eglGetError());
    nxn_log(NXN_LOG_ERROR, "display: %s", nxn_last_error());
    if (d->dpy != EGL_NO_DISPLAY) {
        eglMakeCurrent(d->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (d->ctx != EGL_NO_CONTEXT) eglDestroyContext(d->dpy, d->ctx);
        if (d->surf != EGL_NO_SURFACE) eglDestroySurface(d->dpy, d->surf);
        eglTerminate(d->dpy);
    }
    free(d);
    return NXN_ERR_SYSTEM;
}

nxn_result nxn_display_open(const nxn_display_params* params, nxn_display** out) {
    if (!out) return NXN_ERR_INVALID;
    *out = NULL;
    if (g_open) return NXN_ERR_NOT_READY;
    nxn_display_params p;
    memset(&p, 0, sizeof p);
    if (params) {
        if (params->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
        memcpy(&p, params, params->size < sizeof p ? params->size : sizeof p);
    }
    int gles = p.api == NXN_GFX_GLES;
    if (p.api > NXN_GFX_GLES) return NXN_ERR_UNSUPPORTED;
    if (!p.major) {
        p.major = gles ? 3 : 4;
        p.minor = gles ? 2 : 3;
    }
    if ((!gles && (p.major > 4 || (p.major == 4 && p.minor > 3))) || (gles && (p.major > 3 || (p.major == 3 && p.minor > 2))))
        return NXN_ERR_UNSUPPORTED;
    if (!p.width || !p.height) {
        int docked = appletGetOperationMode() == AppletOperationMode_Console;
        p.width = docked ? 1920 : 1280;
        p.height = docked ? 1080 : 720;
    }
    nxn_display* d = (nxn_display*)calloc(1, sizeof *d);
    if (!d) return NXN_ERR_NO_MEMORY;
    d->dpy = EGL_NO_DISPLAY;
    d->surf = EGL_NO_SURFACE;
    d->ctx = EGL_NO_CONTEXT;
    NWindow* win = nwindowGetDefault();
    nwindowSetDimensions(win, p.width, p.height);
    d->dpy = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (d->dpy == EGL_NO_DISPLAY || !eglInitialize(d->dpy, NULL, NULL)) return fail(d, "eglInitialize");
    if (!eglBindAPI(gles ? EGL_OPENGL_ES_API : EGL_OPENGL_API)) return fail(d, "eglBindAPI");
    EGLint cfg_attr[] = {EGL_RENDERABLE_TYPE, gles ? EGL_OPENGL_ES3_BIT : EGL_OPENGL_BIT,
                         EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
                         EGL_DEPTH_SIZE, p.depth_bits ? (EGLint)p.depth_bits : 24,
                         EGL_STENCIL_SIZE, p.stencil_bits ? (EGLint)p.stencil_bits : 8, EGL_NONE};
    EGLConfig cfg;
    EGLint n = 0;
    if (!eglChooseConfig(d->dpy, cfg_attr, &cfg, 1, &n) || n == 0) return fail(d, "eglChooseConfig");
    d->cfg = cfg;
    d->surf = eglCreateWindowSurface(d->dpy, cfg, win, NULL);
    if (d->surf == EGL_NO_SURFACE) return fail(d, "eglCreateWindowSurface");
    EGLint ctx_attr[16];
    int i = 0;
    if (!gles) {
        ctx_attr[i++] = EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR;
        ctx_attr[i++] = EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR;
    }
    ctx_attr[i++] = EGL_CONTEXT_MAJOR_VERSION_KHR;
    ctx_attr[i++] = (EGLint)p.major;
    ctx_attr[i++] = EGL_CONTEXT_MINOR_VERSION_KHR;
    ctx_attr[i++] = (EGLint)p.minor;
    if (p.flags & NXN_DISPLAY_DEBUG) {
        ctx_attr[i++] = EGL_CONTEXT_FLAGS_KHR;
        ctx_attr[i++] = EGL_CONTEXT_OPENGL_DEBUG_BIT_KHR;
    }
    ctx_attr[i] = EGL_NONE;
    d->ctx = eglCreateContext(d->dpy, cfg, EGL_NO_CONTEXT, ctx_attr);
    if (d->ctx == EGL_NO_CONTEXT) return fail(d, "eglCreateContext");
    if (!eglMakeCurrent(d->dpy, d->surf, d->surf, d->ctx)) return fail(d, "eglMakeCurrent");
    d->vsync = (p.flags & NXN_DISPLAY_NO_VSYNC) ? 0 : 1;
    eglSwapInterval(d->dpy, d->vsync);
    d->w = p.width;
    d->h = p.height;
    g_open = d;
    nxn_log(NXN_LOG_INFO, "display: %s %u.%u, %ux%u", gles ? "GLES" : "GL core", p.major, p.minor, p.width, p.height);
    *out = d;
    return NXN_OK;
}

void nxn_display_close(nxn_display* d) {
    if (!d) return;
    eglMakeCurrent(d->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroyContext(d->dpy, d->ctx);
    eglDestroySurface(d->dpy, d->surf);
    eglTerminate(d->dpy);
    if (g_open == d) g_open = NULL;
    free(d);
}

int nxn__display_teardown(void) {
    if (!g_open) return 0;
    nxn_display_close(g_open);
    return 1;
}

nxn_result nxn_display_swap(nxn_display* d) {
    if (!d) return NXN_ERR_INVALID;
    return eglSwapBuffers(d->dpy, d->surf) ? NXN_OK : NXN_ERR_SYSTEM;
}

nxn_result nxn_display_size(nxn_display* d, uint32_t* width, uint32_t* height) {
    if (!d) return NXN_ERR_INVALID;
    if (width) *width = d->w;
    if (height) *height = d->h;
    return NXN_OK;
}

/* The surface at a given size, made current (0 on failure, d->surf is then EGL_NO_SURFACE). */
static int make_surface(nxn_display* d, uint32_t w, uint32_t h) {
    NWindow* win = nwindowGetDefault();
    if (R_FAILED(nwindowSetDimensions(win, w, h))) return 0;
    d->surf = eglCreateWindowSurface(d->dpy, d->cfg, win, NULL);
    if (d->surf == EGL_NO_SURFACE) return 0;
    if (!eglMakeCurrent(d->dpy, d->surf, d->surf, d->ctx)) {
        eglDestroySurface(d->dpy, d->surf);
        d->surf = EGL_NO_SURFACE;
        return 0;
    }
    eglSwapInterval(d->dpy, d->vsync);
    return 1;
}

nxn_result nxn_display_resize(nxn_display* d, uint32_t width, uint32_t height) {
    if (!d) return NXN_ERR_INVALID;
    if (!width || !height) nxn__output_size(&width, &height, NULL);
    if (width == d->w && height == d->h) return NXN_OK;
    /* nwindowSetDimensions needs the old buffers gone: the surface is destroyed first (the context lives on) */
    eglMakeCurrent(d->dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    eglDestroySurface(d->dpy, d->surf);
    d->surf = EGL_NO_SURFACE;
    if (make_surface(d, width, height)) {
        d->w = width;
        d->h = height;
        nxn_log(NXN_LOG_INFO, "display: resized to %ux%u", width, height);
        return NXN_OK;
    }
    nxn__set_error("resize to %ux%u failed (EGL 0x%x)", width, height, eglGetError());
    nxn_log(NXN_LOG_ERROR, "display: %s", nxn_last_error());
    if (!make_surface(d, d->w, d->h)) nxn_log(NXN_LOG_ERROR, "display: the old size could not be restored either");
    return NXN_ERR_SYSTEM;
}

void* nxn_display_proc(const char* name) { return name ? (void*)eglGetProcAddress(name) : NULL; }
