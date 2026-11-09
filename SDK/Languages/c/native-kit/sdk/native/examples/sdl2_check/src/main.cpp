// SDL2 check: a small SDL2 program that exercises the kit's SDL2 driver inside a Nexvyn OS window and writes what it saw
// to the app log and to <app data>/sdl2_check_report.txt. Run it by hand (it shows live state as coloured bars) or let a
// test inject input (tools: autorun "dpad a", "finger", "key", "text", "click", "sleep" / "wake") and read the report.
//   green bar = that kind of event arrived, grey = not yet. After 30 s (or SDL_QUIT) about 7 s of present checks follow
//   (rows present-*: GL renderer direct and through a target texture, software renderer, window surface), then it ends.
#include <SDL.h>
#include <nexvyn/nexvyn_native.h>
#include <cmath>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <cstdarg>

namespace {

struct Counters {
    unsigned joyAdded = 0, ctrlAdded = 0, joyButtons = 0, joyAxes = 0, ctrlButtons = 0, fingers = 0, keys = 0, texts = 0, mouseButtons = 0, mouseMoves = 0,
             wheels = 0, resizes = 0, focusIn = 0, focusOut = 0, quits = 0, background = 0, foreground = 0;
    int lastW = 0, lastH = 0;
};
Counters g_c;

// audio callback state (SDL's audio thread)
volatile unsigned g_audioCalls = 0;
volatile unsigned g_audioMaxGapMs = 0;
volatile Uint32 g_audioLast = 0;
double g_phase = 0;
int g_rate = 44100, g_channels = 2;

void audioCb(void*, Uint8* stream, int len) {
    Uint32 now = SDL_GetTicks();
    if (g_audioLast) {
        unsigned gap = now - g_audioLast;
        if (gap > g_audioMaxGapMs) g_audioMaxGapMs = gap;
    }
    g_audioLast = now;
    g_audioCalls = g_audioCalls + 1;
    Sint16* out = (Sint16*)stream;
    int frames = len / (int)(sizeof(Sint16) * g_channels);
    for (int i = 0; i < frames; i++) {
        Sint16 v = (Sint16)(std::sin(g_phase) * 8192.0);  // -12 dBFS: Nexvyn OS's capture checks it for clipping
        g_phase += 2.0 * M_PI * 997.0 / g_rate;
        if (g_phase > 2.0 * M_PI) g_phase -= 2.0 * M_PI;
        for (int c = 0; c < g_channels; c++) *out++ = v;
    }
}

char g_report[8192];
size_t g_reportLen = 0;

void row(const char* name, bool ok, const char* fmt, ...) {
    char detail[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(detail, sizeof detail, fmt, ap);
    va_end(ap);
    nxn_log(NXN_LOG_INFO, "sdl2check %-14s %s %s", name, ok ? "OK  " : "FAIL", detail);
    int n = snprintf(g_report + g_reportLen, sizeof g_report - g_reportLen, "%-14s %s %s\n", name, ok ? "OK  " : "FAIL", detail);
    if (n > 0 && g_reportLen + (size_t)n < sizeof g_report) g_reportLen += (size_t)n;
}

// ---- audio conversion (SDL_BuildAudioCVT / SDL_ConvertAudio), the path SDL_mixer games take for their sound effects:
// a 1 kHz sine at -6 dBFS in every source format, rate and channel count, converted to S16 stereo 44.1 kHz (what
// Chocolate Doom's mixer runs at). Pass: no wrap (a jump of more than 1.5 full scale between neighbours), both channels
// carry the tone, and the error against the ideal sine stays under -30 dB (U8: 8-bit source, -30 dB too). One row per
// source format; the worst case of its rates and channel counts is shown.
double cvtCase(SDL_AudioFormat fmt, int chans, int rate, int* wraps) {
    const int outRate = 44100, inFrames = rate / 4;  // 250 ms
    const double f = 1000.0, amp = 0.5;
    SDL_AudioCVT cvt;
    if (SDL_BuildAudioCVT(&cvt, fmt, (Uint8)chans, rate, AUDIO_S16SYS, 2, outRate) < 0) return 0;
    int bps = SDL_AUDIO_BITSIZE(fmt) / 8;
    cvt.len = inFrames * chans * bps;
    cvt.buf = (Uint8*)calloc(1, (size_t)cvt.len * (size_t)(cvt.len_mult > 0 ? cvt.len_mult : 1));
    if (!cvt.buf) return 0;
    for (int i = 0; i < inFrames; i++) {
        double v = amp * std::sin(2.0 * M_PI * f * i / rate);
        for (int c = 0; c < chans; c++) {
            Uint8* p = cvt.buf + ((size_t)i * chans + c) * bps;
            if (fmt == AUDIO_U8) *p = (Uint8)lrint(128 + v * 127);
            else if (fmt == AUDIO_S8) *(Sint8*)p = (Sint8)lrint(v * 127);
            else if (fmt == AUDIO_S16SYS) { Sint16 s = (Sint16)lrint(v * 32767); memcpy(p, &s, 2); }
            else if (fmt == AUDIO_S32SYS) { Sint32 s = (Sint32)llrint(v * 2147483647.0); memcpy(p, &s, 4); }
            else { float s = (float)v; memcpy(p, &s, 4); }
        }
    }
    double worst = 0;
    *wraps = 0;
    if (cvt.needed == 0 || SDL_ConvertAudio(&cvt) == 0) {
        const Sint16* o = (const Sint16*)cvt.buf;
        int outFrames = (cvt.needed ? cvt.len_cvt : cvt.len) / 4;
        // skip the filter's settling at both ends; fit amplitude and phase of the 1 kHz tone, then measure the rest
        int a = outFrames / 8, b = outFrames - outFrames / 8;
        for (int c = 0; c < 2; c++) {
            double sc = 0, cc = 0, n = 0;
            for (int i = a; i < b; i++) {
                double x = o[i * 2 + c] / 32768.0;
                sc += x * std::sin(2.0 * M_PI * f * i / outRate);
                cc += x * std::cos(2.0 * M_PI * f * i / outRate);
                n++;
            }
            sc *= 2 / n;
            cc *= 2 / n;
            double err = 0, sig = 0;
            for (int i = a; i < b; i++) {
                double x = o[i * 2 + c] / 32768.0;
                double ideal = sc * std::sin(2.0 * M_PI * f * i / outRate) + cc * std::cos(2.0 * M_PI * f * i / outRate);
                err += (x - ideal) * (x - ideal);
                sig += ideal * ideal;
            }
            for (int i = 1; i < outFrames; i++)
                if (std::abs(o[i * 2 + c] - o[i * 2 - 2 + c]) > 49152) (*wraps)++;
            double ratio = sig > 0 ? 10 * std::log10(err / sig + 1e-12) : 0;
            double level = std::sqrt(sc * sc + cc * cc);
            if (level < amp * 0.8 || level > amp * 1.2) ratio = 0;  // the tone is missing or at the wrong level
            if (c == 0 || ratio > worst) worst = ratio;
        }
    }
    free(cvt.buf);
    return worst;
}

void checkAudioConversion() {
    struct F { SDL_AudioFormat fmt; const char* name; } fmts[] = {
        {AUDIO_U8, "u8"}, {AUDIO_S8, "s8"}, {AUDIO_S16SYS, "s16"}, {AUDIO_S32SYS, "s32"}, {AUDIO_F32SYS, "f32"}};
    const int rates[] = {11025, 16000, 22050, 44100, 48000};
    for (const F& fm : fmts) {
        double worst = -200;
        int worstRate = 0, worstCh = 0, wrapsAll = 0;
        for (int rate : rates)
            for (int ch = 1; ch <= 2; ch++) {
                int wraps = 0;
                double r = cvtCase(fm.fmt, ch, rate, &wraps);
                wrapsAll += wraps;
                if (r > worst) {
                    worst = r;
                    worstRate = rate;
                    worstCh = ch;
                }
            }
        char name[24];
        snprintf(name, sizeof name, "audio-cvt-%s", fm.name);
        row(name, worst < -30 && wrapsAll == 0, "to s16 2ch 44100: worst error %.1f dB (%d Hz %d ch), wraps %d", worst, worstRate,
            worstCh, wrapsAll);
    }
    // the clipping case: F32 above full scale saturates (never wraps around)
    SDL_AudioCVT cvt;
    int wraps = 0, sat = 0;
    if (SDL_BuildAudioCVT(&cvt, AUDIO_F32SYS, 1, 44100, AUDIO_S16SYS, 2, 44100) >= 0) {
        float in[64];
        for (int i = 0; i < 64; i++) in[i] = (i & 1) ? 1.7f : -1.7f;
        cvt.len = sizeof in;
        cvt.buf = (Uint8*)calloc(1, (size_t)cvt.len * (size_t)cvt.len_mult);
        if (cvt.buf) {
            memcpy(cvt.buf, in, sizeof in);
            SDL_ConvertAudio(&cvt);
            const Sint16* o = (const Sint16*)cvt.buf;
            for (int i = 0; i < 64; i++) {
                Sint16 want = (i & 1) ? 32767 : -32768;
                if (std::abs(o[i * 2] - want) <= 1 && std::abs(o[i * 2 + 1] - want) <= 1) sat++;
                if ((i & 1) ? o[i * 2] < 0 : o[i * 2] > 0) wraps++;
            }
            free(cvt.buf);
        }
    }
    row("audio-clip", sat == 64 && wraps == 0, "f32 +-1.7 to s16: %d of 64 saturated, %d wrapped", sat, wraps);
}

// ---- present paths: what an SDL2 game draws must reach the Nexvyn OS window. Each phase draws a frame-numbered colour
// (R, G fixed per phase, B = frame & 255) at the centre and reads the centre pixel back on the app side; Nexvyn OS's
// developer setting native.frameProbe logs the centre of the frame it shows, so the two can be compared in the logs.
struct Phase {
    const char* name;
    Uint8 r, g;
};

// events during the present phases (after the event loop): a quit still counts
void phaseEvents() {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_JOYDEVICEADDED) g_c.joyAdded++;
        else if (e.type == SDL_CONTROLLERDEVICEADDED) g_c.ctrlAdded++;
        else if (e.type == SDL_QUIT) g_c.quits++;
    }
}

