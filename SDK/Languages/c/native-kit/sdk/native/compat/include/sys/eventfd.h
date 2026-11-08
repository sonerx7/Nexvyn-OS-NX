/* Nexvyn compat: <sys/eventfd.h>. In-process counters behind a normal file descriptor; read/write/poll/select/close
 * work on them. */
#ifndef NEXVYN_COMPAT_SYS_EVENTFD_H
#define NEXVYN_COMPAT_SYS_EVENTFD_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define EFD_SEMAPHORE 1
#define EFD_CLOEXEC   0x80000   /* accepted, ignored (there is no exec) */
#define EFD_NONBLOCK  0x4000    /* same value as O_NONBLOCK in newlib */

typedef uint64_t eventfd_t;

int eventfd(unsigned int initval, int flags);
int eventfd_read(int fd, eventfd_t* value);
int eventfd_write(int fd, eventfd_t value);

#ifdef __cplusplus
}
#endif
#endif
