/* Nexvyn compat layer: <ifaddrs.h>. Returns a minimal interface list (loopback plus the primary IPv4 address from
 * gethostid() when nonzero). */
#ifndef NEXVYN_IFADDRS_H
#define NEXVYN_IFADDRS_H
#include <sys/socket.h>

#ifdef __cplusplus
extern "C" {
#endif

struct ifaddrs {
    struct ifaddrs* ifa_next;
    char* ifa_name;
    unsigned int ifa_flags;
    struct sockaddr* ifa_addr;
    struct sockaddr* ifa_netmask;
    struct sockaddr* ifa_dstaddr;
    void* ifa_data;
};

#ifndef ifa_broadaddr
#define ifa_broadaddr ifa_dstaddr
#endif

int getifaddrs(struct ifaddrs** ifap);
void freeifaddrs(struct ifaddrs* ifa);

#ifdef __cplusplus
}
#endif
#endif
