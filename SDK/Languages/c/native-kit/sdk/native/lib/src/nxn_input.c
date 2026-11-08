/* Nexvyn Native SDK library - controller, touch and keyboard (nxn_input.h). */
#include "nxn_internal.h"
#include <string.h>

static int g_ready;
static PadState g_pad;
static HidTouchScreenState g_touch;
static uint64_t g_prev;
static uint32_t g_prev_actions;

static void ready(void) {
    if (g_ready) return;
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    padInitializeDefault(&g_pad);
    hidInitializeTouchScreen();
    hidInitializeKeyboard();
    g_ready = 1;
}

static float axis(s32 v) {
    float f = (float)v / 32767.f;
    return f < -1.f ? -1.f : (f > 1.f ? 1.f : f);
}

nxn_result nxn_input_poll(nxn_input_state* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    ready();
    padUpdate(&g_pad);
    nxn_input_state s;
    memset(&s, 0, sizeof s);
    s.size = out->size;
    s.buttons = padGetButtons(&g_pad) & 0xFFFFull;  /* the 16 buttons Nexvyn OS maps (stick directions excluded) */
    s.pressed = s.buttons & ~g_prev;
    s.released = g_prev & ~s.buttons;
    g_prev = s.buttons;
    uint64_t confirm = g_nxn.h.confirm ? g_nxn.h.confirm : NXN_BTN_A;
    uint64_t cancel = g_nxn.h.cancel ? g_nxn.h.cancel : NXN_BTN_B;
    if (s.buttons & confirm) s.actions |= NXN_ACT_CONFIRM;
    if (s.buttons & cancel) s.actions |= NXN_ACT_CANCEL;
    s.actions_pressed = s.actions & ~g_prev_actions;
    g_prev_actions = s.actions;
    HidAnalogStickState l = padGetStickPos(&g_pad, 0), r = padGetStickPos(&g_pad, 1);
    s.lx = axis(l.x);
    s.ly = axis(l.y);
    s.rx = axis(r.x);
    s.ry = axis(r.y);
    memset(&g_touch, 0, sizeof g_touch);
    if (hidGetTouchScreenStates(&g_touch, 1)) s.touch_count = (uint32_t)g_touch.count;
    size_t n = out->size < sizeof s ? out->size : sizeof s;
    memcpy(out, &s, n);
    return NXN_OK;
}

nxn_result nxn_input_touch(uint32_t index, nxn_touch* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    if (index >= (uint32_t)g_touch.count || index >= 16) return NXN_ERR_NOT_FOUND;
    nxn_touch t;
    memset(&t, 0, sizeof t);
    t.size = out->size;
    t.id = g_touch.touches[index].finger_id;
    t.x = (float)g_touch.touches[index].x;
    t.y = (float)g_touch.touches[index].y;
    size_t n = out->size < sizeof t ? out->size : sizeof t;
    memcpy(out, &t, n);
    return NXN_OK;
}

/* Native 1.1 USB input is a windowed-mode feature (NXN_CAP_USB_INPUT is not set here): clean "unsupported" answers. */
nxn_result nxn_input_mouse(nxn_mouse* out) {
    (void)out;
    return NXN_ERR_UNSUPPORTED;
}

int nxn_input_key_poll(nxn_key_event* out) {
    (void)out;
    return 0;
}

int nxn_input_text(char* out, size_t cap) {
    if (out && cap) out[0] = 0;
    return 0;
}

int nxn_input_key_held(uint32_t hid_usage) {
    ready();
    if (hid_usage >= 256) return 0;
    HidKeyboardState ks;
    if (!hidGetKeyboardStates(&ks, 1)) return 0;
    return hidKeyboardStateGetKey(&ks, (HidKeyboardKey)hid_usage) ? 1 : 0;
}
