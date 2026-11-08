/* Nexvyn compat: prototypes of the POSIX calls the layer adds that newlib's headers do not declare, plus the optional
 * NXC_STRICT warnings. nexvyn_use_compat() force-includes it (-include nexvyn/compat_posix.h) so unmodified PC sources see
 * the calls; with a plain Makefile, add the same flag or include the header yourself. */
#ifndef NEXVYN_COMPAT_POSIX_H
#define NEXVYN_COMPAT_POSIX_H

#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/select.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "nexvyn/compat.h"
#include "nexvyn/nxc_clockids.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef O_CLOEXEC
#define O_CLOEXEC 0x80000
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 0x200000
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif
#ifndef TIMER_ABSTIME
#define TIMER_ABSTIME 1
#endif

/* C11: newlib has no timespec_get(). Only TIME_UTC (wall clock) is supported; returns the base, or 0 for any other. */
int timespec_get(struct timespec* ts, int base);
int pipe(int fds[2]);
int pipe2(int fds[2], int flags);
/* getline / getdelim: real (newlib keeps them under __getline / __getdelim only) */
ssize_t getdelim(char** lineptr, size_t* n, int delim, FILE* stream);
ssize_t getline(char** lineptr, size_t* n, FILE* stream);
pid_t getppid(void);
uid_t getuid(void);
uid_t geteuid(void);
gid_t getgid(void);
gid_t getegid(void);
pid_t getpgrp(void);
pid_t getpgid(pid_t pid);
pid_t getsid(pid_t pid);
pid_t setsid(void);
pid_t vfork(void);
int execvpe(const char* file, char* const argv[], char* const envp[]);
int clock_nanosleep(clockid_t clock_id, int flags, const struct timespec* req, struct timespec* rem);
int daemon(int nochdir, int noclose);
int ppoll(struct pollfd* fds, nfds_t nfds, const struct timespec* timeout, const sigset_t* sigmask);
int pselect(int nfds, fd_set* rd, fd_set* wr, fd_set* ex, const struct timespec* timeout, const sigset_t* sigmask);
int mkfifo(const char* path, mode_t mode);
int mknod(const char* path, mode_t mode, dev_t dev);
int chown(const char* path, uid_t owner, gid_t group);
int lchown(const char* path, uid_t owner, gid_t group);
int fchown(int fd, uid_t owner, gid_t group);
pid_t waitpid(pid_t pid, int* status, int options);
FILE* popen(const char* command, const char* mode);
int pclose(FILE* stream);
int getpagesize(void);
int clearenv(void);
char* secure_getenv(const char* name);
useconds_t ualarm(useconds_t usecs, useconds_t interval);
int killpg(pid_t pgrp, int sig);
int pthread_kill(pthread_t thread, int sig);

/* NXC_STRICT=1: calls that cannot work on this platform warn at compile time; NXC_STRICT=2: they are errors. */
#if defined(NXC_STRICT) && NXC_STRICT
#if NXC_STRICT >= 2
#define NXC_STRICT_ATTR(msg) __attribute__((error(msg)))
#else
#define NXC_STRICT_ATTR(msg) __attribute__((warning(msg)))
#endif
#define NXC_STRICT_PROC "Nexvyn: there is a single process (no fork / exec / spawn / system / popen); use a thread or call the code in-process"
extern pid_t fork(void) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern pid_t vfork(void) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int execv(const char*, char* const[]) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int execve(const char*, char* const[], char* const[]) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int execvp(const char*, char* const[]) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int execvpe(const char*, char* const[], char* const[]) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int system(const char*) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern FILE* popen(const char*, const char*) NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int posix_spawn(pid_t*, const char*, const posix_spawn_file_actions_t*, const posix_spawnattr_t*, char* const[], char* const[])
    NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int posix_spawnp(pid_t*, const char*, const posix_spawn_file_actions_t*, const posix_spawnattr_t*, char* const[], char* const[])
    NXC_STRICT_ATTR(NXC_STRICT_PROC);
extern int symlink(const char*, const char*)
    NXC_STRICT_ATTR("Nexvyn: the SD card is FAT, there are no symbolic links; copy the file or keep a path table");
extern int link(const char*, const char*)
    NXC_STRICT_ATTR("Nexvyn: the SD card is FAT, there are no hard links; copy the file or keep a path table");
extern int mkfifo(const char*, mode_t) NXC_STRICT_ATTR("Nexvyn: no named pipes on the SD card; use pipe() inside one process");
#endif

#ifdef __cplusplus
}
#endif
#endif
