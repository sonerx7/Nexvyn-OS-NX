/* Nexvyn OS SDL2 driver (windowed native apps): video, GL context, window events, touch, keyboard, mouse, text, power.
 * Added to SDL2 (zlib license) by the Nexvyn native kit; see sdk/native/sdl2/README.md. Not part of upstream SDL.
 *
 * The app owns one SDL window = the content area of its Nexvyn OS window (or full screen inside Nexvyn OS). The GL
 * context is the app's nxn display (nxn_display_open): SDL_GL_SwapWindow publishes the frame. Everything the driver
 * calls is nxn_*; no libnx, no EGL: the module's imports stay inside Nexvyn OS's host import set. */
#include "../../SDL_internal.h"

#if SDL_VIDEO_DRIVER_NEXVYN

#include "SDL_timer.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_events_c.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../events/SDL_mouse_c.h"
#include "../../events/SDL_touch_c.h"
#include "../../events/SDL_windowevents_c.h"

#include "SDL_nexvynvideo.h"

static NEXVYN_VideoData *g_video;

/* ------------------------------------------------------------------ input sample shared with the joystick driver */

const nxn_input_state *NEXVYN_PollInput(int force)
{
    static nxn_input_state state;
    static Uint64 stamp;
    Uint64 now = SDL_GetPerformanceCounter();
    if (!force && stamp && (now - stamp) * 1000 < SDL_GetPerformanceFrequency() * 2) {
        return &state;
    }
    nxn_input_state s = NXN_STRUCT_INIT(nxn_input_state);
    if (nxn_input_poll(&s) == NXN_OK) {
        /* "pressed" and "released" are edges since the previous poll: keep the ones nobody read yet */
        s.pressed |= state.pressed & ~s.released;
        s.released |= state.released & ~s.pressed;
        state = s;
    }
    stamp = now;
    return &state;
}

/* ------------------------------------------------------------------ device */

static void NEXVYN_DeleteDevice(SDL_VideoDevice *device)
{
    SDL_free(device);
}

static int NEXVYN_CreateWindow(SDL_VideoDevice *_this, SDL_Window *window)
{
    NEXVYN_VideoData *vd = g_video;
    if (!vd) {
        return SDL_SetError("nexvyn video driver is not initialized");
    }
    if (vd->window) {
        return SDL_SetError("a Nexvyn OS window holds one SDL window");
    }
    window->driverdata = vd;
    vd->window = window;
    vd->focused = 1;
    SDL_SetMouseFocus(window);
    SDL_SetKeyboardFocus(window);
    return 0;
}

static void NEXVYN_DestroyWindow(SDL_VideoDevice *_this, SDL_Window *window)
{
    NEXVYN_VideoData *vd = g_video;
    if (vd && vd->window == window) {
        vd->window = NULL;
    }
    window->driverdata = NULL;
}

static void NEXVYN_NoWindowOp(SDL_VideoDevice *_this, SDL_Window *window) {}

static void NEXVYN_GetDisplayModes(SDL_VideoDevice *_this, SDL_VideoDisplay *display)
{
    SDL_AddDisplayMode(display, &display->current_mode);
}

static int NEXVYN_SetDisplayMode(SDL_VideoDevice *_this, SDL_VideoDisplay *display, SDL_DisplayMode *mode)
{
    return 0; /* the content area decides the size, not the app */
}

/* ------------------------------------------------------------------ GL (the app's nxn display) */

static void NEXVYN_GLDefaultProfileConfig(SDL_VideoDevice *_this, int *mask, int *major, int *minor)
{
    *mask = SDL_GL_CONTEXT_PROFILE_ES;
    *major = 2;
    *minor = 0;
}

static int NEXVYN_GLLoadLibrary(SDL_VideoDevice *_this, const char *path)
{
    return 0; /* nothing to load: the entry points come from nxn_display_proc */
}

static void NEXVYN_GLUnloadLibrary(SDL_VideoDevice *_this) {}

static void *NEXVYN_GLGetProcAddress(SDL_VideoDevice *_this, const char *proc)
{
    return nxn_display_proc(proc);
}

