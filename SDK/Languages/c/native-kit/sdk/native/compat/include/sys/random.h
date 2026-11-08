/* Nexvyn compat: <sys/random.h> (getrandom, getentropy over the system random service). */
#ifndef NEXVYN_COMPAT_SYS_RANDOM_H
#define NEXVYN_COMPAT_SYS_RANDOM_H

#include <sys/types.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GRND_NONBLOCK 1
#define GRND_RANDOM   2

ssize_t getrandom(void* buf, size_t len, unsigned int flags);
int getentropy(void* buf, size_t len);

#ifdef __cplusplus
}
#endif
#endif
