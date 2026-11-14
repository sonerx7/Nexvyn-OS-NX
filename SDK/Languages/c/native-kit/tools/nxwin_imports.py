"""Host import set of windowed native apps (NATIVE_KIT.md, section 3.2.2).

A windowed app (.nxvmod) runs inside Nexvyn OS's process. Its undefined symbols are resolved against one fixed table
that Nexvyn OS links in: the nxn_* functions, the C library (newlib libc, libm, the POSIX layer of libsysbase) and a
small libnx subset. The table is the windowed ABI: names are only ever added (generation NXW_HOST_GEN in
sdk/native/lib/win/nxwin_support.c and kHostGen in source/runtimes/nxwin_rules.h, kept equal by tools/compat_check.py, is
raised by hand when something incompatible happens, never by this tool).

  python tools/nxwin_imports.py gen      re-reads the toolchain's archives and adds new names to the list
  python tools/nxwin_imports.py table    writes source/runtimes/nxwin_imports.gen.inc from the list
  python tools/nxwin_imports.py check    the list is add-only against git HEAD and the .inc is in sync (exit 1 if not)
  python tools/nxwin_imports.py imports FILE.nxvmod   lists what a module imports that the set does not have

The list lives in sdk/native/toolchain/nxwin_imports.txt (one name per line, '#' comments, sections per source).
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, ".."))
LIST = os.path.join(REPO, "sdk", "native", "toolchain", "nxwin_imports.txt")
INC = os.path.join(REPO, "source", "runtimes", "nxwin_imports.gen.inc")
HEADERS = os.path.join(REPO, "sdk", "native", "include", "nexvyn")
# DEVKITPRO_WIN on Windows (its DEVKITPRO is an msys path), else DEVKITPRO (CI: /opt/devkitpro)
DKP = os.environ.get("DEVKITPRO_WIN") or ("C:/devkitPro" if os.name == "nt" else os.environ.get("DEVKITPRO", "/opt/devkitpro"))
NM = os.path.join(DKP, "devkitA64", "bin", "aarch64-none-elf-nm" + (".exe" if os.name == "nt" else ""))
NEWLIB = os.path.join(DKP, "devkitA64", "aarch64-none-elf", "lib", "pic")  # the multilib Nexvyn OS links (-fPIE)
LIBNX = os.path.join(DKP, "libnx", "lib", "libnx.a")

# newlib internals a module never needs (startup / teardown of the process, allocator and stdio state, syscall glue)
DENY_PREFIX = ("_dummy_", "__malloc_", "__atexit", "__libc_", "__syscall", "__libnx", "_init", "_fini", "__mprec_",
               "__sglue", "__stdio_exit_handler", "_PathLocale", "__global_locale", "__default_locale", "_impure_data",
               "__sf", "__sinit", "__fp_lock", "__fp_unlock", "_global_impure_ptr", "__lock_", "__retarget_lock")
DENY = {"__syscalls", "environ", "__env", "fork", "_fork_r", "execve", "_execve_r", "vfork", "__env_lock", "__env_unlock",
        "__tz_lock", "__tz_unlock", "__sfp_lock_acquire", "__sfp_lock_release", "__sinit_lock_acquire",
        "__sinit_lock_release", "_kill", "_kill_r", "kill", "_getpid", "_getpid_r", "_sbrk", "_sbrk_r", "sbrk",
        "__cxa_finalize", "__register_exitproc", "__call_exitprocs", "_exit", "__stack_chk_init"}
# kept although they start with an underscore: newlib's headers and GCC reference them from app code
KEEP = {"_exit"}

# the libnx subset (threads, synchronisation, time, random); nothing that changes the process or maps memory
LIBNX_NAMES = """
threadCreate threadStart threadWaitForExit threadClose threadExit threadPause threadResume threadGetSelf
threadGetCurHandle threadTlsAlloc threadTlsFree threadTlsGet threadTlsSet
mutexLock mutexTryLock mutexUnlock mutexIsLockedByCurrentThread rmutexLock rmutexTryLock rmutexUnlock
condvarWaitTimeout barrierInit barrierWait semaphoreInit semaphoreSignal semaphoreTryWait semaphoreWait
rwlockInit rwlockReadLock rwlockReadUnlock rwlockTryReadLock rwlockTryWriteLock rwlockWriteLock rwlockWriteUnlock
rwlockIsOwnedByCurrentThread rwlockIsWriteLockHeldByCurrentThread
leventClear leventSignal leventTryWait leventWait ueventCreate ueventClear ueventSignal
svcSleepThread svcGetSystemTick svcGetInfo svcGetThreadId svcGetThreadPriority svcSetThreadPriority
svcGetCurrentProcessorNumber svcOutputDebugString svcSignalProcessWideKey svcWaitProcessWideKeyAtomic
svcArbitrateLock svcArbitrateUnlock svcWaitForAddress svcSignalToAddress svcExitThread
randomGet randomGet64 armDCacheFlush armDCacheClean armDCacheZero armICacheInvalidate
""".split()

# W1b (POSIX layer in a window): the libnx functions the compat layer's wrapped calls and its signal / process-id code
# need. poll / ioctl are libnx's socket-descriptor versions (the layer answers files and pipes itself and passes
# sockets on); __aarch64_read_tp is what -mtp=soft code calls to read the thread pointer; the rest is name handling
# without a network request.
LIBNX_COMPAT_NAMES = """
poll ioctl svcGetProcessId __aarch64_read_tp
inet_addr inet_aton inet_ntoa inet_ntop inet_pton gethostname gai_strerror freeaddrinfo hstrerror
""".split()

# BSD sockets: served per app by source/runtimes/nxwin_net.cpp, which answers EACCES unless the app's
# app.json "permissions" has "network" (socketInitialize / socketExit are no-ops there: Nexvyn OS holds the sockets).
NET_NAMES = """
socket accept bind connect listen recv recvfrom recvmsg send sendto sendmsg shutdown getsockopt setsockopt
getsockname getpeername getaddrinfo gethostbyname gethostbyaddr getnameinfo socketInitialize socketExit
""".split()

# names Nexvyn OS serves with its own per-app version (source/runtimes/nxwin_api.cpp); they are in the list like any
# other name, but the generated table does not reference the C library's copy
OVERRIDES = {"eglGetProcAddress", "exit", "_exit", "_Exit", "quick_exit", "abort", "__assert_func", "__assert", "__stack_chk_fail",
             "atexit", "__cxa_atexit", "at_quick_exit", "chdir", "raise", "__chk_fail"} | set(NET_NAMES)


# Archive members that cannot be linked into Nexvyn OS: a member is bad when it needs a symbol no archive of the link
# defines (newlib leaves regcomp, sigprocmask, csqrtl... out for this target), or needs a bad member. None of the names
# a bad member defines goes into the list (computed, so a new toolchain is checked the same way).
_GRAPH = None


def _members(archive):
    out = subprocess.run([NM, "-A", archive], capture_output=True, text=True).stdout
    members = {}
    for line in out.splitlines():
        m = re.match(r"^(.*?):([^:]+\.o):(.*)$", line)
        if not m:
            continue
        parts = m.group(3).split()
        if len(parts) == 2:
            typ, name = parts
        elif len(parts) == 3:
            typ, name = parts[1], parts[2]
        else:
            continue
        key = os.path.basename(archive) + ":" + m.group(2)
        d = members.setdefault(key, {"def": set(), "undef": set()})
        if typ == "U":
            d["undef"].add(name)
        elif typ in "TDBRWVCi":
            d["def"].add(name)
    return members


def graph():
    global _GRAPH
    if _GRAPH is not None:
        return _GRAPH
    gcc = os.path.join(DKP, "devkitA64", "lib", "gcc", "aarch64-none-elf")
    libgcc = []
    if os.path.isdir(gcc):
        for v in sorted(os.listdir(gcc)):
            pth = os.path.join(gcc, v, "pic", "libgcc.a")
            if os.path.isfile(pth):
                libgcc = [pth]
    members = {}
    for a in [os.path.join(NEWLIB, n) for n in ("libc.a", "libm.a", "libsysbase.a")] + [LIBNX] + libgcc:
        members.update(_members(a))
    # symbols the link itself provides (linker script, crt0, the program's main)
    definer = {n: "" for n in ("_DYNAMIC", "__argdata__", "__bss_end__", "__bss_start__", "__data_start",
                               "__eh_frame_hdr_end", "__eh_frame_hdr_start", "__end__", "__got_end__", "__got_start__",
                               "__relro_start", "__tdata_lma", "__tdata_lma_end", "__tls_align", "__tls_end",
                               "__tls_start", "_init", "_fini", "main")}
    for k, d in members.items():
        for n in d["def"]:
            definer.setdefault(n, k)
    bad = {k for k, d in members.items() if any(u not in definer for u in d["undef"])}
    changed = True
    while changed:
        changed = False
        for k, d in members.items():
            if k not in bad and any(definer.get(u) in bad for u in d["undef"]):
                bad.add(k)
                changed = True
    _GRAPH = (members, bad)
    return _GRAPH


def nm_defined(archive):
    members, bad = graph()
    prefix = os.path.basename(archive) + ":"
    names = set()
    for k, d in members.items():
        if k.startswith(prefix) and k not in bad:
            names |= d["def"]
    return names


def nm_undefined(path):
    out = subprocess.run([NM, "-D", "--undefined-only", path], capture_output=True, text=True).stdout
    return sorted({l.split()[-1] for l in out.splitlines() if l.strip().startswith("U ") or " U " in l})


def nxn_names():
    names = set()
    for fn in sorted(os.listdir(HEADERS)):
        if fn.endswith(".h"):
            with open(os.path.join(HEADERS, fn), encoding="utf-8") as f:
                for m in re.finditer(r"NXN_API\s+[^;(]*?\b(nxn_[a-z0-9_]+)\s*\(", f.read()):
                    names.add(m.group(1))
    return names


def wanted(name):
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        return False
    if name in KEEP:
        return True
    if name in DENY or name.startswith(DENY_PREFIX):
        return False
    return True


def read_list():
    sections, cur = {}, None
    if not os.path.isfile(LIST):
        return sections
    with open(LIST, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line.startswith("## "):
                cur = line[3:].strip()
                sections.setdefault(cur, [])
            elif line and not line.startswith("#") and cur:
                sections[cur].append(line)
    return sections


def all_names(sections):
    return {n for v in sections.values() for n in v}


def cmd_gen():
    sections = read_list()
    have = all_names(sections)
    fresh = {
        "nxn": nxn_names(),
        # GL loaders (glad's gladLoadGL) ask EGL: answered with the app's GL entry points (nxn_display_proc)
        "host": {"eglGetProcAddress"},
        "libc": {n for n in nm_defined(os.path.join(NEWLIB, "libc.a")) if wanted(n)} | (OVERRIDES & {"_exit"}),
        "libm": {n for n in nm_defined(os.path.join(NEWLIB, "libm.a")) if wanted(n)},
        "libsysbase": {n for n in nm_defined(os.path.join(NEWLIB, "libsysbase.a")) if wanted(n)},
        "libnx": set(LIBNX_NAMES) & nm_defined(LIBNX),
        # appended last on purpose: new sections go at the end of the list, so two jobs adding names do not collide
        "compat": set(LIBNX_COMPAT_NAMES) & nm_defined(LIBNX),
        "net": set(NET_NAMES) & nm_defined(LIBNX),
    }
    added = 0
    for sec, names in fresh.items():
        cur = sections.setdefault(sec, [])
        for n in sorted(names):
            if n not in have:
                cur.append(n)
                have.add(n)
                added += 1
    write_list(sections)
    print("nxwin_imports: %d names (%d new)" % (len(have), added))


def write_list(sections):
    lines = ["# Host import set of windowed native apps, generation 1 (NATIVE_KIT.md 3.2.2).",
             "# ADD-ONLY: a name is never removed (modules built against it would stop loading). Edit with",
             "# `python tools/nxwin_imports.py gen` (adds what the toolchain has), then `table`.", ""]
    for sec in ("nxn", "host", "libc", "libm", "libsysbase", "libnx", "compat", "net") + tuple(
            k for k in sections if k not in ("nxn", "host", "libc", "libm", "libsysbase", "libnx", "compat", "net")):
        names = sections.get(sec, [])
        lines.append("## " + sec)
        lines += sorted(set(names))
        lines.append("")
    with open(LIST, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def table_text(sections):
    out = ["// generated by tools/nxwin_imports.py table from sdk/native/toolchain/nxwin_imports.txt - do not edit.",
           "// NXW_IMPORT(name): a C library / libnx symbol a windowed app may import (served at its real address);",
           "// nxn_* names and the per-app overrides are served by source/runtimes/nxwin_api.cpp instead."]
    names = set()
    for sec in ("libc", "libm", "libsysbase", "libnx", "compat", "net"):
        names |= set(sections.get(sec, []))
    for n in sorted(names - OVERRIDES):  # one sorted table: the host looks names up by binary search (strcmp order)
        out.append("NXW_IMPORT(%s)" % n)
    return "\n".join(out) + "\n"


def cmd_table():
    with open(INC, "w", encoding="utf-8", newline="\n") as f:
        f.write(table_text(read_list()))
    print("wrote " + os.path.relpath(INC, REPO))


def cmd_check():
    ok = True
    sections = read_list()
    try:
        old = subprocess.run(["git", "-C", REPO, "show", "HEAD:sdk/native/toolchain/nxwin_imports.txt"],
                             capture_output=True, text=True, check=True).stdout
        old_names = {l.strip() for l in old.splitlines() if l.strip() and not l.startswith("#")}
        gone = sorted(old_names - all_names(sections))
        if gone:
            ok = False
            print("FAIL nxwin_imports: removed names (the list is add-only): " + ", ".join(gone[:20]))
    except subprocess.CalledProcessError:
        pass  # not committed yet
    if os.path.isfile(INC):
        with open(INC, encoding="utf-8") as f:
            if f.read() != table_text(sections):
                ok = False
                print("FAIL nxwin_imports: %s is out of date (run: python tools/nxwin_imports.py table)" %
                      os.path.relpath(INC, REPO))
    missing = sorted(nxn_names() - set(sections.get("nxn", [])))
    if missing:
        ok = False
        print("FAIL nxwin_imports: nxn functions not in the list: " + ", ".join(missing))
    print("nxwin_imports: %s (%d names)" % ("ok" if ok else "FAILED", len(all_names(sections))))
    return 0 if ok else 1


def cmd_imports(path):
    have = all_names(read_list())
    bad = [n for n in nm_undefined(path) if n not in have]
    for n in bad:
        print("not in the host import set: " + n)
    print("%s: %s" % (os.path.basename(path), "ok" if not bad else "%d missing" % len(bad)))
    return 1 if bad else 0


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("gen", "table", "check", "imports"):
        print(__doc__)
        return 2
    c = sys.argv[1]
    if c == "gen":
        cmd_gen()
    elif c == "table":
        cmd_table()
    elif c == "check":
        return cmd_check()
    else:
        return cmd_imports(sys.argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