bool pixelIs(const Uint8* px, Uint8 r, Uint8 g, Uint8 b) {
    return std::abs(px[0] - r) <= 2 && std::abs(px[1] - g) <= 2 && std::abs(px[2] - b) <= 2;
}

// renderer phases: "direct" draws to the window, "target" draws into a target texture first (Chocolate Doom's path)
void presentRenderer(SDL_Renderer* ren, const Phase& ph, bool target, Uint32 ms) {
    int w = 0, h = 0;
    SDL_GetRendererOutputSize(ren, &w, &h);
    SDL_Texture* tt = nullptr;
    if (target) {
        tt = SDL_CreateTexture(ren, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, 320, 200);
        if (!tt) {
            row(ph.name, false, "SDL_CreateTexture(TARGET): %s", SDL_GetError());
            return;
        }
    }
    unsigned frames = 0, good = 0, logged = 0;
    Uint8 last[4] = {};
    Uint32 t0 = SDL_GetTicks();
    while (SDL_GetTicks() - t0 < ms) {
        phaseEvents();
        Uint8 b = (Uint8)(frames & 255);
        SDL_SetRenderTarget(ren, tt);
        SDL_SetRenderDrawColor(ren, ph.r, ph.g, b, 255);
        SDL_RenderClear(ren);
        double a = frames * 0.08;  // a white square going round the centre: consecutive frames differ
        SDL_Rect sq = {(int)((target ? 160 : w / 2) + std::cos(a) * (target ? 60 : w / 4)) - 10,
                       (int)((target ? 100 : h / 2) + std::sin(a) * (target ? 40 : h / 4)) - 10, 20, 20};
        SDL_SetRenderDrawColor(ren, 255, 255, 255, 255);
        SDL_RenderFillRect(ren, &sq);
        if (target) {
            SDL_SetRenderTarget(ren, nullptr);
            SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
            SDL_RenderClear(ren);
            SDL_Rect dst = {w / 8, h / 8, w * 3 / 4, h * 3 / 4};
            SDL_RenderCopy(ren, tt, nullptr, &dst);
        }
        SDL_Rect c = {w / 2, h / 2, 1, 1};
        Uint8 px[4] = {};
        SDL_RenderReadPixels(ren, &c, SDL_PIXELFORMAT_ABGR8888, px, 4);  // bytes R, G, B, A
        good += pixelIs(px, ph.r, ph.g, b);
        memcpy(last, px, 4);
        SDL_RenderPresent(ren);
        frames++;
        if ((SDL_GetTicks() - t0) / 1000 >= logged) {
            nxn_log(NXN_LOG_INFO, "sdl2check probe %s frame %u centre %u,%u,%u (want %u,%u,%u)", ph.name, frames, px[0], px[1], px[2], ph.r,
                    ph.g, b);
            logged++;
        }
    }
    if (tt) SDL_DestroyTexture(tt);
    row(ph.name, frames >= 10 && good * 10 >= frames * 9, "%u frames, centre right in %u, last %u,%u,%u", frames, good, last[0], last[1],
        last[2]);
}

