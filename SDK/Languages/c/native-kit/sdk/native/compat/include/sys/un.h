/* Nexvyn compat layer: <sys/un.h>. The type only: there are no UNIX-domain sockets, socket(AF_UNIX, ...) fails with the
 * libnx error (EAFNOSUPPORT), so code that tries them first and falls back to TCP / UDP works. */
#ifndef NEXVYN_SYS_UN_H
#define NEXVYN_SYS_UN_H
#include <string.h>
#include <sys/socket.h>

#ifndef AF_UNIX
#define AF_UNIX 1
#endif
#ifndef AF_LOCAL
#define AF_LOCAL AF_UNIX
#endif
#ifndef PF_UNIX
#define PF_UNIX AF_UNIX
#endif

struct sockaddr_un {
    sa_family_t sun_family;
    char sun_path[108];
};

#define SUN_LEN(su) (sizeof(*(su)) - sizeof((su)->sun_path) + strlen((su)->sun_path))
#endif
