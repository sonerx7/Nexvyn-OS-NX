/* NexGFX for native apps: the ngfx_* C API a windowed or full-screen native app uses to draw baked 3D scenes with the PBR
 * renderer in its own OpenGL context (docs/NATIVE_KIT.en.md "NexGFX in a native app").
 *
 * Architecture: these functions are a thin shell compiled into the app (sdk/native/nexgfx/nexgfx_native.cpp, listed in the
 * app's SOURCES). ngfx_device_create first asks Nexvyn OS for its renderer (nxn_ngfx_backend, nexgfx_backend.h: a versioned
 * table); when the system has none, has it turned off (setting native.ngfxHost) or answers another generation, the shell uses
 * the renderer compiled into the app (the same code). Either way the renderer owns GL objects and state of the app's own
 * context (nxn_display_open); Nexvyn OS's NexGFX (g3d) is bound to the desktop's context and is never touched. Every GL call
 * goes through the app's entry points (nxn_display_proc), so the host's GPU lock keeps the one shared command stream safe. A
 * later Nexvyn OS can put a faster backend behind the table; an app built with this shell gets it without being rebuilt.
 *
 * Rules (the same as the OS side, source/nexgfx/nexgfx.h): plain C, fixed-size fields only; every struct starts with `size`
 * (the caller sets sizeof, a newer library fills only what an older caller knows); functions and fields are only added,
 * NGFX_NATIVE_API_MINOR grows with additions; a device is an opaque pointer, a scene an opaque uint32_t handle (0 = none).
 * Threads: every call comes from the one thread whose GL context is current (the app's render thread), except that the
 * library starts its own worker thread per scene to read files (it never touches OpenGL). Memory: the library owns every
 * object; free scenes with ngfx_scene_free and the device with ngfx_device_destroy (the app's end frees both anyway).
 * Errors: calls return NGFX_OK (0) or a negative NGFX_ERR_*; ngfx_native_error() has the text of the last failure on the thread.
 * NGFX_ERR_* is its own set: never compare an ngfx_* result with NXN_ERR_* (-5 is NGFX_ERR_NOMEM here, NXN_ERR_DENIED there).
 * Frozen with the Native ABI v1 (sdk/native/toolchain/nxn_abi_v1.json): signatures, layouts and values are only added.
 * A damaged scene file ends as NGFX_ERR_FORMAT in ngfx_scene_step, never as a crash. Feature bit: NXN_CAP_NEXGFX (nxn_app.h)
 * says the host's GL context offers what the device needs (OpenGL 4.3 core). */
#ifndef NEXGFX_NATIVE_H
#define NEXGFX_NATIVE_H
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define NGFX_NATIVE_API_MAJOR 1
#define NGFX_NATIVE_API_MINOR 0

enum {
    NGFX_OK = 0,
    NGFX_ERR_INVALID = -1,  /* bad argument, wrong thread state, scene or device not ready */
    NGFX_ERR_GL = -2,       /* OpenGL missing, too old, or a shader / buffer failed */
    NGFX_ERR_FILE = -3,     /* a scene or texture file cannot be opened */
    NGFX_ERR_FORMAT = -4,   /* the baked file is damaged or not a baked scene (nxv-asset check) */
    NGFX_ERR_NOMEM = -5,
    NGFX_ERR_LIMIT = -6     /* too many scenes at once (4 per device) */
};

typedef struct ngfx_device ngfx_device; /* opaque; one per GL context */
typedef uint32_t ngfx_scene;            /* opaque handle, 0 = none */

/* (major << 16) | minor of this API. */
uint32_t ngfx_native_version(void);
/* Text of the last failure on this thread ("" if none). */
const char* ngfx_native_error(void);

typedef struct ngfx_device_desc {
    uint32_t size;                      /* sizeof(ngfx_device_desc) */
    void* (*get_proc)(const char* name); /* GL entry point loader; NULL: nxn_display_proc (the app's trampolines) */
    uint32_t flags;                     /* 0 */
    uint32_t reserved;                  /* 0 (was tail padding; a new field never goes into padding) */
} ngfx_device_desc;

/* Creates the renderer for the GL context that is current on this thread (desc may be NULL). Needs OpenGL 4.3 core. */
int ngfx_device_create(const ngfx_device_desc* desc, ngfx_device** out);
void ngfx_device_destroy(ngfx_device* dev);

typedef struct ngfx_device_caps {
    uint32_t size;
    uint32_t api_version;               /* ngfx_native_version() of the library that answered */
    uint8_t bc_native, bc_srgb, rgtc, shaders_ready; /* BC1/BC3 on the GPU, their sRGB forms, BC5, programs built */
    float max_anisotropy;
    uint64_t gpu_bytes;                 /* textures + buffers + targets the device holds on the GPU */
    char gl[96], device[96];            /* driver strings, NUL-terminated (cut to fit) */
} ngfx_device_caps;
int ngfx_device_caps_get(ngfx_device* dev, ngfx_device_caps* out);

