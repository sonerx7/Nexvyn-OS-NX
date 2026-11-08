/* Nexvyn compat layer - small POSIX pieces newlib declares badly or not at all (docs/NATIVE_COMPAT.en.md "Identity and
 * text input"): getline / getdelim, the single fixed user (getpwuid, getpwnam, getlogin), getifaddrs.
 * Add-only: nothing here replaces a libc call, so no --wrap entry is needed. */
#include <errno.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

/* ---- getifaddrs: the OS owns the network interface; an app has no list of them ---- */
struct ifaddrs;
int getifaddrs(struct ifaddrs** ifap) {
    if (ifap) *ifap = NULL;
    nxc_unsupported("getifaddrs", "network interfaces are not listed; connect to a host name or address directly");
    return NXC_FAIL(ENOSYS);
}
void freeifaddrs(struct ifaddrs* ifa) { (void)ifa; }
