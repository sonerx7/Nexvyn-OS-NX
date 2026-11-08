/* Nexvyn Native SDK library - one audio output stream over SDL2 audio (nxn_audio.h). */
#include "nxn_internal.h"
#include <SDL2/SDL.h>
#include <stdlib.h>
#include <string.h>

struct nxn_audio {
    SDL_AudioDeviceID dev;
    nxn_audio_callback cb;
    void* user;
};

static void SDLCALL pull(void* user, Uint8* stream, int len) {
    nxn_audio* a = (nxn_audio*)user;
    a->cb(a->user, stream, (uint32_t)len);
}

nxn_result nxn_audio_open(const nxn_audio_params* params, nxn_audio** out) {
    if (!out) return NXN_ERR_INVALID;
    *out = NULL;
    nxn_audio_params p;
    memset(&p, 0, sizeof p);
    if (params) {
        if (params->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
        memcpy(&p, params, params->size < sizeof p ? params->size : sizeof p);
    }
    if (p.format > NXN_AUDIO_F32) return NXN_ERR_UNSUPPORTED;
    if (!SDL_WasInit(SDL_INIT_AUDIO) && SDL_InitSubSystem(SDL_INIT_AUDIO) != 0) {
        nxn__set_error("SDL audio: %s", SDL_GetError());
        return NXN_ERR_SYSTEM;
    }
    nxn_audio* a = (nxn_audio*)calloc(1, sizeof *a);
    if (!a) return NXN_ERR_NO_MEMORY;
    a->cb = p.callback;
    a->user = p.user;
    SDL_AudioSpec want, have;
    SDL_zero(want);
    want.freq = p.rate ? (int)p.rate : 48000;
    want.channels = (Uint8)(p.channels ? p.channels : 2);
    want.format = p.format == NXN_AUDIO_F32 ? AUDIO_F32SYS : AUDIO_S16SYS;
    want.samples = (Uint16)(p.frames ? p.frames : 1024);
    want.callback = p.callback ? pull : NULL;
    want.userdata = a;
    a->dev = SDL_OpenAudioDevice(NULL, 0, &want, &have, 0);  /* no changes allowed: SDL converts for us */
    if (!a->dev) {
        nxn__set_error("SDL_OpenAudioDevice: %s", SDL_GetError());
        free(a);
        return NXN_ERR_SYSTEM;
    }
    *out = a;
    return NXN_OK;
}

void nxn_audio_close(nxn_audio* a) {
    if (!a) return;
    SDL_CloseAudioDevice(a->dev);
    free(a);
}

nxn_result nxn_audio_pause(nxn_audio* a, int paused) {
    if (!a) return NXN_ERR_INVALID;
    SDL_PauseAudioDevice(a->dev, paused ? 1 : 0);
    return NXN_OK;
}

nxn_result nxn_audio_queue(nxn_audio* a, const void* data, uint32_t bytes) {
    if (!a || (!data && bytes)) return NXN_ERR_INVALID;
    if (a->cb) return NXN_ERR_INVALID; /* callback stream */
    if (SDL_QueueAudio(a->dev, data, bytes) != 0) {
        nxn__set_error("SDL_QueueAudio: %s", SDL_GetError());
        return NXN_ERR_SYSTEM;
    }
    return NXN_OK;
}

uint32_t nxn_audio_queued_bytes(nxn_audio* a) { return a ? SDL_GetQueuedAudioSize(a->dev) : 0; }

nxn_result nxn_audio_clear(nxn_audio* a) {
    if (!a) return NXN_ERR_INVALID;
    if (a->cb) return NXN_ERR_INVALID; /* callback stream: nothing is queued */
    SDL_ClearQueuedAudio(a->dev);
    return NXN_OK;
}
