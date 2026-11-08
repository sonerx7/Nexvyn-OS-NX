/* Nexvyn OS SDL2 driver (windowed native apps): audio. Added to SDL2 (zlib license) by the Nexvyn native kit. */
#ifndef SDL_nexvynaudio_h_
#define SDL_nexvynaudio_h_

#include <nexvyn/nexvyn_native.h>

struct SDL_PrivateAudioData
{
    nxn_audio *stream;
    Uint8 *mixbuf;
    Uint32 mixlen;
    Uint32 keep;         /* WaitDevice lets the thread run while at most this many bytes are queued */
    Uint32 bytes_per_ms;
    Uint32 stat_at;      /* SDL_GetTicks of the last statistics line */
    Uint32 total_waits;  /* buffers since the device opened: the first few always find an empty queue (start-up, not an underrun) */
    Uint32 stat_waits, stat_empty; /* buffers written, and of those the ones that found the queue already empty (underrun) */
    Uint64 stat_depth;   /* sum of the queue depth (bytes) seen at each buffer */
    Uint32 stat_sleeps;  /* WaitDevice sleeps since the last statistics line (thread wake-ups) */
    int poll;            /* hint NEXVYN_AUDIO_POLL: the old 1 ms polling instead of sleeping until the queue drains */
};

#endif /* SDL_nexvynaudio_h_ */
