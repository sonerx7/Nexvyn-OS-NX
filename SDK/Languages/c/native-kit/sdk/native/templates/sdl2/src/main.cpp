// SDL2 game loop template: window, input, per-frame update, render. Runs in a Nexvyn OS window or full screen
// (`nxv-native build`); the same source also builds as a plain homebrew .nro (`nxv-native build --exclusive`).
#include <SDL.h>
#include <cstdio>

#ifdef NEXVYN_WINDOWED
// inside Nexvyn OS the close button and the system's quit arrive as SDL_QUIT: no applet loop to run
#define KEEP_RUNNING() true
#else
#include <switch.h>
#define KEEP_RUNNING() appletMainLoop()
#endif

#ifdef NEXVYN_ABI
#include <nexvyn/nexvyn_native.h>  // Nexvyn native ABI (notifications, screenshots, language, return to Nexvyn)
#endif

int main(int, char**) {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK | SDL_INIT_AUDIO) != 0) return 1;
    SDL_Window* win = SDL_CreateWindow("@TITLE@", 0, 0, 1280, 720, SDL_WINDOW_FULLSCREEN);
    SDL_Renderer* ren = win ? SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) : nullptr;
    if (!ren) { SDL_Quit(); return 1; }
    SDL_Joystick* js = nullptr;
    for (int i = 0; i < SDL_NumJoysticks() && !js; i++) js = SDL_JoystickOpen(i);

    float x = 640, y = 360;
    bool run = true;
    Uint32 last = SDL_GetTicks();
    while (run && KEEP_RUNNING()) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) run = false;
            // joystick button 10 is Plus in the Switch controller mapping
            if (e.type == SDL_JOYBUTTONDOWN && e.jbutton.button == 10) run = false;
        }
        Uint32 now = SDL_GetTicks();
        float dt = (now - last) / 1000.0f;
        last = now;

        if (js) {
            x += SDL_JoystickGetAxis(js, 0) / 32768.0f * 400.0f * dt;
            y += SDL_JoystickGetAxis(js, 1) / 32768.0f * 400.0f * dt;
        }

        SDL_SetRenderDrawColor(ren, 20, 24, 40, 255);
        SDL_RenderClear(ren);
        SDL_SetRenderDrawColor(ren, 240, 190, 60, 255);
        SDL_Rect r = {(int)x - 32, (int)y - 32, 64, 64};
        SDL_RenderFillRect(ren, &r);
        SDL_RenderPresent(ren);
    }
    if (js) SDL_JoystickClose(js);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