static SDL_GLContext NEXVYN_GLCreateContext(SDL_VideoDevice *_this, SDL_Window *window)
{
    NEXVYN_VideoData *vd = g_video;
    if (!vd || vd->gl) {
        SDL_SetError("a Nexvyn OS window holds one GL context");
        return NULL;
    }
    nxn_display_params p = NXN_STRUCT_INIT(nxn_display_params);
    int mask = _this->gl_config.profile_mask;
    int major = _this->gl_config.major_version, minor = _this->gl_config.minor_version;
    if (mask == SDL_GL_CONTEXT_PROFILE_COMPATIBILITY) {
        SDL_SetError("the OpenGL compatibility profile is not available (core 4.3 or OpenGL ES 3.2)");
        return NULL;
    }
    if (mask == SDL_GL_CONTEXT_PROFILE_ES) {
        p.api = NXN_GFX_GLES;
        if (major >= 3) { /* ES 2.0 asks for the default: 3.2 runs ES 2 shaders too */
            p.major = (uint32_t)major;
            p.minor = (uint32_t)minor;
        }
    } else {
        p.api = NXN_GFX_GL_CORE;
        if (major > 3 || (major == 3 && minor >= 2)) {
            p.major = (uint32_t)major;
            p.minor = (uint32_t)minor;
        }
    }
    p.depth_bits = (uint32_t)_this->gl_config.depth_size;
    p.stencil_bits = (uint32_t)_this->gl_config.stencil_size;
    if (_this->gl_config.flags & SDL_GL_CONTEXT_DEBUG_FLAG) {
        p.flags |= NXN_DISPLAY_DEBUG;
    }
    /* a fullscreen or resizable window follows the content area; a fixed-size one keeps its size (scaled by Nexvyn OS) */
    int follow = (window->flags & (SDL_WINDOW_FULLSCREEN | SDL_WINDOW_RESIZABLE)) != 0;
    if (!follow) {
        p.width = (uint32_t)window->w;
        p.height = (uint32_t)window->h;
    }
    NEXVYN_GLContext *ctx = (NEXVYN_GLContext *)SDL_calloc(1, sizeof(*ctx));
    if (!ctx) {
        SDL_OutOfMemory();
        return NULL;
    }
    nxn_result r = nxn_display_open(&p, &ctx->display);
    if (r != NXN_OK) {
        SDL_SetError("nxn_display_open: %s", nxn_last_error());
        SDL_free(ctx);
        return NULL;
    }
    ctx->window = window;
    ctx->follow = follow;
    vd->gl = ctx;
    /* what the window really has: Nexvyn OS always renders into a 24 bit depth + 8 bit stencil buffer, whatever was asked
       (SDL_GL_GetAttribute reports these, patched in SDL_video.c) */
    _this->gl_config.depth_size = 24;
    _this->gl_config.stencil_size = 8;
    uint32_t w = 0, h = 0;
    if (nxn_display_size(ctx->display, &w, &h) == NXN_OK && w && h && ((int)w != window->w || (int)h != window->h)) {
        SDL_SendWindowEvent(window, SDL_WINDOWEVENT_RESIZED, (int)w, (int)h);
    }
    return (SDL_GLContext)ctx;
}

static int NEXVYN_GLMakeCurrent(SDL_VideoDevice *_this, SDL_Window *window, SDL_GLContext context)
{
    /* one context, current on the thread that made it for good: "no context" cannot be expressed and is accepted */
    if (context && context != (SDL_GLContext)(g_video ? g_video->gl : NULL)) {
        return SDL_SetError("unknown GL context");
    }
    return 0;
}

static int NEXVYN_GLSetSwapInterval(SDL_VideoDevice *_this, int interval)
{
    /* 1 = vsync, 0 = "do not wait", -1 = adaptive: all accepted (ports ask for 0 and treat failure as a warning). A window
       paces to the OS frame; it does not wait only when the developer setting perf.uncapped is on. So 0 and -1 keep that
       behavior and SDL_GL_GetSwapInterval() tells the truth (1 unless the OS is uncapped, which an app cannot see). */
    if (interval == 1 || interval == 0 || interval == -1) {
        return 0;
    }
    return SDL_SetError("swap interval %d is not available (0, 1 or -1)", interval);
}

