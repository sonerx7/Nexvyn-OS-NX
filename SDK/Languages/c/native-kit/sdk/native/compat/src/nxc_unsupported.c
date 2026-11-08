/* Nexvyn compat layer - things that cannot exist on this platform (one process, FAT file system): they fail with ENOSYS
 * (or the natural error code) and write one log line per call name, instead of returning garbage or not linking. */
#include <errno.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "nxc_internal.h"

#define NO_PROC "there is a single process; run the work in a thread, or call the code in-process"
#define NO_PTY "there are no terminals; use pipe() or a socket pair of your own"
#define NO_LINK "the SD card is FAT: no symbolic or hard links; copy the file or keep a path table"

pid_t __wrap_fork(void) {
    nxc_unsupported("fork", NO_PROC);
    return NXC_FAIL(ENOSYS);
}

pid_t vfork(void) {
    nxc_unsupported("vfork", NO_PROC);
    return NXC_FAIL(ENOSYS);
}

int __wrap_execve(const char* path, char* const argv[], char* const envp[]) {
    nxc_unsupported("exec*", NO_PROC);
    return NXC_FAIL(ENOSYS);
}

int execv(const char* path, char* const argv[]) { return __wrap_execve(path, argv, NULL); }
int execvp(const char* file, char* const argv[]) { return __wrap_execve(file, argv, NULL); }
int execvpe(const char* file, char* const argv[], char* const envp[]) { return __wrap_execve(file, argv, envp); }
int execl(const char* path, const char* arg, ...) { return __wrap_execve(path, NULL, NULL); }
int execlp(const char* file, const char* arg, ...) { return __wrap_execve(file, NULL, NULL); }
int execle(const char* path, const char* arg, ...) { return __wrap_execve(path, NULL, NULL); }

int __wrap_system(const char* cmd) {
    if (!cmd) return 0; /* "is a shell available?" - no */
    nxc_unsupported("system", "there is no shell; call the code in-process");
    return NXC_FAIL(ENOSYS);
}

FILE* popen(const char* cmd, const char* mode) {
    nxc_unsupported("popen", "there is no shell; call the code in-process or use pipe()");
    errno = ENOSYS;
    return NULL;
}

int pclose(FILE* f) { return NXC_FAIL(ECHILD); }

int posix_spawn(pid_t* pid, const char* path, const posix_spawn_file_actions_t* fa, const posix_spawnattr_t* attr, char* const argv[],
                char* const envp[]) {
    nxc_unsupported("posix_spawn", NO_PROC);
    return ENOSYS;
}

int posix_spawnp(pid_t* pid, const char* file, const posix_spawn_file_actions_t* fa, const posix_spawnattr_t* attr, char* const argv[],
                 char* const envp[]) {
    return posix_spawn(pid, file, fa, attr, argv, envp);
}

/* No child can exist, so waiting for one is ECHILD: the natural answer, no log noise. */
pid_t __wrap_wait(int* status) { return NXC_FAIL(ECHILD); }
pid_t waitpid(pid_t pid, int* status, int options) { return NXC_FAIL(ECHILD); }

int openpty(int* amaster, int* aslave, char* name, const void* termp, const void* winp) {
    nxc_unsupported("openpty", NO_PTY);
    return NXC_FAIL(ENOSYS);
}

pid_t forkpty(int* amaster, char* name, const void* termp, const void* winp) {
    nxc_unsupported("forkpty", NO_PTY);
    return NXC_FAIL(ENOSYS);
}

int posix_openpt(int flags) {
    nxc_unsupported("posix_openpt", NO_PTY);
    return NXC_FAIL(ENOSYS);
}

int grantpt(int fd) { return NXC_FAIL(ENOSYS); }
int unlockpt(int fd) { return NXC_FAIL(ENOSYS); }
char* ptsname(int fd) {
    errno = ENOSYS;
    return NULL;
}

int daemon(int nochdir, int noclose) {
    nxc_unsupported("daemon", NO_PROC);
    return NXC_FAIL(ENOSYS);
}

pid_t setsid(void) { return NXC_FAIL(EPERM); }

int mknod(const char* path, mode_t mode, dev_t dev) {
    nxc_unsupported("mknod", "device and fifo nodes do not exist on the SD card");
    return NXC_FAIL(ENOSYS);
}

int __wrap_symlink(const char* target, const char* linkpath) {
    nxc_unsupported("symlink", NO_LINK);
    return NXC_FAIL(ENOSYS);
}

int __wrap_link(const char* existing, const char* newpath) {
    nxc_unsupported("link", NO_LINK);
    return NXC_FAIL(ENOSYS);
}

ssize_t __wrap_readlink(const char* path, char* buf, size_t size) { return NXC_FAIL(EINVAL); /* nothing is a link on FAT */ }

/* FAT has no owners: accepted, nothing to change (programs call these after creating files). */
int chown(const char* path, uid_t owner, gid_t group) { return 0; }
int lchown(const char* path, uid_t owner, gid_t group) { return 0; }
int fchown(int fd, uid_t owner, gid_t group) { return 0; }
