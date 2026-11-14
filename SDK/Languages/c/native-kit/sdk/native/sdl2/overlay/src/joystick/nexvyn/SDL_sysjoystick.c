/* Nexvyn OS SDL2 driver (windowed native apps): one game controller (player 1 and handheld).
 * Added to SDL2 (zlib license) by the Nexvyn native kit; see sdk/native/sdl2/README.md. Not part of upstream SDL.
 *
 * Reads nxn_input_poll (through the shared sample of the video driver). Button numbers follow the Switch SDL layout of
 * the homebrew ports: 0 A, 1 B, 2 X, 3 Y, 4 L stick, 5 R stick, 6 L, 7 R, 8 ZL, 9 ZR, 10 +, 11 -, 12 left, 13 up,
 * 14 right, 15 down (= the NXN_BTN_* bit numbers); axes 0..3 = left x/y, right x/y (y down, like SDL). The device is
 * named "Switch Controller", which SDL's built-in game controller database already maps. While the window has no
 * focus the sample is empty, so nothing leaks to a background app. */
#include "../../SDL_internal.h"

#if SDL_JOYSTICK_NEXVYN

#include "SDL_events.h"
#include "../SDL_sysjoystick.h"
#include "../SDL_joystick_c.h"
#include <nexvyn/nexvyn_native.h>

#define NEXVYN_BUTTONS 16

extern const nxn_input_state *NEXVYN_PollInput(int force);

static uint64_t g_buttons;
static Sint16 g_axes[4];
static SDL_JoystickID g_instance = -1; /* the one pad's SDL instance id, made at init */

static Sint16 axis16(float v)
{
    if (v > 1.f) {
        v = 1.f;
    }
    if (v < -1.f) {
        v = -1.f;
    }
    return (Sint16)(v * 32767.f);
}

static int NEXVYN_JoystickInit(void)
{
    /* SDL learns about a device only through SDL_PrivateJoystickAdded: without it no SDL_JOYDEVICEADDED /
     * SDL_CONTROLLERDEVICEADDED event ever arrives and the player index stays unset, so programs that wait for the
     * "added" event (or read SDL's player slot) never see the pad although SDL_NumJoysticks() says 1. */
    g_instance = SDL_GetNextJoystickInstanceID();
    SDL_PrivateJoystickAdded(g_instance);
    return 0;
}

static int NEXVYN_JoystickGetCount(void)
{
    return 1;
}

static void NEXVYN_JoystickDetect(void) {}

static const char *NEXVYN_JoystickGetDeviceName(int device_index)
{
    return "Switch Controller";
}

static const char *NEXVYN_JoystickGetDevicePath(int device_index)
{
    return NULL;
}

static int NEXVYN_JoystickGetDevicePlayerIndex(int device_index)
{
    return 0;
}

static void NEXVYN_JoystickSetDevicePlayerIndex(int device_index, int player_index) {}

static SDL_JoystickGUID NEXVYN_JoystickGetDeviceGUID(int device_index)
{
    return SDL_CreateJoystickGUIDForName(NEXVYN_JoystickGetDeviceName(device_index));
}

static SDL_JoystickID NEXVYN_JoystickGetDeviceInstanceID(int device_index)
{
    return g_instance;
}

static int NEXVYN_JoystickOpen(SDL_Joystick *joystick, int device_index)
{
    joystick->nbuttons = NEXVYN_BUTTONS;
    joystick->naxes = 4;
    joystick->nhats = 0;
    joystick->instance_id = g_instance;
    g_buttons = 0;
    SDL_memset(g_axes, 0, sizeof(g_axes));
    return 0;
}

static int NEXVYN_JoystickRumble(SDL_Joystick *joystick, Uint16 low, Uint16 high)
{
    (void)joystick;
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    if (nxn_caps_get(&caps) == NXN_OK && (caps.features & NXN_CAP_RUMBLE)) {
        Uint16 mx = low > high ? low : high;
        float strength = (float)mx / 65535.0f;
        nxn_rumble(strength, mx ? 2000u : 0u);
        return 0;
    }
    return SDL_Unsupported();
}

static int NEXVYN_JoystickRumbleTriggers(SDL_Joystick *joystick, Uint16 left, Uint16 right)
{
    return SDL_Unsupported();
}

static Uint32 NEXVYN_JoystickGetCapabilities(SDL_Joystick *joystick)
{
    return 0;
}