static int NEXVYN_GLGetSwapInterval(SDL_VideoDevice *_this)
{
    return 1;
}

static int NEXVYN_GLSwapWindow(SDL_VideoDevice *_this, SDL_Window *window)
{
    NEXVYN_VideoData *vd = g_video;
    if (!vd || !vd->gl) {
        return SDL_SetError("no GL context");
    }
    if (nxn_display_swap(vd->gl->display) != NXN_OK) {
        return SDL_SetError("nxn_display_swap: %s", nxn_last_error());
    }
    return 0;
}

static void NEXVYN_GLDeleteContext(SDL_VideoDevice *_this, SDL_GLContext context)
{
    NEXVYN_VideoData *vd = g_video;
    NEXVYN_GLContext *ctx = (NEXVYN_GLContext *)context;
    if (!ctx) {
        return;
    }
    if (ctx->display) {
        nxn_display_close(ctx->display);
    }
    if (vd && vd->gl == ctx) {
        vd->gl = NULL;
    }
    SDL_free(ctx);
}

/* ------------------------------------------------------------------ events */

static void NEXVYN_PollTouch(NEXVYN_VideoData *vd, const nxn_input_state *in)
{
    SDL_Window *window = vd->window;
    if (!window) {
        return;
    }
    float tw = 1280.f, th = 720.f;
    uint32_t dw = 0, dh = 0;
    if (vd->gl && nxn_display_size(vd->gl->display, &dw, &dh) == NXN_OK && dw && dh) {
        tw = (float)dw; /* in a window, touches are display pixels */
        th = (float)dh;
    }
    if (!vd->touch_added) {
        SDL_AddTouch((SDL_TouchID)1, SDL_TOUCH_DEVICE_DIRECT, "Switch");
        vd->touch_added = 1;
    }
    uint32_t ids[16];
    float xs[16], ys[16];
    int n = 0;
    for (uint32_t i = 0; i < in->touch_count && n < 16; i++) {
        nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(i, &t) == NXN_OK) {
            ids[n] = t.id;
            xs[n] = t.x / tw;
            ys[n] = t.y / th;
            n++;
        }
    }
    for (int i = 0; i < n; i++) { /* down or move */
        int was = 0;
        for (int j = 0; j < vd->touch_count; j++) {
            was |= vd->touch_ids[j] == ids[i];
        }
        if (was) {
            SDL_SendTouchMotion((SDL_TouchID)1, (SDL_FingerID)ids[i], window, xs[i], ys[i], 1.0f);
        } else {
            SDL_SendTouch((SDL_TouchID)1, (SDL_FingerID)ids[i], window, SDL_TRUE, xs[i], ys[i], 1.0f);
        }
    }
    for (int j = 0; j < vd->touch_count; j++) { /* up */
        int still = 0;
        for (int i = 0; i < n; i++) {
            still |= ids[i] == vd->touch_ids[j];
        }
        if (!still) {
            SDL_SendTouch((SDL_TouchID)1, (SDL_FingerID)vd->touch_ids[j], window, SDL_FALSE, 0.f, 0.f, 0.0f);
        }
    }
    for (int i = 0; i < n; i++) {
        vd->touch_ids[i] = ids[i];
    }
    vd->touch_count = n;
}

/* USB keyboard (ordered key events, HID usage = SDL scancode), typed text and the pointer as a mouse. The queue is always
 * drained (a stalled app must not keep old keys), but only a focused window sends them on. */
