/* Nexvyn compat layer - small POSIX pieces newlib declares badly or not at all (docs/NATIVE_COMPAT.en.md "Identity and
 * text input"): getline / getdelim, the single fixed user (getpwuid, getpwnam, getlogin), getifaddrs.
 * Add-only: nothing here replaces a libc call, so no --wrap entry is needed. */
#include <arpa/inet.h>
#include <errno.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include "nxc_internal.h"

/* ---- getline / getdelim: newlib has them only as __getdelim / __getline (no public name, no prototype) ---- */
ssize_t __getdelim(char** lineptr, size_t* n, int delim, FILE* stream);

ssize_t getdelim(char** lineptr, size_t* n, int delim, FILE* stream) { return __getdelim(lineptr, n, delim, stream); }
ssize_t getline(char** lineptr, size_t* n, FILE* stream) { return __getdelim(lineptr, n, '\n', stream); }

/* ---- the one user: uid / gid 1000 (getuid, geteuid, getgid, getegid in nxc_core.c), name "nexvyn" ---- */
#define NXC_USER "nexvyn"
#define NXC_UID 1000

static struct passwd g_pw;

static struct passwd* fill_pw(struct passwd* pw, char* name, char* dir, char* shell) {
    memset(pw, 0, sizeof *pw);
    pw->pw_name = name;
    pw->pw_passwd = shell; /* "" : no password */
    pw->pw_uid = NXC_UID;
    pw->pw_gid = NXC_UID;
    pw->pw_comment = shell;
    pw->pw_gecos = name;
    pw->pw_dir = dir;
    pw->pw_shell = shell;
    return pw;
}

static char* home_dir(void) {
    const char* h = getenv("HOME");
    return (char*)(h && *h ? h : "sdmc:/");
}

struct passwd* getpwuid(uid_t uid) {
    if (uid != NXC_UID) {
        errno = 0; /* "not found" is not an error */
        return NULL;
    }
    return fill_pw(&g_pw, (char*)NXC_USER, home_dir(), (char*)"");
}

struct passwd* getpwnam(const char* name) {
    if (!name || strcmp(name, NXC_USER)) {
        errno = 0;
        return NULL;
    }
    return getpwuid(NXC_UID);
}

static int pw_r(struct passwd* pwd, char* buf, size_t buflen, struct passwd** result) {
    const char* home = home_dir();
    size_t need = sizeof NXC_USER + strlen(home) + 1 + 1;
    *result = NULL;
    if (!pwd || !buf) return EINVAL;
    if (buflen < need) return ERANGE;
    char* name = buf;
    memcpy(name, NXC_USER, sizeof NXC_USER);
    char* dir = name + sizeof NXC_USER;
    memcpy(dir, home, strlen(home) + 1);
    char* shell = dir + strlen(home) + 1;
    *shell = 0;
    *result = fill_pw(pwd, name, dir, shell);
    return 0;
}

int getpwuid_r(uid_t uid, struct passwd* pwd, char* buf, size_t buflen, struct passwd** result) {
    if (uid != NXC_UID) {
        if (result) *result = NULL;
        return 0;
    }
    return pw_r(pwd, buf, buflen, result);
}

int getpwnam_r(const char* name, struct passwd* pwd, char* buf, size_t buflen, struct passwd** result) {
    if (!name || strcmp(name, NXC_USER)) {
        if (result) *result = NULL;
        return 0;
    }
    return pw_r(pwd, buf, buflen, result);
}

char* getlogin(void) { return (char*)NXC_USER; }
int getlogin_r(char* name, size_t len) {
    if (len < sizeof NXC_USER) return ERANGE;
    memcpy(name, NXC_USER, sizeof NXC_USER);
    return 0;
}

/* ---- getifaddrs: minimal list (loopback + primary IPv4 from gethostid() when nonzero) ---- */
typedef struct nxc_ifaddr_node {
    struct ifaddrs ifa;
    struct sockaddr_in addr;
    struct sockaddr_in netmask;
    char name[16];
} nxc_ifaddr_node;

static nxc_ifaddr_node* make_ifaddr(const char* name, unsigned int flags, in_addr_t addr_n, in_addr_t mask_n) {
    nxc_ifaddr_node* n = (nxc_ifaddr_node*)calloc(1, sizeof *n);
    if (!n) return NULL;
    snprintf(n->name, sizeof n->name, "%s", name);
    n->ifa.ifa_name = n->name;
    n->ifa.ifa_flags = flags;
    n->addr.sin_len = sizeof n->addr;
    n->addr.sin_family = AF_INET;
    n->addr.sin_addr.s_addr = addr_n;
    n->netmask.sin_len = sizeof n->netmask;
    n->netmask.sin_family = AF_INET;
    n->netmask.sin_addr.s_addr = mask_n;
    n->ifa.ifa_addr = (struct sockaddr*)&n->addr;
    if (mask_n) n->ifa.ifa_netmask = (struct sockaddr*)&n->netmask;
    return n;
}

int getifaddrs(struct ifaddrs** ifap) {
    if (!ifap) return NXC_FAIL(EINVAL);
    *ifap = NULL;
    nxc_ifaddr_node* lo = make_ifaddr("lo", IFF_UP | IFF_LOOPBACK | IFF_RUNNING,
                                      htonl(INADDR_LOOPBACK), htonl(0xff000000u));
    if (!lo) return NXC_FAIL(ENOMEM);

    struct in_addr host = {0};
#if NXC_WINDOWED
    /* The existing libnx gethostname import formats gethostid() via inet_ntop. */
    char address[INET_ADDRSTRLEN];
    if (gethostname(address, sizeof address) == 0)
        inet_pton(AF_INET, address, &host);
#else
    host.s_addr = (in_addr_t)gethostid();
#endif
    /* libnx can return INADDR_LOOPBACK in host order when NIFM is unavailable. */
    if (host.s_addr != 0 && host.s_addr != INADDR_LOOPBACK &&
        host.s_addr != htonl(INADDR_LOOPBACK)) {
        nxc_ifaddr_node* eth = make_ifaddr("en0", IFF_UP, host.s_addr, 0);
        if (!eth) {
            free(lo);
            return NXC_FAIL(ENOMEM);
        }
        lo->ifa.ifa_next = &eth->ifa;
    }
    *ifap = &lo->ifa;
    return 0;
}

void freeifaddrs(struct ifaddrs* ifa) {
    while (ifa) {
        struct ifaddrs* next = ifa->ifa_next;
        free(ifa);
        ifa = next;
    }
}