static int NEXVYN_JoystickSetLED(SDL_Joystick *joystick, Uint8 red, Uint8 green, Uint8 blue)
{
    return SDL_Unsupported();
}

static int NEXVYN_JoystickSendEffect(SDL_Joystick *joystick, const void *data, int size)
{
    return SDL_Unsupported();
}

static int NEXVYN_JoystickSetSensorsEnabled(SDL_Joystick *joystick, SDL_bool enabled)
{
    return SDL_Unsupported();
}

static void NEXVYN_JoystickUpdate(SDL_Joystick *joystick)
{
    const nxn_input_state *in = NEXVYN_PollInput(0);
    uint64_t now = in->buttons;
    uint64_t diff = now ^ g_buttons;
    for (int i = 0; diff && i < NEXVYN_BUTTONS; i++) {
        if (diff & (1ull << i)) {
            SDL_PrivateJoystickButton(joystick, (Uint8)i, (now >> i) & 1 ? SDL_PRESSED : SDL_RELEASED);
        }
    }
    g_buttons = now;
    Sint16 a[4] = {axis16(in->lx), axis16(-in->ly), axis16(in->rx), axis16(-in->ry)};
    for (int i = 0; i < 4; i++) {
        if (a[i] != g_axes[i]) {
            SDL_PrivateJoystickAxis(joystick, (Uint8)i, a[i]);
            g_axes[i] = a[i];
        }
    }
}

static void NEXVYN_JoystickClose(SDL_Joystick *joystick) {}

static void NEXVYN_JoystickQuit(void)
{
    g_instance = -1; /* SDL_Quit and SDL_Init again (a program that restarts its subsystems) announce the pad anew */
}

static SDL_bool NEXVYN_JoystickGetGamepadMapping(int device_index, SDL_GamepadMapping *out)
{
    /* the layout of the Switch SDL ports: SDL's A (south) is the console's B button, SDL's B is the console's A */
    *out = (SDL_GamepadMapping){
        .a = {EMappingKind_Button, 1},
        .b = {EMappingKind_Button, 0},
        .x = {EMappingKind_Button, 3},
        .y = {EMappingKind_Button, 2},
        .back = {EMappingKind_Button, 11},
        .guide = {EMappingKind_None, 255},
        .start = {EMappingKind_Button, 10},
        .leftstick = {EMappingKind_Button, 4},
        .rightstick = {EMappingKind_Button, 5},
        .leftshoulder = {EMappingKind_Button, 6},
        .rightshoulder = {EMappingKind_Button, 7},
        .dpup = {EMappingKind_Button, 13},
        .dpdown = {EMappingKind_Button, 15},
        .dpleft = {EMappingKind_Button, 12},
        .dpright = {EMappingKind_Button, 14},
        .misc1 = {EMappingKind_None, 255},
        .paddle1 = {EMappingKind_None, 255},
        .paddle2 = {EMappingKind_None, 255},
        .paddle3 = {EMappingKind_None, 255},
        .paddle4 = {EMappingKind_None, 255},
        .leftx = {EMappingKind_Axis, 0},
        .lefty = {EMappingKind_Axis, 1},
        .rightx = {EMappingKind_Axis, 2},
        .righty = {EMappingKind_Axis, 3},
        .lefttrigger = {EMappingKind_Button, 8},
        .righttrigger = {EMappingKind_Button, 9},
    };
    return SDL_TRUE;
}

SDL_JoystickDriver SDL_NEXVYN_JoystickDriver = {
    NEXVYN_JoystickInit,
    NEXVYN_JoystickGetCount,
    NEXVYN_JoystickDetect,
    NEXVYN_JoystickGetDeviceName,
    NEXVYN_JoystickGetDevicePath,
    NEXVYN_JoystickGetDevicePlayerIndex,
    NEXVYN_JoystickSetDevicePlayerIndex,
    NEXVYN_JoystickGetDeviceGUID,
    NEXVYN_JoystickGetDeviceInstanceID,
    NEXVYN_JoystickOpen,
    NEXVYN_JoystickRumble,
    NEXVYN_JoystickRumbleTriggers,
    NEXVYN_JoystickGetCapabilities,
    NEXVYN_JoystickSetLED,
    NEXVYN_JoystickSendEffect,
    NEXVYN_JoystickSetSensorsEnabled,
    NEXVYN_JoystickUpdate,
    NEXVYN_JoystickClose,
    NEXVYN_JoystickQuit,
    NEXVYN_JoystickGetGamepadMapping,
};

#endif /* SDL_JOYSTICK_NEXVYN */
