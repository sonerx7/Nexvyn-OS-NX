/* Nexvyn Native SDK library - system event queue (nxn_event.h). */
#include "nxn_internal.h"
#include <string.h>

#define NXN__EVENTS 8

static nxn_event g_q[NXN__EVENTS];
static unsigned g_count;
static Mutex g_lock; /* zero-initialised = unlocked; the hook runs on whichever thread pumps applet messages */
static AppletHookCookie g_cookie;
static int g_hooked;

static void push(const nxn_event* e) {
    mutexLock(&g_lock);
    if (e->type == NXN_EVENT_RESIZE && g_count && g_q[g_count - 1].type == NXN_EVENT_RESIZE) {
        g_q[g_count - 1] = *e; /* the newest size is the only one that matters */
    } else {
        if (g_count == NXN__EVENTS) {
            memmove(g_q, g_q + 1, sizeof g_q[0] * (NXN__EVENTS - 1));
            g_count--;
        }
        g_q[g_count++] = *e;
    }
    mutexUnlock(&g_lock);
}

void nxn__output_size(uint32_t* w, uint32_t* h, uint32_t* docked) {
    int d = appletGetOperationMode() == AppletOperationMode_Console;
    if (w) *w = d ? 1920 : 1280;
    if (h) *h = d ? 1080 : 720;
    if (docked) *docked = (uint32_t)d;
}

static void on_applet(AppletHookType type, void* param) {
    (void)param;
    if (type != AppletHookType_OnOperationMode) return;
    nxn_event e;
    memset(&e, 0, sizeof e);
    e.size = sizeof e;
    e.type = NXN_EVENT_RESIZE;
    e.time_ns = nxn_time_ns();
    nxn__output_size(&e.width, &e.height, &e.docked);
    push(&e);
    nxn_log(NXN_LOG_INFO, "event: %s, output %ux%u", e.docked ? "docked" : "handheld", e.width, e.height);
}

void nxn__events_start(void) {
    if (g_hooked) return;
    appletHook(&g_cookie, on_applet, NULL);
    g_hooked = 1;
}

void nxn__events_stop(void) {
    if (!g_hooked) return;
    appletUnhook(&g_cookie);
    g_hooked = 0;
    mutexLock(&g_lock);
    g_count = 0;
    mutexUnlock(&g_lock);
}

int nxn_event_poll(nxn_event* out) {
    if (nxc_signal_poll) nxc_signal_poll(); /* emulated signals are delivered once per frame */
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    if (!g_hooked) return NXN_ERR_NOT_READY;
    nxn_event e;
    mutexLock(&g_lock);
    if (!g_count) {
        mutexUnlock(&g_lock);
        return 0;
    }
    e = g_q[0];
    g_count--;
    memmove(g_q, g_q + 1, sizeof g_q[0] * g_count);
    mutexUnlock(&g_lock);
    e.size = out->size;
    size_t n = out->size < sizeof e ? out->size : sizeof e;
    memcpy(out, &e, n);
    return 1;
}
