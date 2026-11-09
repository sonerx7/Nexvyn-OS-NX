#!/usr/bin/env python3
"""Clang spike: packs a clang-built .nxvmod as .nxvapp and runs it in the emulator under the current NexvynOS.nro.

  python sdk/native/toolchain/clang/ryu_probe.py NAME [--nro PATH] [--tls] [--autotest]

NAME is build/clangspike/NAME.nxvmod (build_clang.py). The package is installed with the autorun command pkginstall (the
App Market's way), launched, closed and uninstalled again. --tls turns on native.windowedTls (thread_local), exceptions
(native.windowedEh) are always on; both settings go back to their old values. Rules: the shared lock
(tools/ryujinx_lock.py), the emulator minimized without focus, one session under 60 s, only our own PID is killed, the SD card
is put back (settings.json, logs, app, data, autorun.txt). The logs are kept in build/clangspike/run_NAME/.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools"))
import ryujinx_lock  # noqa: E402

APPDATA = os.environ.get("APPDATA", "")
SD = os.path.join(APPDATA, "the emulator", "sdcard", "NexvynOS")
LOGDIR = os.path.join(SD, "System", "Logs")
LOG = os.path.join(LOGDIR, "system.log")
PREV = os.path.join(LOGDIR, "system.prev.log")
SETTINGS = os.path.join(SD, "System", "Config", "settings.json")
DATA = os.path.join(SD, "Users", "RyuPlayer", "Library", "Application Support")
STAGE = os.path.join(SD, "pkgtest")
ICON = os.path.join(REPO, "sdk", "native", "tests", "glprobe", "icon.png")


def text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def ryujinx_exe():
    for c in (os.environ.get("RYUJINX"), os.path.join(APPDATA, "the emulator", "the emulator.exe"),
              "C:/Users/soned/OneDrive/Masa\u00fcst\u00fc/ryujinx/the emulator.exe"):
        if c and os.path.isfile(c):
            return c
    sys.exit("the emulator.exe not found")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--nro", default=os.path.join(REPO, "NexvynOS.nro"))
    ap.add_argument("--tls", action="store_true")
    ap.add_argument("--autotest", action="store_true", help="write the hello_gl autotest file (returns 7 after 3 s)")
    ap.add_argument("--wait", type=int, default=14)
    a = ap.parse_args()
    out = os.path.join(REPO, "build", "clangspike")
    mod = os.path.join(out, a.name + ".nxvmod")
    if not os.path.isfile(mod) or not os.path.isfile(a.nro):
        sys.exit("build the module (build_clang.py all) and give --nro")
    app_id = "com.nexvyn.test.clang." + a.name.replace("_", "")
    bundle = os.path.join(out, "pkg", a.name)
    shutil.rmtree(bundle, ignore_errors=True)
    os.makedirs(bundle)
    shutil.copyfile(mod, os.path.join(bundle, a.name + ".nxvmod"))
    shutil.copyfile(ICON, os.path.join(bundle, "icon.png"))
    manifest = {"id": app_id, "name": "Clang spike " + a.name, "version": "1.0.0", "author": "Nexvyn OS",
                "category": "developer", "runtime": "native", "mode": "windowed", "main": a.name + ".nxvmod",
                "icon": "icon.png", "window": {"width": 640, "height": 400, "resizable": True}, "minNative": "1.0",
                "minSdk": "1.10", "targetSdk": "1.10", "permissions": ["files"]}
    with open(os.path.join(bundle, "app.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
    pkg = os.path.join(out, "pkg", a.name + ".nxvapp")
    subprocess.run([sys.executable, "-I", os.path.join(REPO, "tools", "nxvapp_pack.py"), bundle, "-o", pkg], check=True)
    subprocess.run([sys.executable, "-I", os.path.join(REPO, "tools", "nxvapp_pack.py"), "--verify", pkg], check=True)

    if not ryujinx_lock.acquire("clang_spike", max_wait=1800):
        sys.exit("the emulator busy")
    autorun = os.path.join(SD, "autorun.txt")
    if os.path.exists(autorun) or os.path.exists(STAGE):
        ryujinx_lock.release("clang_spike")
        sys.exit("autorun.txt or pkgtest already on the SD card")
    data_dir = os.path.join(DATA, app_id)
    app_log = os.path.join(LOGDIR, "Apps", app_id + ".log")
    saved = {}
    try:
        for p in (LOG, PREV, app_log, SETTINGS):
            if os.path.isfile(p):
                saved[p] = p + ".clang_spike"
                shutil.copyfile(p, saved[p])
        os.makedirs(STAGE)
        shutil.copyfile(pkg, os.path.join(STAGE, a.name + ".nxvapp"))
        if a.autotest:
            os.makedirs(data_dir, exist_ok=True)
            with open(os.path.join(data_dir, "autotest"), "w") as f:
                f.write("1")
        lines = ["setup en", "wait 2", "unlock", "wait 3", "lang en", "closeall", "wait 1",
                 "set native.windowedEh true", "set native.windowedTls %s" % ("true" if a.tls else "false"),
                 "pkginstall sdmc:/NexvynOS/pkgtest/%s.nxvapp" % a.name, "wait 3", "trust " + app_id,
                 "log probe-begin", "launch " + app_id, "wait %d" % (a.wait - 6), "shot clang_" + a.name, "wait 6",
                 "log probe-end", "closeall", "wait 1",
                 "pkguninstall %s data" % app_id, "wait 2", "log probe-done", "exit"]
        with open(autorun, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines) + "\n")
        open(LOG, "w").close()
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = 7  # SW_SHOWMINNOACTIVE
        t0 = time.time()
        proc = subprocess.Popen([ryujinx_exe(), a.nro], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=si)
        done = False
        while time.time() - t0 < 56 and proc.poll() is None:
            time.sleep(2)
            if "probe-done" in text(LOG):
                done = True
                time.sleep(1)
                break
        subprocess.run(["taskkill", "/F", "/PID", str(proc.pid), "/T"], capture_output=True)  # only our own emulator
        for _ in range(30):
            if not ryujinx_lock.running():
                break
            time.sleep(0.5)
        secs = time.time() - t0
        log, alog = text(LOG), text(app_log)
        probe = text(os.path.join(data_dir, "clang_probe.txt"))
        rd = os.path.join(out, "run_" + a.name)
        os.makedirs(rd, exist_ok=True)
        for fn, t in (("system.log", log), ("app.log", alog), ("clang_probe.txt", probe)):
            with open(os.path.join(rd, fn), "w", encoding="utf-8") as f:
                f.write(t)
        shot = os.path.join(SD, "autoshots", "clang_%s.png" % a.name)
        if os.path.isfile(shot):
            shutil.copyfile(shot, os.path.join(REPO, "qa", "screens", "2026-11-09_clang_%s.png" % a.name))
            os.remove(shot)
        print("session %.1f s, finished=%s; logs in %s" % (secs, done, rd))
        for l in log.splitlines():
            if app_id in l or "probe-" in l or "autorun" in l:
                print("  SYS " + l.strip()[:260])
        for l in alog.splitlines()[:40]:
            print("  APP " + l.strip()[:260])
        if probe:
            print("--- clang_probe.txt\n" + probe)
        return 0
    finally:
        shutil.rmtree(STAGE, ignore_errors=True)
        shutil.rmtree(data_dir, ignore_errors=True)
        try:
            os.remove(autorun)
        except OSError:
            pass
        for p, b in saved.items():
            shutil.copyfile(b, p)
            os.remove(b)
        if app_log not in saved and os.path.isfile(app_log):
            os.remove(app_log)
        ryujinx_lock.release("clang_spike")


if __name__ == "__main__":
    sys.exit(main())