static void NEXVYN_PollUSB(NEXVYN_VideoData *vd)
{
    SDL_Window *window = vd->window;
    nxn_key_event k = NXN_STRUCT_INIT(nxn_key_event);
    while (nxn_input_key_poll(&k) > 0) {
        if (vd->focused && window && k.usage > 0 && k.usage < SDL_NUM_SCANCODES) {
            SDL_SendKeyboardKey(k.down ? SDL_PRESSED : SDL_RELEASED, (SDL_Scancode)k.usage);
        }
        k.size = sizeof k;
    }
    char text[64];
    int n;
    while ((n = nxn_input_text(text, sizeof(text))) > 0) {
        if (vd->focused && window && SDL_IsTextInputActive()) {
            SDL_SendKeyboardText(text);
        }
    }
    nxn_mouse m = NXN_STRUCT_INIT(nxn_mouse);
    if (nxn_input_mouse(&m) != NXN_OK || !vd->focused || !window) {
        return;
    }
    static const struct {
        uint32_t bit;
        Uint8 button;
    } buttons[3] = {{NXN_MOUSE_LEFT, SDL_BUTTON_LEFT}, {NXN_MOUSE_MIDDLE, SDL_BUTTON_MIDDLE}, {NXN_MOUSE_RIGHT, SDL_BUTTON_RIGHT}};
    if (m.present) {
        if (SDL_GetRelativeMouseMode()) {
            if (m.dx != 0.f || m.dy != 0.f) {
                SDL_SendMouseMotion(window, 0, 1, (int)m.dx, (int)m.dy);
            }
        } else if (!vd->mouse_seen || (int)m.x != vd->mouse_x || (int)m.y != vd->mouse_y) {
            SDL_SendMouseMotion(window, 0, 0, (int)m.x, (int)m.y);
        }
        vd->mouse_seen = 1;
        vd->mouse_x = (int)m.x;
        vd->mouse_y = (int)m.y;
    }
    for (int i = 0; i < 3; i++) { /* a click inside one frame: press, then release */
        if (m.pressed & buttons[i].bit) {
            SDL_SendMouseButton(window, 0, SDL_PRESSED, buttons[i].button);
        }
        if (m.released & buttons[i].bit) {
            SDL_SendMouseButton(window, 0, SDL_RELEASED, buttons[i].button);
        }
    }
    if (m.wheel_x != 0.f || m.wheel_y != 0.f) {
        SDL_SendMouseWheel(window, 0, m.wheel_x, m.wheel_y, SDL_MOUSEWHEEL_NORMAL);
    }
}

static void NEXVYN_PumpEvents(SDL_VideoDevice *_this)
{
    NEXVYN_VideoData *vd = g_video;
    if (!vd) {
        return;
    }
    nxn_event e = NXN_STRUCT_INIT(nxn_event);
    while (nxn_event_poll(&e) > 0) {
        switch (e.type) {
        case NXN_EVENT_RESIZE:
            if (vd->window && vd->gl && vd->gl->follow && e.width && e.height) {
                if (nxn_display_resize(vd->gl->display, e.width, e.height) == NXN_OK) {
                    SDL_SendWindowEvent(vd->window, SDL_WINDOWEVENT_RESIZED, (int)e.width, (int)e.height);
                }
            }
            break;
        case NXN_EVENT_QUIT:
            SDL_SendQuit();
            break;
        case NXN_EVENT_SUSPEND: /* background / console sleep: SDL's app lifecycle events */
            SDL_SendAppEvent(SDL_APP_WILLENTERBACKGROUND);
            SDL_SendAppEvent(SDL_APP_DIDENTERBACKGROUND);
            break;
        case NXN_EVENT_RESUME:
            SDL_SendAppEvent(SDL_APP_WILLENTERFOREGROUND);
            SDL_SendAppEvent(SDL_APP_DIDENTERFOREGROUND);
            break;
        case NXN_EVENT_FOCUS:
            vd->focused = e.focused ? 1 : 0;
            if (vd->window) {
                if (e.focused) {
                    SDL_SetKeyboardFocus(vd->window);
                    SDL_SetMouseFocus(vd->window);
                } else {
                    SDL_SetKeyboardFocus(NULL);
                    SDL_SetMouseFocus(NULL);
                }
            }
            break;
        default:
            break; /* new event types of a later system: ignored, as the ABI rules say */
        }
        e.size = sizeof e;
    }
    const nxn_input_state *in = NEXVYN_PollInput(1);
    if (vd->focused) {
        NEXVYN_PollTouch(vd, in);
    }
    if (vd->usb_input) {
        NEXVYN_PollUSB(vd);
    }
}

/* ------------------------------------------------------------------ init */

static int NEXVYN_SetRelativeMouseMode(SDL_bool enabled)
{
    return 0; /* the pointer stays Nexvyn OS's; relative mode only switches to the movement deltas */
}

