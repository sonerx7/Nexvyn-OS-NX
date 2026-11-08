/* Stand-in for an upstream program: opens a window, clears it with a colour that changes, ends on SDL_QUIT. */
#include <SDL.h>

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_Window* win = SDL_CreateWindow("@TITLE@", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 960, 600, 0);
    SDL_Renderer* ren = win ? SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) : NULL;
    if (!ren) {
        SDL_Quit();
        return 1;
    }
    int running = 1;
    Uint32 t0 = SDL_GetTicks();
    while (running) {
        SDL_Event e;
        while (SDL_PollEvent(&e))
            if (e.type == SDL_QUIT) running = 0;
        Uint8 v = (Uint8)(60 + (SDL_GetTicks() - t0) / 20 % 120);
        SDL_SetRenderDrawColor(ren, 20, v / 2, v, 255);
        SDL_RenderClear(ren);
        SDL_RenderPresent(ren);
    }
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
