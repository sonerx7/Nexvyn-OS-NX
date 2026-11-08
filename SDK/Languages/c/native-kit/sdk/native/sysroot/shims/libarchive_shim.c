// Weak stand-ins that libarchive needs to link on newlib/libnx. All of them are for features the Switch cannot do:
//  - fchdir(): archive_read_disk walks directory trees with it (archiving a directory); fails with ENOSYS.
//  - waitpid(), __archive_create_child(), __archive_check_child(): the "program" filters (gzip -d through an external
//    process). There is no fork/exec, so they fail cleanly; the built-in gzip/bzip2/zstd/lz4 filters do the work.
// Weak on purpose: the compat layer (sdk/native/compat) may define real versions and those win.
// Reading and writing archives in memory and through files (the normal use) never reaches any of this.
#include <errno.h>
#include <sys/types.h>

__attribute__((weak)) int fchdir(int fd) { (void)fd; errno = ENOSYS; return -1; }

__attribute__((weak)) pid_t waitpid(pid_t pid, int *status, int options)
{
    (void)pid; (void)status; (void)options;
    errno = ECHILD;
    return -1;
}

__attribute__((weak)) int __archive_create_child(const char *cmd, int *child_stdin, int *child_stdout, pid_t *out_child)
{
    (void)cmd; (void)child_stdin; (void)child_stdout; (void)out_child;
    errno = ENOSYS;
    return -1; // the caller reports ARCHIVE_FAILED
}

__attribute__((weak)) void __archive_check_child(int in, int out) { (void)in; (void)out; }
