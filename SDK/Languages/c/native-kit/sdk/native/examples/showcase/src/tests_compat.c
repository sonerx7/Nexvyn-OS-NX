/* Native SDK Showcase - compat layer checks (libnexvyn_compat is linked into the app: the .nro build and the window / full screen module). */
#include <dlfcn.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/eventfd.h>
#include <sys/mman.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/compat.h>

int sc_c_pipe(char* msg, size_t n) {
    int fd[2];
    if (pipe(fd) != 0) {
        snprintf(msg, n, "pipe() failed, errno %d", errno);
        return 0;
    }
    char buf[8] = {0};
    int w = (int)write(fd[1], "ping", 4);
    int r = (int)read(fd[0], buf, 4);
    close(fd[0]);
    close(fd[1]);
    snprintf(msg, n, "wrote %d, read %d (%s)", w, r, buf);
    return w == 4 && r == 4 && !strcmp(buf, "ping");
}

int sc_c_poll(char* msg, size_t n) {
    int fd[2];
    if (pipe(fd) != 0) {
        snprintf(msg, n, "pipe() failed, errno %d", errno);
        return 0;
    }
    struct pollfd p = {fd[0], POLLIN, 0};
    int idle = poll(&p, 1, 0);
    if (write(fd[1], "x", 1) != 1) idle = -99;
    p.revents = 0;
    int ready = poll(&p, 1, 100);
    close(fd[0]);
    close(fd[1]);
    snprintf(msg, n, "empty pipe: %d ready, after write: %d ready (revents 0x%x)", idle, ready, (unsigned)p.revents);
    return idle == 0 && ready == 1 && (p.revents & POLLIN);
}

int sc_c_eventfd(char* msg, size_t n) {
    int fd = eventfd(0, 0);
    if (fd < 0) {
        snprintf(msg, n, "eventfd() failed, errno %d", errno);
        return 0;
    }
    eventfd_t v = 0;
    int w = eventfd_write(fd, 5);
    w |= eventfd_write(fd, 2);
    int r = eventfd_read(fd, &v);
    close(fd);
    snprintf(msg, n, "5 + 2 written, counter read as %llu", (unsigned long long)v);
    return w == 0 && r == 0 && v == 7;
}

int sc_c_select(char* msg, size_t n) {
    int fd[2];
    if (pipe(fd) != 0) {
        snprintf(msg, n, "pipe() failed, errno %d", errno);
        return 0;
    }
    fd_set rs;
    struct timeval tv = {0, 0};
    FD_ZERO(&rs);
    FD_SET(fd[0], &rs);
    int idle = select(fd[0] + 1, &rs, NULL, NULL, &tv);
    if (write(fd[1], "x", 1) != 1) idle = -99;
    FD_ZERO(&rs);
    FD_SET(fd[0], &rs);
    tv.tv_usec = 100000;
    int ready = select(fd[0] + 1, &rs, NULL, NULL, &tv);
    int set = FD_ISSET(fd[0], &rs) != 0;
    close(fd[0]);
    close(fd[1]);
    snprintf(msg, n, "empty: %d, after write: %d (fd set %d)", idle, ready, set);
    return idle == 0 && ready == 1 && set;
}

int sc_c_mmap(char* msg, size_t n) {
    size_t len = 3 * 4096;
    unsigned char* p = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) {
        snprintf(msg, n, "anonymous mmap failed, errno %d", errno);
        return 0;
    }
    int zero = 1;
    for (size_t i = 0; i < len; i++) zero &= p[i] == 0;
    memset(p, 0xAB, len);
    int aligned = ((size_t)p & 4095) == 0;
    int un = munmap(p, len);
    /* file mapping: read a small file back through mmap */
    char path[320];
    int file_ok = 0;
    nxn_fs_write(NXN_DIR_CACHE, "mmap_test.bin", "mapped file data", 16);
    nxn_fs_path(NXN_DIR_CACHE, "mmap_test.bin", path, sizeof path);
    int fd = open(path, O_RDONLY);
    if (fd >= 0) {
        char* m = mmap(NULL, 16, PROT_READ, MAP_PRIVATE, fd, 0);
        if (m != MAP_FAILED) {
            file_ok = memcmp(m, "mapped file data", 16) == 0;
            munmap(m, 16);
        }
        close(fd);
    }
    unlink(path);
    snprintf(msg, n, "anonymous %zu bytes: zeroed %d, 4K aligned %d, munmap %d; file mapping %s", len, zero, aligned, un,
             file_ok ? "reads the file" : "FAILED");
    return zero && aligned && un == 0 && file_ok;
}