/* Builds one shader program per call (a link can take 200+ ms: call it once per frame behind a progress bar). Returns 1 when
 * every program is ready, 0 while more calls are needed, a negative error if one failed. *done / *total may be NULL. */
int ngfx_device_prepare(ngfx_device* dev, uint32_t* done, uint32_t* total);

typedef struct ngfx_scene_desc {
    uint32_t size;
    const char* scene_path;             /* NAME.nxsc (nxv-asset bake) */
    const char* texture_path;           /* NAME.nxtx */
    uint32_t flags;                     /* 0; NGFX_SCENE_SMALL_READS (1) reads with the libc's default stdio buffer, to measure what a
                                           1 MB buffer saves (a diagnostic, older hosts ignore it) */
    uint32_t reserved;                  /* 0 (was tail padding) */
} ngfx_scene_desc;
/* Starts loading: a worker thread reads and checks the files, ngfx_scene_step uploads. Up to 4 scenes per device. */
int ngfx_scene_load(ngfx_device* dev, const ngfx_scene_desc* desc, ngfx_scene* out);

typedef struct ngfx_scene_status {
    uint32_t size;
    int32_t failed;                     /* 1 when loading failed: error has the reason */
    uint32_t geometry_ready, ready;     /* drawable (textures may still stream), fully loaded */
    float progress;                     /* 0..1 of the bytes read */
    uint32_t textures_total, textures_uploaded;
    uint64_t gpu_bytes;                 /* this scene's textures + buffers */
    char error[160];
} ngfx_scene_status;
/* Uploads for at most about budget_ns (geometry in 3 MB slices, then textures) and reports. Call every frame while loading
 * (the frame never stalls on a file or a big upload); it is cheap once the scene is ready. */
int ngfx_scene_step(ngfx_device* dev, ngfx_scene scene, uint64_t budget_ns, ngfx_scene_status* out);

typedef struct ngfx_scene_info {
    uint32_t size;
    float bmin[3], bmax[3], radius;
    uint32_t has_camera, has_sun;
    float camera[5], fov_deg;           /* x y z yaw pitch (radians), vertical field of view; from the file */
    float sun_dir[3], sun_color[3];     /* direction towards the sun; sun_dir is a default when the file has none */
    uint32_t materials, textures, chunks, vertices, triangles;
} ngfx_scene_info;
/* Valid once geometry_ready. */
int ngfx_scene_info_get(ngfx_device* dev, ngfx_scene scene, ngfx_scene_info* out);
/* Bounds of chunk `index` (0 <= index < ngfx_scene_info.chunks), for tools like camera paths. */
int ngfx_scene_chunk_bounds(ngfx_device* dev, ngfx_scene scene, uint32_t index, float bmin[3], float bmax[3]);
void ngfx_scene_free(ngfx_device* dev, ngfx_scene scene);

enum { NGFX_VIEW_SHADOWS = 1, NGFX_VIEW_FXAA = 2 };
typedef struct ngfx_view {
    uint32_t size;
    float eye[3], yaw, pitch, fov_deg;  /* yaw 0 looks along -Z, radians; fov is vertical */
    uint32_t width, height;             /* size of the target (pixels) */
    float render_scale;                 /* 0.25..1: the scene is drawn at this fraction and scaled up by the post pass (0 = 1) */
    uint32_t flags;                     /* NGFX_VIEW_* */
    float exposure;                     /* 0 = 1 */
    uint32_t target_fbo;                /* framebuffer to draw into; 0 = the app's default framebuffer (the window) */
} ngfx_view;

typedef struct ngfx_frame_stats {
    uint32_t size;
    uint32_t draws, shadow_draws, chunks_seen, chunks_total, triangles, render_width, render_height;
} ngfx_frame_stats;
/* Draws sky + scene (scene 0, or one not yet drawable: the sky only) with PBR (metallic-roughness, normal, emissive, one sun
 * with a fitted PCF shadow map, hemisphere ambient, fog, alpha test and blend), ACES tone mapping and optional FXAA into the
 * target. It changes the GL state of the app's context (bindings, viewport, blend, depth) and leaves the target bound with
 * depth test and blend off. Needs ngfx_device_prepare to have returned 1. */
int ngfx_render(ngfx_device* dev, ngfx_scene scene, const ngfx_view* view, ngfx_frame_stats* stats);

#ifdef __cplusplus
}
#endif
#endif /* NEXGFX_NATIVE_H */
