# Nexvyn Native Compatibility Layer

`libnexvyn_compat.a` is an optional link-in layer for the native kit. It fills the POSIX gaps between libnx / newlib
and typical Linux or PC C and C++ code (emulators, decompilation ports, glib-style libraries) so that code compiles and
runs with few changes. It works the same in an exclusive `.nro` and in a window or Nexvyn full screen (a `.nxvmod`, in
process; section [In a window](#in-a-window-and-in-nexvyn-full-screen)). Nothing in it is needed by apps that only use the Nexvyn ABI or SDL2. It never
changes the OS: it is linked into the app, and an app that does not link it behaves exactly as before.

What it is not: a second operating system. There is one process, one address space and a FAT SD card. Calls that cannot
work (`fork`, `exec*`, ...) fail cleanly and say so in the app log; see [What cannot work](#what-cannot-work).

Source: `sdk/native/compat/`. Tests: `sdk/native/compat/tests/`. Version: `nxc_version()` (1.0, with Native SDK 1.0).

## Use it

Build the library once (inside the devkitPro shell, or `DEVKITPRO` set):

```
make -C sdk/native/compat   # -> lib/libnexvyn_compat.a (exclusive .nro) and lib/libnexvyn_compat_pic.a (window / full screen)
```

CMake (kit toolchain):

```cmake
include(${NEXVYN_KIT}/toolchain/nexvyn-native.cmake)
include(${NEXVYN_KIT}/compat/cmake/nexvyn-compat.cmake)
add_executable(mygame main.c)
target_link_libraries(mygame PRIVATE SDL2 ...)   # your own libraries first
nexvyn_use_compat(mygame)                        # the layer (any position: it is also repeated at the end of the link line)
nexvyn_compat_fsmap(mygame)                      # optional, see Paths
nexvyn_add_nro(mygame TITLE "My Game")
```

`nexvyn_use_compat(target [STRICT | STRICT_ERROR] [NO_FORCE_INCLUDE] [NO_WRAP])` is the same call in both modes: with `-DNEXVYN_WINDOWED=ON`
(what `nxv-native build` passes) it records the `-fPIC` archive and the wrap flags for the `.nxvmod` that `nexvyn_add_nro()` builds
from the same sources. In exclusive mode it adds the include folder, force-includes
`nexvyn/compat_posix.h`, links `-lnexvyn_compat` and the `--wrap` flags of `wrap_core.txt`. It works on its own: `nexvyn_compat_fsmap()` is only
for the PC path handling. The archive is also appended once at the very end of the link command of every C / C++
executable in the calling directory, so libraries CMake places after it (libEGL behind SDL2, ...) still find the wrapped
calls (`undefined reference to __wrap_fcntl` used to happen there).

Makefile (devkitPro style): `include <kit>/compat/compat.mk`, then add `$(NXC_CFLAGS)` to the compile flags,
`$(NXC_LDFLAGS)` to the link flags and `$(NXC_LIBS_END)` as the **last** item of `LIBS` (it is
`-Wl,--start-group -lnexvyn_compat -lnx -Wl,--end-group`: a static library is searched once, so it must come after every
library that calls a wrapped function). `$(NXC_LIBS)` is only `-lnexvyn_compat`, for projects that place it themselves.
`sdk/native/compat/tests/compat_test/Makefile` is a complete example.

Makefile projects that build a window (`.nxvmod`, `-fPIC`, `-shared`) link the objects with `$(NXC_WIN_LDFLAGS) $(NXC_WIN_LIBS)`
(the archive goes after the objects, before `-lnexvyn_window`); a hand-written `nexvyn_add_windowed()` uses
`nexvyn_compat_window_args()` (`examples/showcase/CMakeLists.txt`). The compile flags are the same `$(NXC_CFLAGS)`.

How it works: calls that libnx or newlib already define (`poll`, `select`, `fcntl`, `getpid`, `raise`, ...) are taken over
with the linker's `--wrap` option, so the original stays reachable and nothing is defined twice; calls that do not exist
(`mmap`, `pipe`, `getcontext`, ...) are plain definitions. Headers that newlib lacks (`<sys/mman.h>`, `<ucontext.h>`,
`<sys/ucontext.h>`, `<sys/eventfd.h>`, `<dlfcn.h>`, `<sys/utsname.h>`, `<sys/random.h>`) are in `compat/include/`; `<sys/signal.h>` and
`<sys/resource.h>` wrap newlib's header and add what it misses (`struct sigaction` with `sa_sigaction`, `siginfo_t` with
`si_addr` and `SEGV_*` / `BUS_*` codes, `SA_RESTART`, `getrlimit`).

`nxc_init()` is optional. It moves the working directory into the app's data folder (`nxn_fs_path(NXN_DIR_DATA)` when
the Nexvyn ABI is linked, else `sdmc:/switch`) and sets `HOME`, `PWD`, `TMPDIR`, `USER` if they are unset.

## In a window and in Nexvyn full screen

A `.nxvmod` runs inside Nexvyn OS's process, in a window or in Nexvyn's own full screen (one loader, one build; the user
switches while it runs). The layer is **linked into the app's module** (`libnexvyn_compat_pic.a`, the same sources built `-fPIC`
with `NXC_WINDOWED=1`), and Nexvyn OS's host import set offers what it needs from libnx and the C library (`poll`, `ioctl`,
`svcGetProcessId`, `FindDevice` / `AddDevice` / `RemoveDevice`, the BSD sockets below ...; the list is add-only,
`NATIVE_SDK_DESIGN.md` 3.2.2). So the same calls behave as in the table below, with these differences:

| Area | Exclusive `.nro` | Window / Nexvyn full screen |
|---|---|---|
| Whose state | the whole process is the app | every table of the layer lives in the app's module: descriptors, mappings, signals and the timer thread, environment, working directory belong to that app and never mix with another app or with Nexvyn OS |
| Descriptors (`pipe`, `eventfd`, `/dev/*`) | devoptab `nxcfd:` | a devoptab of its own per window (named after the module's address), closed and removed when the app ends |
| Working directory | the process's | the app's own: `chdir`, `getcwd`, `realpath` and every relative path of the wrapped calls (`open`, `fopen`, `stat`, `access`, `mkdir`, `opendir`, `rename`, `unlink`, `utime`, `utimes`, `utimensat` ... the file family of `wrap_fsmap.txt` and `wrap_core.txt`, always wrapped here) use it. The process's directory is Nexvyn OS's and is never changed. Calls outside that family (`creat` ...) need an absolute path |
| Environment | newlib's table | the app's own table and `environ`: `setenv`, `putenv`, `getenv`, `clearenv` never change Nexvyn OS's environment; `putenv` copies the string and never writes into it (a literal in read-only memory is fine) |
| `getpid` | the process id | the same (the process is Nexvyn OS's, shared) |
| Runtime hooks | `libnexvyn_native` calls the layer | the same effect, done with `--wrap` on `nxn_init`, `nxn_event_poll`, `nxn_should_quit`, `nxn_sleep_ns`, `nxn_shutdown`, `nxn_run` (Nexvyn OS implements `nxn_*` and cannot call into the module). `nxn_thread_join` waits normally: a signal is delivered after the join, not during it |
| App end | process exit | `nxc_shutdown`, then descriptors, mappings (`MAP_SHARED` written back), environment, sockets and TLS slots are released from `atexit`, on the app's thread while its code is still mapped. Not reclaimed (as for any window, `NATIVE_SDK_DESIGN.md` 3.2.7): files opened with `open` / `fopen` and the app's own heap |
| `thread_local` | allowed | with setting `native.windowedTls` (`NXN_CAP_TLS`; objects built with the kit's `-mtls-dialect=trad`, `NATIVE_SDK_DESIGN.md` 3.2.10); off: refused at load. The layer itself uses libnx TLS slots |
| Sockets | libnx | libnx behind the permission check, see [Sockets](#sockets-in-a-window) |
| `dlopen`, `PROT_EXEC` | `.nxvlib` / JIT service later | `dlopen` loads `.nxvlib` files with setting `native.windowedLibs` (`NXN_CAP_SHARED_LIBS`), otherwise it returns `NULL` with the reason; `PROT_EXEC` is `ENOTSUP` (executable memory: `nxn_jit_*`, setting `native.windowedJit`, `NXN_CAP_JIT`); both fail cleanly |
| `romfs:/` | the NRO's romfs | none: ship files in the package (`nxn_fs_path`) |

A window and Nexvyn full screen are the same module and the same layer: nothing in it knows the display mode. A window and an
exclusive app are tested with the same program (see Tests).

### Sockets in a window

BSD sockets (`socket`, `bind`, `listen`, `accept`, `connect`, `send*`, `recv*`, `shutdown`, `get/setsockopt`, `getsockname`,
`getpeername`) and name lookups (`getaddrinfo`, `gethostbyname`, `gethostbyaddr`, `getnameinfo`) are served by Nexvyn OS per app:

- the app's `app.json` `"permissions"` must list `"network"` (any letter case). Without it every call fails with `EACCES`
  (a name lookup returns `EAI_FAIL`), and one line `permission denied: network (<call>)` goes to the app's log. The user can
  also switch it off in the install sheet or Settings > Privacy & Security (the stored answer wins over the manifest). A
  package without a `"permissions"` array has no network. The answer is read once when the window starts.
- with it the call goes to libnx's sockets. Nexvyn OS owns the socket service: `socketInitialize()` / `socketExit()` in an
  app are no-ops (`socketInitializeDefault()` succeeds with the permission and fails without), an app never starts or stops it.
- headers: `<sys/socket.h>`, `<netinet/in.h>`, `<netinet/tcp.h>`, `<arpa/inet.h>`, `<netdb.h>`, `<net/if.h>`, `<poll.h>`, `<sys/select.h>`
  come from libnx's include folder (every kit build has it on the include path), `<sys/un.h>` (type only: UNIX-domain sockets
  do not exist, `socket(AF_UNIX, ...)` fails cleanly) and `<ifaddrs.h>` from the kit's `compat/include`. A port needs no
  socket shim: build it with `nexvyn_use_compat()` and add `"network"` to its permissions. `fork`, `execvp` and friends fail
  with `ENOSYS` and one log line (section "What cannot work"), `dlopen` loads `.nxvlib` files (setting `native.windowedLibs`).
- no network on the console (no connection, service missing): Nexvyn OS starts as before and the app's calls fail with libnx's
  `errno`; nothing else is affected.
- `poll`, `select` and `ioctl` work on sockets mixed with pipes and eventfds exactly as above. A blocking `recv`, `accept` or
  `connect` blocks only the app's own thread: Nexvyn OS's main thread makes no socket calls for it.
- the layer notes the sockets the app opens and closes the ones still open when it ends.

### N6 network fixture

`python tests/run_n6_net_probe.py` builds `build/n6-net-probe/n6_net_probe.nxvapp` from an exported SDK kit and checks its
windowed module, declared `network` permission, package integrity and marker format. The fixture uses the compatibility
layer for `ioctl` and `poll`. The native host checks the app's stored permission before forwarding socket and resolver
calls to libnx. The OS owns the socket service.

`PASS_HOST` covers compilation, import validation, packaging and the parser's sample logs. The recorded emulator run reached `N6N-END status=COMPLETE`. The progress log does not record
individual syscall results. Each row needs a retained guest log for a verdict.

| Item | Behavior to check in the app log | Evidence level |
|---|---|---|
| TCP loopback | Bind and listen on `127.0.0.1` with an OS-assigned port. Connect, accept, send and verify one byte. `N6N-TCP stage=done rc=1` means the byte matched. | Console `NOT_RUN` |
| Non-blocking TCP connect | Set `FIONBIO`, connect to the local listener, poll for `POLLOUT`, then read `SO_ERROR`. `N6N-CONNECT stage=ready` requires writable readiness and `so_error=0`. Record whether `connect` completed immediately or reported progress. | Console `NOT_RUN` |
| Poll timeout | Poll the bound, idle UDP socket for `POLLIN` with a 100 ms timeout before sending anything. Expect `N6N-TIMEOUT rc=0 revents=0` and record elapsed monotonic milliseconds. | Console `NOT_RUN` |
| UDP loopback | Bind to `127.0.0.1` with an OS-assigned port. Send a datagram and verify one byte via `recvfrom`. `N6N-UDP stage=done rc=1` means the byte matched. | Console `NOT_RUN` |
| Resolver | Record IPv4 `getaddrinfo` return codes for `localhost` and `example.com` in separate `N6N-DNS` rows. Record public lookup failures as observations, including offline. | Console `NOT_RUN` |
| Broadcast | Record `SO_BROADCAST` and then `sendto` to `255.255.255.255:58466` when the option succeeds. `set_rc=0 send_rc=1` confirms local send acceptance. A LAN listener is required to prove delivery. | Console `NOT_RUN` |
| Multicast | Record `IP_ADD_MEMBERSHIP` return code for `239.255.0.1` on the default interface. `stage=join rc=0` confirms the join call succeeded. This fixture exercises membership only. | Console `NOT_RUN` |
| Socket count | Open UDP sockets until the first error or the cap of 64. Record the count, first allocation error and number of close failures. `opened=64` establishes a lower bound for that run. | Console `NOT_RUN` |
| Completion | `N6N-END status=COMPLETE` means all probes returned and logged. Evaluate each preceding row independently. A return value of `-2` in a syscall field means the call was skipped. | `PASS_EMULATOR` for completion. Console `NOT_RUN`. |

The compatibility layer implements minimal IPv4 interface enumeration through
`getifaddrs` and `freeifaddrs`. The network fixture exercises the socket surface.

#### Reproduce the fixture

1. Build the package and record its SHA-256 and the candidate OS source/artifact identity. Install on an isolated SD
   with the `network` permission allowed. Run once on a connected LAN and once offline on each target. If running
   the emulator, use the shared lock and start minimized without activation. Use a test LAN for the single broadcast packet.
2. Archive the new lines from `System/Logs/Apps/com.nexvyn.test.n6netprobe.log` per launch. Validate each capture with
   `python tests/run_n6_net_probe.py --log <capture>`. Review the row values and record the results separately as
   `PASS_EMULATOR`, `PASS_DEVICE` or `FAIL`, including environment and sample count. Loopback connects use a local
   listener. Resolver calls have a platform-controlled timeout.
3. For the permission control, deny `network` in Settings, reopen the app and retain a separate log. Check the one-time
   permission warning, socket `EACCES` and resolver `EAI_FAIL`. The stored permission is sampled at launch.

## POSIX calls

| Area | Calls | Behaviour |
|---|---|---|
| Memory | `mmap`, `munmap`, `mprotect`, `msync`, `madvise`, `mremap`, `mlock*` | Heap blocks aligned to 4 KiB. Anonymous memory is zeroed. A file mapping is read into the block; `MAP_SHARED` + `PROT_WRITE` writes back at `msync` and `munmap`. Partial `munmap` keeps the block until all pages are released. `MAP_FIXED` works inside a block `mmap` returned earlier. Protections are recorded, not enforced (no guard pages). `PROT_EXEC` fails with `ENOTSUP` and one log line: executable memory needs the JIT service. On a console the SD card file system locks a file that is open for writing. `stat`, `lstat` and `access` of such a file work: the layer remembers the path of every file this process opened for writing (`open`, `fopen`; dropped at `close` / `fclose`) and answers from `fstat` of that descriptor (a descriptor made by `dup`, `fdopen` or `freopen` is not tracked). Still refused by the file system: a second `open` / `fopen` of the same file while the first is open for writing, so do not reopen a file while a `MAP_SHARED` descriptor of it is open; read it through that descriptor. |
| Info | `sysconf`, `getpagesize`, `getrlimit`, `uname`, `getrandom`, `getentropy` | Page size 4096; CPU count from the process core mask (3 for apps); memory pages from the process and the libnx heap. |
| Descriptors of files | `fcntl` on stdio and on files of the SD card / romfs | libnx's `fcntl` fails on them (`ENOTSOCK`, `EBADF`), which stops GLib and others. `F_GETFL` answers (stdin `O_RDONLY`, stdout and stderr `O_WRONLY`, files `O_RDWR`: the kernel keeps no open flags, so the access mode is a guess), `F_SETFL` is accepted and changes nothing (no non-blocking mode on a file), `F_GETFD` / `F_SETFD` answer 0, `F_DUPFD` duplicates. A closed or invalid descriptor is `EBADF`. Sockets still go to libnx; pipes and eventfds keep their own flags. |
| Devices | `/dev/null`, `/dev/zero`, `/dev/random`, `/dev/urandom` | Through `open`, `fopen`, `stat`, `lstat`, `access` (and `fstat`, `read`, `write`, `lseek`, `dup`, `fcntl`, `poll` on the descriptor). `null` swallows writes and reads EOF, `zero` reads zeros, `random` and `urandom` read from the console's random generator and never block; `stat` says character device; `/dev` itself is a folder. Checked before the PC path translation, so `NXC_FS_VROOT` does not move them. Not covered: `freopen` and `opendir("/dev")`. |
| C11 time | `timespec_get(ts, TIME_UTC)` | The wall clock; any other base returns 0. Declared in `nexvyn/compat_posix.h` (newlib has none). |
| Identity | `getpid`, `getppid`, `getuid`..., `umask` | `getpid` is the real process id and never changes; the rest are constants. |
| The one user | `getuid`, `geteuid`, `getgid`, `getegid`, `getpwuid`, `getpwuid_r`, `getpwnam`, `getpwnam_r`, `getlogin` | There is a single user: name `nexvyn`, uid and gid 1000, home `$HOME` or `sdmc:/`, empty shell. Any other uid or name is "not found" (`NULL`, `errno` 0; the `_r` forms return 0 with `*result == NULL`). Fixed, not the console's user. (Kit 1.1, add-only.) |
| Text input | `getline`, `getdelim` | Real, on top of newlib's `__getdelim` (newlib has no public name). Declared in `nexvyn/compat_posix.h` (force-included by `nexvyn_use_compat()`). (Kit 1.1, add-only.) |
| Interfaces | `getifaddrs`, `freeifaddrs` (`<ifaddrs.h>`) | Minimal list (`lo` `127.0.0.1`, plus the primary IPv4 address when available, via `gethostid()` in exclusive mode and the existing libnx `gethostname()` host import in windowed mode); never `ENOSYS`. |
| Timestamps | `utime`, `utimes`, `futimens`, `utimensat` | FAT timestamps are not settable here: documented no-op returning `0` while keeping existing file times when the path or descriptor exists, and failing with `ENOENT` or `EBADF` for missing targets. `utimensat` supports absolute paths and app-relative paths via `AT_FDCWD`; newlib does not expose directory descriptors for relative lookup. |
| Positional & 64-bit I/O | `pread`, `pwrite`, `pread64`, `pwrite64`, `lseek64`, `off64_t` | 64-bit offsets (including > 2 GiB); `pread*` / `pwrite*` save and restore the file offset under an internal lock to preserve the descriptor position. Calls through other I/O APIs on the same open file description require caller synchronization. |
| Directory listing | `readdir` | Ensures `d_type` is filled (`DT_DIR` / `DT_REG` on FAT and romfs, or `DT_UNKNOWN` consistently for unknown entry types). |
| Pipes | `pipe`, `pipe2`, `eventfd`, `eventfd_read/write` | In-process: a 64 KiB ring buffer (pipe) or counter (eventfd) behind a normal descriptor. `read`, `write`, `close`, `dup`, `fstat`, `fcntl(F_GETFL/F_SETFL/F_GETFD/F_SETFD/F_DUPFD)`, `ioctl(FIONBIO/FIONREAD)`. Blocking and non-blocking, EOF, `EPIPE`, atomic writes up to 4096 bytes. |
| Readiness | `poll`, `ppoll`, `select`, `pselect` | Work on pipes, eventfds, sockets and regular files in one set (regular files are always ready). Waits are woken at once when another thread writes; sockets are checked every 2 ms while waiting. `select(0, ...)` and `poll(NULL, 0, ms)` sleep. |
| Environment | `getenv`, `setenv`, `putenv`, `unsetenv`, `clearenv`, `secure_getenv` | newlib's table with argument checks (`EINVAL`) and a `clearenv`. |
| Directory | `getcwd`, `chdir`, `realpath` | Work on `sdmc:/...` paths; `realpath` resolves `.` and `..`, checks the file exists and does not follow links (there are none). With `NXC_FS_VROOT` they show `/` as the app folder. `chdir` keeps `$PWD` true. |
| Time | `clock_gettime`, `clock_getres`, `clock_nanosleep`, `nanosleep`, `sleep`, `usleep`, `sched_yield` | Recognized clock ids are mapped to the real-time/monotonic implementation; unknown ids fail with EINVAL. CPU-time ids report elapsed time since the first call, not CPU usage (the kernel gives no CPU time). Sleeps are interrupted by signals like on a PC. |
| Libraries | `dlopen`, `dlsym`, `dlclose`, `dlerror`, `dladdr` | `dlopen(file)` loads a Nexvyn shared library (`.nxvlib`) through `nxn_lib_open` (section "Shared libraries (dlopen)"). `dlopen(NULL)` and `dlsym(RTLD_DEFAULT, name)` search `nxc_dl_register(name, address)`, then the app's exports and every open library, so ports that probe for optional functions get a clean answer. `dladdr` finds nothing. |

### Anonymous VM-backed mappings

Native SDK 1.3 windowed modules can opt in with `NEXVYN_VM_MMAP=1` before requesting anonymous
private `MAP_NORESERVE` mappings. The physical backend must support page-granular commits and
protection. The route supports unbacked `PROT_NONE` reservations, in-range anonymous
`MAP_FIXED` replacements, `mprotect` and `munmap`. The heap-backed route remains the default.
See [Virtual memory](NATIVE_KIT.md#virtual-memory) for the backend contract. File mappings still
read into a buffer. Positional stream reads are the alternative for large read-only files.

## Coroutines

`<ucontext.h>` has `getcontext`, `setcontext`, `swapcontext`, `makecontext` for AArch64. A context holds `x19`-`x30`, `sp`,
`d8`-`d15`, `fpcr`, `fpsr` (the AAPCS64 callee-saved set) plus `x0`-`x7` for the arguments of `makecontext` (at most 8
`int` arguments). The signal mask is stored but not switched. A swap measured 0.2 microseconds in the emulator (20000 swaps in 4 ms). Resume a context on the
thread that made it; do not let a C++ exception leave the function a context runs.

A small API sits on top:

```c
nxc_coro* c = nxc_coro_create(fn, arg, 0);   // 0 = 64 KiB stack (heap), guard pattern at the low end
while (nxc_coro_resume(c) == 1) { }          // 1 yielded, 0 finished, -1 error (finished, overflow, running)
nxc_coro_yield();                            // inside fn
nxc_coro_destroy(c);
```

Coroutines nest (a coroutine may resume another). `nxc_coro_stack_free()` reports the untouched part of a stack, and a
stack overflow that reaches the guard is detected at the next switch and reported once in the log.

Poll scratch storage is bounded by the call's fixed `nfds` (maximum4096), including
when descriptor classifications change between internal scans. This prevents scratch
underallocation; it does not establish defined ordering for arbitrary concurrent
close/reuse. Coordinate descriptor lifetime with the owner of the wait.

## Signals (emulation)

There is no kernel signal delivery here. A signal is a pending bit; its handler runs at a safe point on a thread that is
inside this layer:

- `raise`, `kill(getpid(), sig)`, `pthread_kill`: the handler runs before the call returns (unless the signal is blocked).
- `alarm`, `ualarm`, `setitimer(ITIMER_REAL)`: a small timer thread only sets the pending bit and wakes waiting threads.
  The handler runs on the thread that armed the timer: inside `sleep`, `poll`, `select`, a pipe or eventfd read, `sigsuspend`,
  `sigwait`, or in `nxc_signal_poll()`. **Call `nxc_signal_poll()` once per frame or loop pass** in a program that does not
  block in those calls.
- `sigaction` (flags `SA_SIGINFO`, `SA_RESTART`, `SA_NODEFER`, `SA_RESETHAND`, handler masks), `signal`, `sigprocmask`,
  `pthread_sigmask`, `sigpending`, `sigsuspend`, `sigwait`.
- A blocking call that is interrupted returns `-1` with `EINTR`; `sleep` returns the seconds left. `read` / `write` on pipes
  restart when the handler has `SA_RESTART`; `poll`, `select` and the sleeps never restart (as on Linux).
- One process-wide signal mask. Standard signals only, coalescing (no queue, no real-time signals).
- The compat header uses unsigned `sigset_t` shifts for mask helpers, including console signal31
  (`SIGUSR2`). Rebuild callers and the app-linked compat library to adopt this correction;
  an OS update alone does not replace macros already compiled into a port.
- A default action of "terminate" ends the app with exit code 128 + signal after one log line; "ignore" signals (`SIGCHLD`,
  `SIGPIPE`, `SIGWINCH`, ...) are dropped. `SIGPIPE` is therefore harmless unless the program installs a handler.
- Hardware data-abort delivery (`SIGSEGV` / `SIGBUS` with `SA_SIGINFO`): see [Hardware faults (`SIGSEGV` / `SIGBUS`)](#hardware-faults-sigsegv--sigbus) below. `SIGILL` and `SIGFPE` handlers (and non-`SA_SIGINFO` `SIGSEGV` / `SIGBUS` handlers) are accepted and never called for hardware faults.
- `sigaltstack` currently returns success without installing an alternate stack. Handlers use the caller's stack.
  Do not use a successful return as proof that stack-overflow recovery or an alternate signal stack exists.

### Hardware faults (`SIGSEGV` / `SIGBUS`)

For Native SDK 1.3 modules that link this compatibility layer, the bridge replaces the
signal-emulation-only fastmem fallback on a protection-capable backend.

In a windowed or Nexvyn full-screen module with `native.windowedFaultHandler` enabled (`NXN_CAP_FAULT_HANDLER`), installing
a `SIGSEGV` or `SIGBUS` handler with `SA_SIGINFO` registers a single `nxn_fault_handler_set` callback (`nxc_fault.c`) that
delivers AArch64 data aborts directly to `sa_sigaction(int sig, siginfo_t* si, void* uctx)` on the faulting thread:

- `siginfo_t` (`<sys/signal.h>`):
  - `si_signo`: `SIGSEGV` or `SIGBUS` (decoded from the AArch64 `ESR_EL1` Data Fault Status Code, bits 5..0).
  - `si_addr`: the faulting data address (`FAR`, `nxn_fault.addr`).
  - `si_code`: `SEGV_ACCERR` for permission faults (DFSC `0x0C`..`0x0F`), `SEGV_MAPERR` for translation / address-size /
    access-flag faults (DFSC `0x00`..`0x0B`) or unknown syndromes, `BUS_ADRALN` for alignment faults (`0x21`), `BUS_ADRERR`
    for synchronous external aborts (`0x10`, `0x11`, `0x14`..`0x17`), and `BUS_OBJERR` for parity / ECC errors (`0x18`,
    `0x1C`..`0x1F`).
  - `si_errno`: `0`.
- `ucontext_t` (`<ucontext.h>` / `<sys/ucontext.h>`):
  - `uc_mcontext.regs[0..30]` (`x0`..`x30`; `regs[29]` is `fp`, `regs[30]` is `lr`), `uc_mcontext.sp`, `uc_mcontext.pc`,
    `uc_mcontext.pstate`, `uc_mcontext.fault_address` (`FAR`), and `uc_mcontext.esr` (the raw AArch64 `ESR_EL1` syndrome).
  - Read vs. write access is exposed via bit 6 of `uc_mcontext.esr` (`NXC_ESR_WNR`, `1` = write, `0` = read) and the
    helper `nxc_fault_is_write(const ucontext_t*)`.
  - When `sa_sigaction` returns, modified `regs[0..30]`, `sp`, `pc` and `pstate` NZCV flags (bits 31..28) are written back
    to `nxn_fault` and execution resumes at `uc_mcontext.pc`.
- Crash pass-through: `SIG_DFL`, `SIG_IGN`, no handler, a handler installed without `SA_SIGINFO`, a signal blocked in
  `sigprocmask`, or an unhandled signal class (e.g. a `SIGBUS` fault when only `SIGSEGV` is handled) returns `0` to the
  host and keeps the normal Nexvyn crash path. When both `SIGSEGV` and `SIGBUS` return to `SIG_DFL` / `SIG_IGN` (or at
  `nxc_shutdown()`), the compat layer removes its `nxn_fault_handler_set` callback.
- `SA_RESETHAND` (`SA_ONESHOT`) clears the slot atomically before invoking the handler, so a subsequent fault takes the
  crash path unless the handler is reinstalled.
- Standalone `.nro` builds and hosts with `native.windowedFaultHandler` off receive `NXN_ERR_UNSUPPORTED` from
  `nxn_fault_handler_set`; `sigaction()` still succeeds and logs one unsupported notice, keeping the normal crash path.

Limits (inherited from `docs/current/n4/N4_FAULT_CONTRACT.md` and `sdk/native/include/nexvyn/nxn_jit.h`):

- **Data aborts only:** instruction aborts, undefined instructions (`SIGILL`), floating-point traps (`SIGFPE`), stack
  overflows, recursive faults inside the handler, and faults inside a Nexvyn OS function or `malloc` always take the
  normal crash path.
- **`x17` (`regs[17]`) is not restored:** the host resume trampoline (`nxw_fault_resume`) uses `x17` to carry the resume
  address. Code that may fault must not hold a live value in `x17` across the faulting access.
- **SIMD / FP state is not editable:** `q0`..`q31` are restored unchanged by the host; `uc_mcontext.d[]`, `fpcr`, and
  `fpsr` are only used by `getcontext` / `setcontext` / `swapcontext` and are neither populated nor written back for
  hardware faults.
- **Handler rules:** the handler runs on the faulting thread's own stack (`sp - 512`, 16-byte aligned) and must be
  reentrant across concurrent faulting threads. It must **not** call `nxn_*` functions (including `nxn_mem_guard` or
  `nxn_log`), must **not** allocate, must **not** take locks (including `sigaction()`), and must **not** block. `sa_mask`
  is not switched around hardware fault handlers.
- **Emulator limit:** the emulator does not enforce page permissions (`docs/current/n6/N6_PROBES.md` row c), so guarded writes
  do not fault in the emulator; hardware fault delivery must be verified on a console. See `sdk/native/examples/fault_demo`.

## Paths (opt-in)

Ports written for PC paths can ask for translation of every file call: `nexvyn_compat_fsmap(target [FLAGS ...])` in CMake,
or add `compat/fsmap_on.c` and `$(NXC_FSMAP_LDFLAGS)` in a Makefile. At run time `nxc_fs_enable(flags)` replaces the set
(0 = off). Flags:

| Flag | Effect |
|---|---|
| `NXC_FS_CASEFOLD` | `open`, `fopen`, `freopen`, `stat`, `lstat`, `access`, `opendir`, `mkdir`, `rmdir`, `unlink`, `remove`, `rename`, `truncate`, `chmod` find a file whose letter case differs. Only tried when the exact name does not exist, so it costs nothing on the SD card (FAT is case-insensitive already); it matters for `romfs:/` and the bundle, which are case-sensitive. A name that exists nowhere is left as given, so creating files keeps your spelling. |
| `NXC_FS_BACKSLASH` | `\` is a separator. |
| `NXC_FS_DRIVES` | `C:` ... `Z:` map to the root folder (or `nxc_fs_map_drive('D', "romfs:/Data")`). |
| `NXC_FS_VROOT` | `/x` means `<root>/x`; `getcwd`, `realpath` show `/...`. Root: `nxc_fs_set_root()`, default the data folder. |

Paths that carry a device (`sdmc:/`, `romfs:/`) are never touched by the drive and root rules. `nxc_fs_translate()` exposes
the translation alone. Set the flags before starting threads.

Lexical normalization preserves unresolved parents in relative paths (`../../assets`
stays `../../assets`); it cancels only an actual preceding directory component.
Absolute/device roots remain clamped (`sdmc:/../../assets` becomes `sdmc:/assets`).
This is string normalization, not symbolic-link resolution or a filesystem sandbox.
The correction is in the app-linked compat library: rebuild/relink a port to adopt it;
updating the OS alone does not replace an already linked archive.

## PC types

`#include <nexvyn/nxc_pc_types.h>` (header only) for decompilation ports: `BOOL`, `BYTE`, `WORD`, `DWORD`, `LONG`, `UINT`,
`QWORD`, opaque `HANDLE` and `INVALID_HANDLE_VALUE`, `MAX_PATH`, `_countof`, `LOBYTE` / `HIWORD` / `MAKEWORD` ..., `ZeroMemory`
..., `stricmp`, `strnicmp`, `_strdup`, `_snprintf`, `strcpy_s`, `Sleep`, `GetTickCount`, `QueryPerformanceCounter`,
`GetLastError`. It is a naming bridge: nothing opens a kernel object. `min` / `max` macros only with `NXC_PC_MINMAX`.

## What cannot work

These fail with `ENOSYS` (or the natural error) and write one log line per call name:

| Call | Result | Usual replacement |
|---|---|---|
| `fork`, `vfork` | `ENOSYS` | A thread, or call the code in-process (single-process mode of the program). |
| `exec*`, `posix_spawn*`, `system(cmd)`, `popen` | `ENOSYS` (`system(NULL)` is `0`: no shell) | Call the function; link the tool as a library. |
| `wait`, `waitpid` | `ECHILD` | Nothing to wait for. |
| `openpty`, `forkpty`, `posix_openpt` | `ENOSYS` | `pipe()` or an in-process buffer. |
| `symlink`, `link` | `ENOSYS` | The SD card is FAT: copy the file or keep a path table. `readlink` is `EINVAL` (nothing is a link). |
| `mkfifo`, `mknod` | `ENOSYS` | `pipe()` inside the process. |
| `kill(other pid, ...)` | `ESRCH` | There is no other process. |
| `chown` and friends | succeed | FAT has no owners. |
| `mmap(PROT_EXEC)`, `mprotect(PROT_EXEC)` | `ENOTSUP` | Use `nxn_jit_*` (`nxn_jit.h`, `NXN_CAP_JIT`): rw + rx views, cache maintenance. |
| `dlopen` of a Linux `.so` | `NULL` with the reason in `dlerror()` | Rebuild the plugin as a `.nxvlib` (`NATIVE_KIT.md`), or link it statically. |

`-DNXC_STRICT=1` (CMake: `nexvyn_use_compat(target STRICT)`) turns calls to the process and link functions into compile-time
warnings that name the replacement; `STRICT_ERROR` (`NXC_STRICT=2`) makes them errors. Use it while porting to find them all.

## Limits

- Fastmem: a real data abort can go to the app first with `nxn_fault_handler_set` (`nxn_jit.h`, setting `native.windowedFaultHandler`, `NXN_CAP_FAULT_HANDLER`) or through POSIX `sigaction` (`SIGSEGV` / `SIGBUS` with `SA_SIGINFO`, see [Hardware faults](#hardware-faults-sigsegv--sigbus)); the handler fixes the registers / `pc` and the thread goes on. Guard pages: `nxn_mem_guard` (`native.windowedGuardPages`). Both are off by default; see `NATIVE_SDK_DESIGN.md` 3.2.11.
- Pipes and eventfds are for threads of one process. There is no `socketpair`, `epoll`, `timerfd`, `signalfd`, `inotify`.
- Memory mappings are heap copies: a huge sparse reservation (a 4 GiB `PROT_NONE` address space) fails with `ENOMEM`, and file
  mappings take the file's size in RAM.
- Signals are cooperative (see above); the emulation does not interrupt code that never enters the layer.
- The layer holds one lock for descriptors and signals. It does no file or socket I/O while holding it, runs signal handlers
  with it released and never calls SDL, GL or user code under it, so it cannot join a lock cycle with them.
- Needs the kit toolchain (devkitA64 15.2, newlib, libnx 4.10).
- In a window: `thread_local`, C++ exceptions and `dlopen` only with their settings (`native.windowedTls`, `native.windowedEh`,
  `native.windowedLibs`, default off), relative paths only through the wrapped file calls, `nxn_thread_join` does not
  deliver signals while it waits, no `romfs:/` (all in the table of the window section).

## Hooks with the native runtime (`libnexvyn_native`)

The runtime library references the layer **weakly**. An app that does not link `libnexvyn_compat` builds and behaves exactly
as before (a weak undefined symbol does not pull the archive in). When both are linked:

In a window the same hooks are made with `--wrap` on the `nxn_*` imports (window section). Exclusive mode:

| Runtime call | Hook |
|---|---|
| `nxn_init` | `nxc_init()` once the sandbox paths are known |
| `nxn_event_poll`, `nxn_should_quit` | `nxc_signal_poll()`, so `alarm()` / `setitimer()` signals are delivered once per frame |
| `nxn_shutdown` | `nxc_shutdown()`: disarms the timers and stops the signal timer thread |
| `nxn_sleep_ns` | `nxc_sleep_interruptible()`: handlers run while sleeping, the sleep still lasts the full time |
| `nxn_thread_join` | waits in 10 ms slices and runs `nxc_signal_poll()` between them (exclusive only) |

`nxc_shutdown()` and `nxc_sleep_interruptible(ns)` (0 after the full time, -1 with `EINTR` when a handler ran) are public in
`nexvyn/compat.h` and also usable without the runtime.

Planned, not in 1.0: `PROT_EXEC` backed by `nxn_jit_*` (today a JIT uses `nxn_jit_*` directly).

## Shared libraries (dlopen)

`dlopen`, `dlsym`, `dlclose` and `dlerror` go to the Native SDK's shared libraries (`nxn_lib_*`, built and shipped as
`.nxvlib`: `NATIVE_KIT.md`, "Shared libraries"), so ports that load plugins work unchanged once the plugin is rebuilt
as a `.nxvlib`.

- Names: a path (`"plugins/foo.so"`, `"sdmc:/x/foo.nxvlib"`), or a bare name (`"libfoo.so"`, `"libfoo.so.2"`) that is
  looked up as `libfoo.nxvlib`, then `foo.nxvlib`, next to the app's `.nro` and in `<data>/lib/`. A path that does not
  exist is also tried with the `.nxvlib` name in the same folder.
- Flags: `RTLD_LAZY`, `RTLD_NOW`, `RTLD_GLOBAL`, `RTLD_LOCAL` and `RTLD_NODELETE` are accepted and change nothing
  (every library is bound at once, its symbols are visible to `dlsym(RTLD_DEFAULT, ...)`, it stays loaded until the
  app ends). `RTLD_NOLOAD` returns a library `dlopen` opened before, `NULL` otherwise.
- `dlsym(handle, name)` returns only the library's own exports; `dlsym(RTLD_DEFAULT, name)` searches the
  `nxc_dl_register` table, the app's exports, then every open library. A handle that is not an open library is refused
  without being read.
- `dlerror()` gives the loader's message ("libfoo.so: not found ...", "foo: missing symbol bar (...)", "foo: version 2.0.0
  is installed, this app needs 1.x", the JIT note in applet mode).
- Linking: the layer references `libnexvyn_native` weakly. With CMake (`NEXVYN_ABI` on) `nexvyn_use_compat` pulls the
  loader in; Makefile projects add `$(NXC_DL_LDFLAGS)` to `LDFLAGS`. Without `libnexvyn_native`, `dlopen` fails with a
  message that says so.
- In a window (setting `native.windowedLibs`): Nexvyn OS serves `nxn_lib_*`, so the same calls work without
  `libnexvyn_native`. The app's folder takes the place of the `.nro`'s folder; a library's imports resolve to the
  module's exports, the libraries opened before, then the host import set; libraries may use `thread_local` and
  exceptions with those settings on (`NATIVE_SDK_DESIGN.md` 3.2.10).

## Tests

| What | How |
|---|---|
| Plain C parts (path rules, ring buffer) | `python sdk/native/compat/tests/host/run_host.py` (gcc, clang or MSVC on the PC) |
| Public headers in C and C++, wrap lists | `python sdk/native/compat/tests/header_check.py` |
| `NXC_STRICT` warnings and errors | `python sdk/native/compat/tests/strict_check.py` |
| Everything else on the console or emulator | `python tools/nxv_native build sdk/native/compat/tests/compat_test` builds the window / full screen module (`--exclusive`: the `.nro`), run it, read `sdmc:/switch/compat_test/results.txt` (a hung test is cut by a watchdog; the `.nro` also exits 0 when all passed). Also builds with `make` (`sdk/native/compat/tests/compat_test/Makefile`, uses `compat.mk`). |
| The same test in the emulator: window, full screen, exclusive | `python sdk/native/compat/tests/window_run.py --mode window\|fullscreen --net allow\|deny` (and `--exclusive <nro>`): follows the one-the emulator lock, starts minimized, puts the SD card back. `--net deny` removes `"network"` from the answers and expects `EACCES` |

The on-device test has about 390 checks (385 in a window: no `romfs:/`; its socket part reports `net=allowed` or `net=denied`): memory maps, pipes (a 1.5 MiB transfer between threads), eventfd, poll and select
(wake-up latency, loopback sockets mixed with pipes), environment, directories, `dl*`, clocks, identity, PC types, the
unsupported calls, `ucontext` (ping-pong, `uc_link`), coroutines (nested, 500 at once, a 500 KiB deep stack, floating-point
registers and `fpcr`, guard check), signals (masks, `SA_SIGINFO`, `sigwait`, `sigsuspend`, alarm interrupting `sleep` and
`poll`), the runtime hooks (`alarm()` delivered while the app only calls `nxn_event_poll()`; `nxn_sleep_ns`) paths (drives, backslashes, case-insensitive `romfs:/`), `fcntl` on files, the `/dev` devices and `timespec_get`.

The link behaviour (plain `nexvyn_use_compat()`, and libraries after the layer on the link line) is tested by
`python sdk/native/compat/tests/link_check.py` (builds `sdk/native/compat/tests/link_test`: `link_test` uses the core with no other helper,
`link_order` reaches the layer only through a library that CMake places behind it).

### Shared mapping descriptor failure

A writable shared file mapping duplicates its descriptor before it is published.
If duplication fails, mmap returns MAP_FAILED with the original descriptor error
(such as EMFILE or ENFILE), releases its backing and leaves the caller descriptor
open. Success must never silently disable writeback. This static-library correction
requires rebuilding linked applications; it does not add enforced page protection.

`pread`/`pwrite` keep the file offset by saving and restoring it under one process-wide lock: positional calls never interleave, but they are serialized across all descriptors (multi-threaded ISO readers see no parallel I/O), and a plain `read`/`write` on the same descriptor from another thread at the same moment is not protected.
