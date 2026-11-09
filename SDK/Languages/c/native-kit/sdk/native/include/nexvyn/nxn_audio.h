/* Nexvyn Native SDK - audio: one output stream, either pulled by a callback or pushed by the app.
 *
 * Inside Nexvyn OS a stream is a source in the OS mixer (up to 8 per app; the mixer only reads the app's ring and never
 * runs app code). Stand-alone .nro builds use SDL2 audio. Apps that already use SDL audio (or SDL_mixer) keep doing so:
 * the passthrough is simply calling SDL directly; nxn_audio is for apps that do not want SDL.
 *
 * Threads: open, pause and close from any app thread; in push mode one thread at a time calls nxn_audio_queue (a
 * single producer feeds the stream's ring). Memory: the nxn_audio* handle is owned by the library and freed by
 * nxn_audio_close or when the app ends. */
#ifndef NEXVYN_NXN_AUDIO_H
#define NEXVYN_NXN_AUDIO_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_audio nxn_audio; /* opaque */

typedef enum nxn_audio_format {
    NXN_AUDIO_S16 = 0, /* signed 16-bit, interleaved */
    NXN_AUDIO_F32 = 1  /* float 32-bit, interleaved */
} nxn_audio_format;

/* Called on a thread the library owns (the audio thread; inside Nexvyn OS a thread of the app, never the mixer's): fill
 * `bytes` bytes. Keep it short; no file or network I/O; do not call nxn_audio_close from inside it. The buffer
 * belongs to the library and is valid only during the call; `user` stays the app's. */
typedef void (*nxn_audio_callback)(void* user, void* buffer, uint32_t bytes);

typedef struct nxn_audio_params {
    uint32_t size;
    uint32_t rate;      /* 0 = 48000 */
    uint32_t channels;  /* 0 = 2 */
    uint32_t format;    /* nxn_audio_format */
    uint32_t frames;    /* buffer size in sample frames, 0 = 1024 */
    nxn_audio_callback callback; /* NULL: push mode (nxn_audio_queue) */
    void* user;
} nxn_audio_params;

/* Opens the stream paused. params may be NULL (48 kHz stereo S16, push mode). params->size must be set
 * (NXN_STRUCT_INIT): with a size below 4 Nexvyn OS uses the defaults as for NULL, while the stand-alone library answers
 * NXN_ERR_INVALID (both kept as they are for compatibility).
 * Thread: any app thread. Memory: *out is a library-owned handle; `params` is only read during the call. */
NXN_API nxn_result nxn_audio_open(const nxn_audio_params* params, nxn_audio** out);
/* Thread: any app thread, not from the stream's own callback. Memory: frees the handle; it must not be used afterwards. */
NXN_API void nxn_audio_close(nxn_audio* a);
/* Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_audio_pause(nxn_audio* a, int paused);
/* Push mode: appends interleaved samples in the stream's format. It may wait a short time (up to 250 ms inside Nexvyn
 * OS) when the ring is full and then refuses the rest (NXN_ERR_TOO_SMALL).
 * Thread: one producer thread at a time. Memory: `data` is copied; it may be reused after the call. */
NXN_API nxn_result nxn_audio_queue(nxn_audio* a, const void* data, uint32_t bytes);
/* Thread: any app thread. Memory: none. */
NXN_API uint32_t nxn_audio_queued_bytes(nxn_audio* a);
/* Push mode: drops everything that is queued but not played yet, so the next nxn_audio_queue starts fresh (a seek, a
 * restart, leaving a menu, SDL_ClearQueuedAudio). nxn_audio_queued_bytes is 0 right after it. The sound already in the
 * mixer's hands (a few milliseconds) still plays. Check nxn_caps.features for NXN_CAP_AUDIO_CLEAR (Native 1.1).
 * Thread: the producer thread (the one that calls nxn_audio_queue). Memory: none. */
NXN_API nxn_result nxn_audio_clear(nxn_audio* a);

/* ---- the OS sound mixer (NXN_CAP_MIXER, windowed apps): short effects and tones without opening a stream of your own. They
 * play on the same mixer as the system sounds, follow the user's volume, and stop when the window closes. The calls
 * only queue the sound (they never wait for the mixer or a file); a sound that cannot be played is logged, not reported.
 * Without the cap they return NXN_ERR_UNSUPPORTED. */
/* Plays a system sound by name ("click", "notify", ...) or a sound file by path (wav, ogg, mp3). volume 0..1; loops 0 = once,
 * n = n more times (up to 99; stop them with nxn_sfx_stop_all). Thread: any app thread. Memory: the strings are copied. */
NXN_API nxn_result nxn_sfx_play(const char* name_or_path, float volume, int32_t loops);
/* A synthesized tone: freq_hz 20..20000, seconds 0.01..10, volume 0..1, wave 0 sine, 1 square, 2 saw, 3 triangle, 4 noise.
 * Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_tone(float freq_hz, float seconds, float volume, uint32_t wave);
/* Stops every sound this app started with nxn_sfx_play or nxn_tone. Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_sfx_stop_all(void);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_AUDIO_H */