int sc_c_mprotect(char* msg, size_t n) {
    unsigned char* p = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) {
        snprintf(msg, n, "mmap failed, errno %d", errno);
        return 0;
    }
    p[0] = 1;
    int a = mprotect(p, 4096, PROT_READ);
    int b = mprotect(p, 4096, PROT_READ | PROT_WRITE);
    p[0] = 2;
    errno = 0;
    int bad = mprotect(p + 1, 100, PROT_READ); /* unaligned address: must fail with EINVAL */
    int e = errno;
    munmap(p, 4096);
    snprintf(msg, n, "RO %d, RW again %d, unaligned address -> %d (errno %d)", a, b, bad, e);
    return a == 0 && b == 0 && bad == -1 && e == EINVAL;
}

static volatile sig_atomic_t g_alarm, g_usr1;
static void on_alarm(int s) {
    (void)s;
    g_alarm++;
}
static void on_usr1(int s) {
    (void)s;
    g_usr1++;
}

int sc_c_signal(char* msg, size_t n) {
    g_alarm = g_usr1 = 0;
    signal(SIGUSR1, on_usr1);
    raise(SIGUSR1);
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_alarm;
    sigaction(SIGALRM, &sa, NULL);
    ualarm(40000, 0);
    usleep(200000); /* the handler runs inside the sleep */
    nxc_signal_poll();
    snprintf(msg, n, "raise(SIGUSR1): handler ran %d time(s); ualarm(40 ms): SIGALRM handler ran %d time(s)", (int)g_usr1,
             (int)g_alarm);
    return g_usr1 == 1 && g_alarm == 1;
}

int sc_c_fcntl(char* msg, size_t n) {
    int a = fcntl(1, F_GETFL);
    char path[320];
    nxn_fs_write(NXN_DIR_CACHE, "fcntl_test.bin", "x", 1);
    nxn_fs_path(NXN_DIR_CACHE, "fcntl_test.bin", path, sizeof path);
    int fd = open(path, O_RDWR);
    int b = fd >= 0 ? fcntl(fd, F_GETFL) : -1;
    int c = fd >= 0 ? fcntl(fd, F_SETFD, FD_CLOEXEC) : -1;
    int d = fd >= 0 ? fcntl(fd, F_GETFD) : -1;
    if (fd >= 0) close(fd);
    unlink(path);
    snprintf(msg, n, "stdout F_GETFL %d, file F_GETFL %d, F_SETFD %d, F_GETFD %d", a, b, c, d);
    return a >= 0 && b >= 0 && c == 0 && d >= 0;
}

int sc_c_devnull(char* msg, size_t n) {
    FILE* w = fopen("/dev/null", "w");
    FILE* r = fopen("/dev/null", "r");
    if (!w || !r) {
        snprintf(msg, n, "fopen failed (errno %d)", errno);
        if (w) fclose(w);
        if (r) fclose(r);
        return 0;
    }
    size_t wrote = fwrite("discard me", 1, 10, w);
    fflush(w);
    char b[4];
    size_t got = fread(b, 1, sizeof b, r);
    struct stat st;
    int s = stat("/dev/null", &st);
    fclose(w);
    fclose(r);
    snprintf(msg, n, "write %zu swallowed, read %zu (EOF), stat %d", wrote, got, s);
    return wrote == 10 && got == 0 && s == 0;
}

int sc_c_devrandom(char* msg, size_t n) {
    unsigned char a[32], b[32];
    FILE* f = fopen("/dev/random", "rb");
    if (!f) {
        snprintf(msg, n, "fopen failed (errno %d)", errno);
        return 0;
    }
    size_t ra = fread(a, 1, sizeof a, f), rb = fread(b, 1, sizeof b, f);
    fclose(f);
    int zero = 1;
    for (size_t i = 0; i < sizeof a; i++) zero &= a[i] == 0;
    int same = memcmp(a, b, sizeof a) == 0;
    snprintf(msg, n, "read %zu + %zu bytes, first %02x%02x%02x%02x, two reads differ: %d", ra, rb, a[0], a[1], a[2], a[3], !same);
    return ra == sizeof a && rb == sizeof b && !zero && !same;
}

int sc_c_timespec(char* msg, size_t n) {
    struct timespec ts = {0, 0}, bad = {0, 0};
    int base = timespec_get(&ts, TIME_UTC);
    int other = timespec_get(&bad, 99);
    long long unix_now = (long long)nxn_time_unix();
    snprintf(msg, n, "TIME_UTC -> %d (sec %lld, nxn_time_unix %lld), unknown base -> %d", base, (long long)ts.tv_sec, unix_now, other);
    return base == TIME_UTC && other == 0 && (ts.tv_sec - unix_now < 3) && (unix_now - ts.tv_sec < 3);
}

