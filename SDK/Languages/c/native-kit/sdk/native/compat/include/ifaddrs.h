/* Nexvyn compat layer: <ifaddrs.h>. The OS owns the network interface; getifaddrs() always fails with ENOSYS (one log line),
 * so ports that probe for local addresses compile and fall back cleanly. */
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

int getifaddrs(struct ifaddrs** ifap);
void freeifaddrs(struct ifaddrs* ifa);

#ifdef __cplusplus
}
#endif
#endif
