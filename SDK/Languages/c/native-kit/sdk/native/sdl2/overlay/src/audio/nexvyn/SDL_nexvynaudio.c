/* Nexvyn OS SDL2 driver (windowed native apps): audio output through the app's nxn audio stream.
 * Added to SDL2 (zlib license) by the Nexvyn native kit; see sdk/native/sdl2/README.md. Not part of upstream SDL.
 *
 * Push mode: SDL's audio thread (an app thread) fills one buffer, nxn_audio_queue copies it into the app's stream in
 * Nexvyn OS's mixer. WaitDevice lets the thread run only while the audio that waits in the ring is below a budget:
 * at least two SDL buffers (SDL_AudioSpec.samples) and at least NEXVYN_AUDIO_LATENCY_MS (hint, default 100 ms). The
 * budget used to be two buffers (about 42 ms for 1024 samples at 44.1 kHz): a game whose audio thread was late by more
 * than that (slow frames, the GPU lock held by the OS) crackled. A deeper queue rides those gaps out and costs latency
 * only. The thread takes no shared lock while it waits, and never calls into SDL's video or GL. It sleeps about as
 * long as the mixer needs to play the queue down to the budget (1-20 ms) instead of waking every millisecond (hint
 * NEXVYN_AUDIO_POLL=1: the old 1 ms polling).
 * Every 5 s the thread logs how many buffers found the queue empty (an underrun) and the average depth, when there was
 * any audio, so a crackle in a log has a number next to it (nxn_log line "sdl audio"). */
#include "../../SDL_internal.h"

#if SDL_AUDIO_DRIVER_NEXVYN

#include "SDL_audio.h"
#include "SDL_timer.h"
#include "SDL_hints.h"
#include "../SDL_audio_c.h"
#include "../SDL_sysaudio.h"
#include "SDL_nexvynaudio.h"

static int NEXVYNAUDIO_OpenDevice(SDL_AudioDevice *_this, const char *devname)
{
    SDL_AudioFormat fmt = _this->spec.format;
    if (_this->iscapture) {
        return SDL_SetError("audio capture is not available inside a Nexvyn OS window");
    }
    /* the stream takes S16 or F32; SDL converts everything else for us */
    if (SDL_AUDIO_ISFLOAT(fmt) && SDL_AUDIO_BITSIZE(fmt) == 32) {
        _this->spec.format = AUDIO_F32SYS;
    } else {
        _this->spec.format = AUDIO_S16SYS;
    }
    if (_this->spec.channels < 1) {
        _this->spec.channels = 2;
    }
    if (_this->spec.channels > 2) {
        /* the mixer plays the front pair of a wider stream only: SDL downmixes 3..8 channels to stereo instead, so the
           centre and the surround channels are heard too */
        _this->spec.channels = 2;
    }
    SDL_CalculateAudioSpec(&_this->spec);

    _this->hidden = (struct SDL_PrivateAudioData *)SDL_calloc(1, sizeof(*_this->hidden));
    if (!_this->hidden) {
        return SDL_OutOfMemory();
    }
    _this->hidden->mixlen = _this->spec.size;
    _this->hidden->mixbuf = (Uint8 *)SDL_calloc(1, _this->spec.size);
    if (!_this->hidden->mixbuf) {
        return SDL_OutOfMemory();
    }
    {
        /* the queue budget: >= 2 buffers and >= NEXVYN_AUDIO_LATENCY_MS (default 100, 20..500) */
        Uint32 ms = 100;
        const char *h = SDL_GetHint("NEXVYN_AUDIO_LATENCY_MS");
        if (h && h[0]) {
            int v = SDL_atoi(h);
            ms = (Uint32)(v < 20 ? 20 : v > 500 ? 500 : v);
        }
        Uint32 frame = SDL_AUDIO_BITSIZE(_this->spec.format) / 8 * _this->spec.channels;
        _this->hidden->bytes_per_ms = (Uint32)((Uint64)_this->spec.freq * frame / 1000);
        Uint32 target = _this->hidden->bytes_per_ms * ms;
        if (target < 2 * _this->hidden->mixlen) {
            target = 2 * _this->hidden->mixlen;
        }
        _this->hidden->keep = target - _this->hidden->mixlen; /* the thread runs while queued <= keep */
        _this->hidden->stat_at = SDL_GetTicks();
        _this->hidden->poll = SDL_GetHintBoolean("NEXVYN_AUDIO_POLL", SDL_FALSE) ? 1 : 0;
    }
    nxn_audio_params p = NXN_STRUCT_INIT(nxn_audio_params);
    p.rate = (uint32_t)_this->spec.freq;
    p.channels = _this->spec.channels;
    p.format = _this->spec.format == AUDIO_F32SYS ? NXN_AUDIO_F32 : NXN_AUDIO_S16;
    p.frames = _this->spec.samples;
    if (nxn_audio_open(&p, &_this->hidden->stream) != NXN_OK) {
        return SDL_SetError("nxn_audio_open: %s", nxn_last_error());
    }
    nxn_audio_pause(_this->hidden->stream, 0);
    return 0;
}