// the window surface without a renderer (SDL_GetWindowSurface + SDL_UpdateWindowSurface: SDL's own window texture)
void presentSurface(SDL_Window* win, const Phase& ph, Uint32 ms) {
    SDL_Surface* s = SDL_GetWindowSurface(win);
    if (!s) {
        row(ph.name, false, "SDL_GetWindowSurface: %s", SDL_GetError());
        return;
    }
    unsigned frames = 0, good = 0, logged = 0, updated = 0;
    Uint8 last[4] = {};
    Uint32 t0 = SDL_GetTicks();
    while (SDL_GetTicks() - t0 < ms) {
        phaseEvents();
        s = SDL_GetWindowSurface(win);  // a resize makes a new one
        if (!s) break;
        Uint8 b = (Uint8)(frames & 255);
        SDL_FillRect(s, nullptr, SDL_MapRGB(s->format, ph.r, ph.g, b));
        double a = frames * 0.08;
        SDL_Rect sq = {(int)(s->w / 2 + std::cos(a) * s->w / 4) - 10, (int)(s->h / 2 + std::sin(a) * s->h / 4) - 10, 20, 20};
        SDL_FillRect(s, &sq, SDL_MapRGB(s->format, 255, 255, 255));
        Uint32 v = 0;
        SDL_LockSurface(s);
        memcpy(&v, (Uint8*)s->pixels + (s->h / 2) * s->pitch + (s->w / 2) * s->format->BytesPerPixel, 4);
        SDL_UnlockSurface(s);
        Uint8 px[4] = {};
        SDL_GetRGBA(v, s->format, &px[0], &px[1], &px[2], &px[3]);
        good += pixelIs(px, ph.r, ph.g, b);
        memcpy(last, px, 4);
        updated += SDL_UpdateWindowSurface(win) == 0;
        frames++;
        SDL_Delay(15);
        if ((SDL_GetTicks() - t0) / 1000 >= logged) {
            nxn_log(NXN_LOG_INFO, "sdl2check probe %s frame %u centre %u,%u,%u (want %u,%u,%u)", ph.name, frames, px[0], px[1], px[2], ph.r,
                    ph.g, b);
            logged++;
        }
    }
    row(ph.name, frames >= 10 && good * 10 >= frames * 9 && updated == frames, "%u frames, %u updates, centre right in %u, %dx%d, last %u,%u,%u",
        frames, updated, good, s ? s->w : 0, s ? s->h : 0, last[0], last[1], last[2]);
}

}  // namespace

