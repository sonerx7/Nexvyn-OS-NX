// Weak stand-ins for the two POSIX calls newlib/libnx lack that SQLite references (os_unix.c, syscall table).
// Weak on purpose: the compat layer (sdk/native/compat) or the app may define real ones and those win.
#include <errno.h>
#include <sys/types.h>

__attribute__((weak)) uid_t geteuid(void) { return 1000; } // non-zero: SQLite then never tries fchown()
__attribute__((weak)) int fchown(int fd, uid_t u, gid_t g) { (void)fd; (void)u; (void)g; errno = ENOSYS; return -1; }