static int g_steps;
static void coro_body(void* arg) {
    (void)arg;
    for (int i = 0; i < 3; i++) {
        g_steps++;
        nxc_coro_yield();
    }
}

int sc_c_coro(char* msg, size_t n) {
    g_steps = 0;
    nxc_coro* c = nxc_coro_create(coro_body, NULL, 0);
    if (!c) {
        snprintf(msg, n, "nxc_coro_create failed");
        return 0;
    }
    int resumes = 0, rc;
    while ((rc = nxc_coro_resume(c)) == 1) resumes++;
    int done = nxc_coro_done(c);
    size_t spare = nxc_coro_stack_free(c);
    nxc_coro_destroy(c);
    snprintf(msg, n, "3 yields, %d resumes, final %d, done %d, %zu stack bytes untouched", resumes, rc, done, spare);
    return resumes == 3 && rc == 0 && done && g_steps == 3;
}

int sc_c_dlopen(char* msg, size_t n) {
    void* h = dlopen("libgreet.so", RTLD_NOW);
    if (!h) {
        const char* e = dlerror();
        snprintf(msg, n, "dlopen(libgreet.so) failed: %s", e ? e : "?");
        return 0;
    }
    const char* (*hello)(void) = (const char* (*)(void))dlsym(h, "greet_hello");
    const char* text = hello ? hello() : NULL;
    int none = dlsym(h, "no_such_symbol") == NULL;
    dlclose(h);
    snprintf(msg, n, "dlsym greet_hello -> %s; unknown symbol gives NULL: %d", text ? text : "?", none);
    return text && strstr(text, "greet") && none;
}

/* BSD sockets: in a window they need "network" in app.json "permissions" (Nexvyn OS answers EACCES without it). Both
 * outcomes are correct; the message says which one this run is. */
int sc_c_socket(char* msg, size_t n) {
    errno = 0;
    uint64_t t0 = nxn_time_ns();
    int s = socket(AF_INET, SOCK_STREAM, 0);
    uint64_t t1 = nxn_time_ns();
    if (s < 0) {
        int e = errno;
        struct addrinfo* res = (struct addrinfo*)1;
        int g = getaddrinfo("localhost", "80", NULL, &res);
        snprintf(msg, n, "no socket: errno %d (%s), getaddrinfo %d", e, strerror(e), g);
        return e == EACCES && g != 0 && res == NULL; /* denied cleanly */
    }
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    a.sin_port = 0;
    int one = 1;
    int o = setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    uint64_t t2 = nxn_time_ns();
    int b = bind(s, (struct sockaddr*)&a, sizeof a);
    uint64_t t3 = nxn_time_ns();
    int l = b == 0 ? listen(s, 1) : -1;
    uint64_t t4 = nxn_time_ns();
    close(s);
    uint64_t t5 = nxn_time_ns();
    snprintf(msg, n, "permission network: socket ok, setsockopt %d, bind %d, listen %d (ms: socket %llu, setsockopt %llu, bind %llu, listen %llu, close %llu)",
             o, b, l, (unsigned long long)((t1 - t0) / 1000000), (unsigned long long)((t2 - t1) / 1000000),
             (unsigned long long)((t3 - t2) / 1000000), (unsigned long long)((t4 - t3) / 1000000),
             (unsigned long long)((t5 - t4) / 1000000));
    return o == 0 && b == 0 && l == 0;
}

/* own environment and working directory (in a window they belong to this app, not to Nexvyn OS) */
int sc_c_envcwd(char* msg, size_t n) {
    char before[512] = "", after[512] = "", sub[512], made[640];
    int ok = 1;
    getcwd(before, sizeof before);
    ok &= setenv("SC_ENV_TEST", "one", 1) == 0 && strcmp(getenv("SC_ENV_TEST") ? getenv("SC_ENV_TEST") : "", "one") == 0;
    nxn_fs_path(NXN_DIR_CACHE, "cwd_test", sub, sizeof sub);
    mkdir(sub, 0777);
    ok &= chdir(sub) == 0;
    FILE* f = fopen("rel.txt", "w"); /* relative: lands in the new working directory */
    if (f) {
        fputs("x", f);
        fclose(f);
    }
    snprintf(made, sizeof made, "%s/rel.txt", sub);
    struct stat st;
    ok &= stat(made, &st) == 0 && stat("rel.txt", &st) == 0;
    getcwd(after, sizeof after);
    ok &= strcmp(after, sub) == 0;
    unlink("rel.txt");
    if (before[0]) chdir(before);
    rmdir(sub);
    unsetenv("SC_ENV_TEST");
    ok &= getenv("SC_ENV_TEST") == NULL;
    snprintf(msg, n, "cwd %s -> %s and back, relative fopen landed in it, env set / unset", before, after);
    return ok;
}