static void NEXVYNAUDIO_WaitDevice(SDL_AudioDevice *_this)
{
    /* run while the queue is at or below the budget: after PlayDevice the ring holds `keep` + one buffer at the most */
    struct SDL_PrivateAudioData *h = _this->hidden;
    uint32_t q = nxn_audio_queued_bytes(h->stream);
    while (!SDL_AtomicGet(&_this->shutdown) && q > h->keep) {
        /* sleep about as long as the mixer needs to bring the queue down to the budget (it plays in real time), so the
         * thread wakes a few times per buffer instead of every millisecond; the queue still holds `keep` when it wakes.
         * Hint NEXVYN_AUDIO_POLL=1: the old 1 ms polling. */
        Uint32 ms = 1;
        if (!h->poll && h->bytes_per_ms) {
            ms = (q - h->keep) / h->bytes_per_ms;
            ms = ms < 1 ? 1 : ms > 20 ? 20 : ms;
        }
        SDL_Delay(ms);
        h->stat_sleeps++;
        q = nxn_audio_queued_bytes(h->stream);
    }
    /* statistics: this is the depth the mixer will find after the buffer we are about to write */
    h->stat_waits++;
    h->stat_depth += q;
    if (q == 0 && h->total_waits++ >= 4) {
        h->stat_empty++;
    }
    Uint32 now = SDL_GetTicks();
    if (now - h->stat_at >= 5000) {
        if (h->stat_waits && h->bytes_per_ms) {
            nxn_log(h->stat_empty ? NXN_LOG_WARN : NXN_LOG_INFO,
                    "sdl audio: %u buffers in %u ms, %u found the queue empty (underrun), queue avg %.1f ms of a %.0f ms budget, "
                    "%u wake-ups (%s)",
                    h->stat_waits, now - h->stat_at, h->stat_empty,
                    (double)h->stat_depth / h->stat_waits / h->bytes_per_ms, (double)(h->keep + h->mixlen) / h->bytes_per_ms,
                    h->stat_sleeps, h->poll ? "1 ms poll" : "timed");
        }
        h->stat_at = now;
        h->stat_waits = h->stat_empty = h->stat_sleeps = 0;
        h->stat_depth = 0;
    }
}

static void NEXVYNAUDIO_PlayDevice(SDL_AudioDevice *_this)
{
    nxn_audio_queue(_this->hidden->stream, _this->hidden->mixbuf, _this->hidden->mixlen);
}

static Uint8 *NEXVYNAUDIO_GetDeviceBuf(SDL_AudioDevice *_this)
{
    return _this->hidden->mixbuf;
}

static void NEXVYNAUDIO_CloseDevice(SDL_AudioDevice *_this)
{
    if (!_this->hidden) {
        return;
    }
    if (_this->hidden->stream) {
        nxn_audio_close(_this->hidden->stream);
    }
    SDL_free(_this->hidden->mixbuf);
    SDL_free(_this->hidden);
    _this->hidden = NULL;
}

static SDL_bool NEXVYNAUDIO_Init(SDL_AudioDriverImpl *impl)
{
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    if (nxn_caps_get(&caps) != NXN_OK || !(caps.features & NXN_CAP_WINDOWED) || !(caps.features & NXN_CAP_AUDIO)) {
        return SDL_FALSE;
    }
    impl->OpenDevice = NEXVYNAUDIO_OpenDevice;
    impl->WaitDevice = NEXVYNAUDIO_WaitDevice;
    impl->PlayDevice = NEXVYNAUDIO_PlayDevice;
    impl->GetDeviceBuf = NEXVYNAUDIO_GetDeviceBuf;
    impl->CloseDevice = NEXVYNAUDIO_CloseDevice;
    impl->OnlyHasDefaultOutputDevice = SDL_TRUE;
    return SDL_TRUE;
}

AudioBootStrap NEXVYNAUDIO_bootstrap = {"nexvyn", "Nexvyn OS audio driver", NEXVYNAUDIO_Init, SDL_FALSE};

#endif /* SDL_AUDIO_DRIVER_NEXVYN */