static int NEXVYN_VideoInit(SDL_VideoDevice *_this)
{
    NEXVYN_VideoData *vd = (NEXVYN_VideoData *)SDL_calloc(1, sizeof(*vd));
    if (!vd) {
        return SDL_OutOfMemory();
    }
    g_video = vd;
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    vd->usb_input = nxn_caps_get(&caps) == NXN_OK && (caps.features & NXN_CAP_USB_INPUT) != 0;
    if (vd->usb_input) {
        SDL_GetMouse()->SetRelativeMouseMode = NEXVYN_SetRelativeMouseMode;
    }
    SDL_DisplayMode mode;
    SDL_zero(mode);
    mode.w = 1280;
    mode.h = 720;
    mode.refresh_rate = 60;
    mode.format = SDL_PIXELFORMAT_RGBA8888;
    SDL_VideoDisplay display;
    SDL_zero(display);
    display.desktop_mode = mode;
    display.current_mode = mode;
    SDL_AddVideoDisplay(&display, SDL_FALSE);
    return 0;
}

static void NEXVYN_VideoQuit(SDL_VideoDevice *_this)
{
    NEXVYN_VideoData *vd = g_video;
    if (!vd) {
        return;
    }
    if (vd->gl) {
        NEXVYN_GLDeleteContext(_this, (SDL_GLContext)vd->gl);
    }
    if (vd->touch_added) {
        SDL_DelTouch((SDL_TouchID)1);
    }
    g_video = NULL;
    SDL_free(vd);
}

static SDL_VideoDevice *NEXVYN_CreateDevice(void)
{
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    if (nxn_caps_get(&caps) != NXN_OK || !(caps.features & NXN_CAP_WINDOWED)) {
        return NULL; /* this SDL runs inside a Nexvyn OS window only */
    }
    SDL_VideoDevice *device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(SDL_VideoDevice));
    if (!device) {
        SDL_OutOfMemory();
        return NULL;
    }
    device->free = NEXVYN_DeleteDevice;
    device->VideoInit = NEXVYN_VideoInit;
    device->VideoQuit = NEXVYN_VideoQuit;
    device->GetDisplayModes = NEXVYN_GetDisplayModes;
    device->SetDisplayMode = NEXVYN_SetDisplayMode;
    device->CreateSDLWindow = NEXVYN_CreateWindow;
    device->DestroyWindow = NEXVYN_DestroyWindow;
    device->SetWindowTitle = NEXVYN_NoWindowOp;
    device->SetWindowPosition = NEXVYN_NoWindowOp;
    device->SetWindowSize = NEXVYN_NoWindowOp;
    device->ShowWindow = NEXVYN_NoWindowOp;
    device->HideWindow = NEXVYN_NoWindowOp;
    device->RaiseWindow = NEXVYN_NoWindowOp;
    device->MaximizeWindow = NEXVYN_NoWindowOp;
    device->MinimizeWindow = NEXVYN_NoWindowOp;
    device->RestoreWindow = NEXVYN_NoWindowOp;
    device->PumpEvents = NEXVYN_PumpEvents;
    device->GL_LoadLibrary = NEXVYN_GLLoadLibrary;
    device->GL_GetProcAddress = NEXVYN_GLGetProcAddress;
    device->GL_UnloadLibrary = NEXVYN_GLUnloadLibrary;
    device->GL_CreateContext = NEXVYN_GLCreateContext;
    device->GL_MakeCurrent = NEXVYN_GLMakeCurrent;
    device->GL_SetSwapInterval = NEXVYN_GLSetSwapInterval;
    device->GL_GetSwapInterval = NEXVYN_GLGetSwapInterval;
    device->GL_SwapWindow = NEXVYN_GLSwapWindow;
    device->GL_DeleteContext = NEXVYN_GLDeleteContext;
    device->GL_DefaultProfileConfig = NEXVYN_GLDefaultProfileConfig;
    return device;
}

VideoBootStrap NEXVYN_bootstrap = {"nexvyn", "Nexvyn OS window video driver", NEXVYN_CreateDevice};

#endif /* SDL_VIDEO_DRIVER_NEXVYN */