int main(int, char**) {
    nxn_log(NXN_LOG_INFO, "sdl2check start");
    bool inited = SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER | SDL_INIT_TIMER) == 0;
    row("init", inited, "video=%s audio=%s %s", SDL_GetCurrentVideoDriver() ? SDL_GetCurrentVideoDriver() : "-",
        SDL_GetCurrentAudioDriver() ? SDL_GetCurrentAudioDriver() : "-", inited ? "" : SDL_GetError());
    if (!inited) {
        nxn_fs_write(NXN_DIR_DATA, "sdl2_check_report.txt", g_report, g_reportLen);
        return 1;
    }

    SDL_Window* win = SDL_CreateWindow("SDL2 Check", 0, 0, 1280, 720, SDL_WINDOW_FULLSCREEN);
    SDL_Renderer* ren = win ? SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) : nullptr;
    int ww = 0, wh = 0;
    if (win) SDL_GetWindowSize(win, &ww, &wh);
    SDL_RendererInfo info;
    memset(&info, 0, sizeof info);
    if (ren) SDL_GetRendererInfo(ren, &info);
    row("window", win && ren, "%dx%d renderer %s %s", ww, wh, info.name ? info.name : "-", ren ? "" : SDL_GetError());
    if (!ren) {
        nxn_fs_write(NXN_DIR_DATA, "sdl2_check_report.txt", g_report, g_reportLen);
        return 1;
    }

    // audio: a 997 Hz tone at -12 dBFS in callback mode at 44.1 kHz (Nexvyn OS converts it to 48 kHz); the callback gap
    // shows underruns
    SDL_AudioSpec want, have;
    SDL_zero(want);
    want.freq = 44100;
    want.format = AUDIO_S16SYS;
    want.channels = 2;
    want.samples = 1024;
    want.callback = audioCb;
    SDL_AudioDeviceID dev = SDL_OpenAudioDevice(nullptr, 0, &want, &have, 0);
    if (dev) {
        g_rate = have.freq;
        g_channels = have.channels;
        SDL_PauseAudioDevice(dev, 0);
    }
    row("audio-open", dev != 0, "%d Hz %d ch %d samples %s", dev ? have.freq : 0, dev ? have.channels : 0, dev ? have.samples : 0,
        dev ? "" : SDL_GetError());
    checkAudioConversion();

    // joystick and game controller
    int njoy = SDL_NumJoysticks();
    SDL_Joystick* js = njoy > 0 ? SDL_JoystickOpen(0) : nullptr;
    SDL_GameController* gc = njoy > 0 && SDL_IsGameController(0) ? SDL_GameControllerOpen(0) : nullptr;
    row("joystick", js != nullptr, "%d device(s), '%s', %d buttons %d axes", njoy, js ? SDL_JoystickName(js) : "-",
        js ? SDL_JoystickNumButtons(js) : 0, js ? SDL_JoystickNumAxes(js) : 0);
    row("gamecontroller", gc != nullptr, "%s", gc ? SDL_GameControllerName(gc) : "no mapping");
    {   // what a program that picks its pad by GUID / instance / player slot sees (Chocolate Doom: joystick_guid)
        char guid[40] = "-";
        if (njoy > 0) SDL_JoystickGetGUIDString(SDL_JoystickGetDeviceGUID(0), guid, sizeof guid);
        SDL_JoystickID inst = njoy > 0 ? SDL_JoystickGetDeviceInstanceID(0) : -1;
        row("joy-identity", js && SDL_JoystickGetAttached(js) && SDL_JoystickInstanceID(js) == inst && inst >= 0,
            "guid %s instance %d (open %d) player %d hats %d type %d", guid, (int)inst, js ? (int)SDL_JoystickInstanceID(js) : -1,
            js ? SDL_JoystickGetPlayerIndex(js) : -1, js ? SDL_JoystickNumHats(js) : 0,
            njoy > 0 ? (int)SDL_GameControllerTypeForIndex(0) : -1);
        char* map = gc ? SDL_GameControllerMapping(gc) : nullptr;
        row("joy-mapping", map && strstr(map, "a:b1") && strstr(map, "leftx:a0"), "%.60s", map ? map : "none");
        if (map) SDL_free(map);
    }

    // stdout / stderr of a windowed app land in the app's log (lines "O" and "E", Native 1.1 host)
    printf("sdl2check stdout line\n");
    fprintf(stderr, "sdl2check stderr line\n");

    SDL_StartTextInput();
    Uint32 t0 = SDL_GetTicks(), lastFps = t0;
    unsigned frames = 0, frameCheck = 0;
    bool run = true, fpsReported = false;
    float x = 200, y = 200;
    long long downIds[16] = {0};  // fingers now down, by SDL finger id (multi-touch: each finger has its own id)
    int down = 0, maxDown = 0;
    while (run && SDL_GetTicks() - t0 < 30000) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            switch (e.type) {
                case SDL_QUIT: g_c.quits++; run = false; break;
                case SDL_JOYDEVICEADDED: g_c.joyAdded++; nxn_log(NXN_LOG_INFO, "sdl2check joy device added %d", e.jdevice.which); break;
                case SDL_CONTROLLERDEVICEADDED: g_c.ctrlAdded++; break;
                case SDL_JOYBUTTONDOWN: g_c.joyButtons++; nxn_log(NXN_LOG_INFO, "sdl2check joy button %d", e.jbutton.button); break;
                case SDL_JOYAXISMOTION: g_c.joyAxes++; break;
                case SDL_CONTROLLERBUTTONDOWN: g_c.ctrlButtons++; break;
                case SDL_FINGERDOWN:
                    g_c.fingers++;
                    nxn_log(NXN_LOG_INFO, "sdl2check finger id %lld at %.2f %.2f", (long long)e.tfinger.fingerId, e.tfinger.x, e.tfinger.y);
                    if (down < 16) downIds[down++] = (long long)e.tfinger.fingerId;
                    if (down > maxDown) maxDown = down;
                    break;
                case SDL_FINGERUP:
                    for (int k = 0; k < down; k++)
                        if (downIds[k] == (long long)e.tfinger.fingerId) { downIds[k] = downIds[--down]; break; }
                    break;
                case SDL_KEYDOWN: g_c.keys++; nxn_log(NXN_LOG_INFO, "sdl2check key scancode %d mod %x", e.key.keysym.scancode, e.key.keysym.mod); break;
                case SDL_TEXTINPUT: g_c.texts++; nxn_log(NXN_LOG_INFO, "sdl2check text '%s'", e.text.text); break;
                case SDL_MOUSEBUTTONDOWN: g_c.mouseButtons++; nxn_log(NXN_LOG_INFO, "sdl2check mouse button %d at %d,%d", e.button.button, e.button.x, e.button.y); break;
                case SDL_MOUSEMOTION: g_c.mouseMoves++; break;
                case SDL_MOUSEWHEEL: g_c.wheels++; nxn_log(NXN_LOG_INFO, "sdl2check wheel %.2f %.2f", (double)e.wheel.preciseX, (double)e.wheel.preciseY); break;
                case SDL_APP_WILLENTERBACKGROUND: g_c.background++; nxn_log(NXN_LOG_INFO, "sdl2check will enter background"); break;
                case SDL_APP_DIDENTERFOREGROUND: g_c.foreground++; nxn_log(NXN_LOG_INFO, "sdl2check did enter foreground"); break;
                case SDL_WINDOWEVENT:
                    if (e.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
                        g_c.resizes++;
                        g_c.lastW = e.window.data1;
                        g_c.lastH = e.window.data2;
                        nxn_log(NXN_LOG_INFO, "sdl2check resized %dx%d", e.window.data1, e.window.data2);
                    } else if (e.window.event == SDL_WINDOWEVENT_FOCUS_GAINED) g_c.focusIn++;
                    else if (e.window.event == SDL_WINDOWEVENT_FOCUS_LOST) g_c.focusOut++;
                    break;
                default: break;
            }
        }
        if (js) {
            x += SDL_JoystickGetAxis(js, 0) / 32768.0f * 6.0f;
            y += SDL_JoystickGetAxis(js, 1) / 32768.0f * 6.0f;
        }
        int w = 0, h = 0;
        SDL_GetRendererOutputSize(ren, &w, &h);
        SDL_SetRenderDrawColor(ren, 18, 22, 36, 255);
        SDL_RenderClear(ren);
        // one bar per kind of event
        const unsigned counts[] = {g_c.joyButtons, g_c.joyAxes, g_c.ctrlButtons, g_c.fingers, g_c.keys, g_c.texts,
                                   g_c.mouseButtons, g_c.mouseMoves, g_c.wheels, g_c.resizes, g_c.focusIn};
        for (int i = 0; i < 11; i++) {
            SDL_Rect r = {16 + i * 40, 16, 32, 32};
            if (counts[i]) SDL_SetRenderDrawColor(ren, 60, 200, 110, 255);
            else SDL_SetRenderDrawColor(ren, 70, 74, 88, 255);
            SDL_RenderFillRect(ren, &r);
        }
        SDL_SetRenderDrawColor(ren, 240, 190, 60, 255);
        SDL_Rect r = {(int)x - 24, (int)y - 24, 48, 48};
        SDL_RenderFillRect(ren, &r);
        SDL_RenderPresent(ren);
        frames++;
        Uint32 now = SDL_GetTicks();
        if (!fpsReported && now - lastFps >= 3000) {
            frameCheck = frames;
            row("frames", frameCheck >= 30, "%u frames in 3 s (%.1f fps), output %dx%d", frames, frames / 3.0, w, h);
            fpsReported = true;
        }
    }

    unsigned calls = g_audioCalls, maxGap = g_audioMaxGapMs;
    Uint32 secs = (SDL_GetTicks() - t0) / 1000;
    row("audio-run", dev && calls >= 20, "%u callbacks in %u s, longest gap %u ms (buffer = %d ms)", calls, (unsigned)secs, maxGap,
        have.freq ? have.samples * 1000 / have.freq : 0);
    // the device-added events come once, at SDL_Init; the button rows need pad input from a test (autorun "dpad a")
    row("joy-added", g_c.joyAdded == 1 && g_c.ctrlAdded == 1, "joydevice %u controllerdevice %u", g_c.joyAdded, g_c.ctrlAdded);
    row("joy-input", g_c.joyButtons > 0 && g_c.ctrlButtons > 0, "joybtn %u ctrlbtn %u (no pad input injected if 0)", g_c.joyButtons,
        g_c.ctrlButtons);
    row("events", true, "joybtn %u axis %u ctrlbtn %u finger %u key %u text %u mousebtn %u move %u wheel %u resize %u(%dx%d) focus +%u/-%u bg %u fg %u quit %u",
        g_c.joyButtons, g_c.joyAxes, g_c.ctrlButtons, g_c.fingers, g_c.keys, g_c.texts, g_c.mouseButtons, g_c.mouseMoves,
        g_c.wheels, g_c.resizes, g_c.lastW, g_c.lastH, g_c.focusIn, g_c.focusOut, g_c.background, g_c.foreground, g_c.quits);

    row("multitouch", true, "most fingers down at once: %d (needs a two-finger test, autorun \"finger\"; 0 or 1 = none injected)", maxDown);
    SDL_StopTextInput();
    if (dev) SDL_CloseAudioDevice(dev);
    if (gc) SDL_GameControllerClose(gc);
    if (js) SDL_JoystickClose(js);
    // present paths after the event loop (their event pumping must not eat the events the rows above count)
    presentRenderer(ren, Phase{"present-direct", 200, 40}, false, 2000);
    presentRenderer(ren, Phase{"present-target", 40, 200}, true, 2000);
    SDL_DestroyRenderer(ren);
    // the software renderer and the bare window surface (SDL's window texture), after the GL renderer is gone
    if (SDL_Renderer* sw = SDL_CreateRenderer(win, -1, SDL_RENDERER_SOFTWARE)) {
        presentRenderer(sw, Phase{"present-soft", 200, 200}, false, 1500);
        SDL_DestroyRenderer(sw);
    } else {
        row("present-soft", false, "SDL_CreateRenderer(SOFTWARE): %s", SDL_GetError());
    }
    presentSurface(win, Phase{"present-surface", 90, 30}, 1500);
    SDL_DestroyWindow(win);
    SDL_Quit();
    nxn_fs_write(NXN_DIR_DATA, "sdl2_check_report.txt", g_report, g_reportLen);
    nxn_log(NXN_LOG_INFO, "sdl2check-done");
    return 0;
}
