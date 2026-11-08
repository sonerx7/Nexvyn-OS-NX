/* Nexvyn compat: clock ids newlib hides unless _GNU_SOURCE / _POSIX_CPUTIME are set. Same numbers as newlib's <time.h>. */
#ifndef NEXVYN_NXC_CLOCKIDS_H
#define NEXVYN_NXC_CLOCKIDS_H

#ifndef CLOCK_REALTIME
#define CLOCK_REALTIME 1
#endif
#ifndef CLOCK_REALTIME_COARSE
#define CLOCK_REALTIME_COARSE 0
#endif
#ifndef CLOCK_PROCESS_CPUTIME_ID
#define CLOCK_PROCESS_CPUTIME_ID 2
#endif
#ifndef CLOCK_THREAD_CPUTIME_ID
#define CLOCK_THREAD_CPUTIME_ID 3
#endif
#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 4
#endif
#ifndef CLOCK_MONOTONIC_RAW
#define CLOCK_MONOTONIC_RAW 5
#endif
#ifndef CLOCK_MONOTONIC_COARSE
#define CLOCK_MONOTONIC_COARSE 6
#endif
#ifndef CLOCK_BOOTTIME
#define CLOCK_BOOTTIME 7
#endif
#ifndef CLOCK_REALTIME_ALARM
#define CLOCK_REALTIME_ALARM 8
#endif
#ifndef CLOCK_BOOTTIME_ALARM
#define CLOCK_BOOTTIME_ALARM 9
#endif

/* C11 timespec_get() base (newlib has none) */
#ifndef TIME_UTC
#define TIME_UTC 1
#endif

#endif
