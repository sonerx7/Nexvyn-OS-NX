#!/usr/bin/env python3
"""nxvtest: run a Nexvyn OS app in an emulator and check it automatically.

    python nxvtest.py init   [--emulator-exe PATH] [--os-nro PATH|latest] [--work DIR] [--app PATH]
    python nxvtest.py setup  [--fresh]
    python nxvtest.py run    scenario.json [--keep]
    python nxvtest.py report [result.json | run folder]

setup prepares an isolated emulator data folder with an empty SD card, installs the OS and your app.
run executes one scenario (autorun script), collects logs and screenshots, prints PASS/FAIL and writes result.json.
Exit code: 0 = PASS, 1 = FAIL, 2 = usage or setup problem.  Python 3.9+, standard library only.
The emulator is a program you supply (it must already run homebrew); this tool never ships or configures one.
"""
import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
import urllib.request
import zlib

VERSION = "1.0"
RELEASE_API = "https://api.github.com/repos/sonerx7/Nexvyn-OS-NX/releases/latest"
DEFAULT_CONFIG = "nxvtest.json"
# One autorun line per step; the boot lines run the first-start assistant with defaults and clear the desktop.
BOOT = ["setup en", "wait 2", "unlock", "wait 4", "closeall", "wait 1"]
DEFAULT_EMU_ARGS = ["-r", "{data}", "{nro}"]
APP_ERROR = [r"(?i)\btraceback\b", r"(?i)\battempt to\b", r"(?i)\bunhandled\b", r"(?i)\bexception\b", r"(?i)\berror\b"]
NOT_RESPONDING = r"(?i)not responding"
CRASHED = r"(?i)\bcrash(ed)?\b|\bfatal\b|\bpanic\b"


class Fail(Exception):
    """A user-facing problem (message printed, exit code 2)."""


def die(msg):
    print("nxvtest: " + msg, file=sys.stderr)
    sys.exit(2)


def read_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except OSError as e:
        raise Fail("cannot read %s %s: %s" % (what, path, e.strerror or e))
    except ValueError as e:
        raise Fail("%s %s is not valid JSON: %s" % (what, path, e))


def read_text(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


# ------------------------------------------------------------------ config
class Config:
    def __init__(self, path):
        self.path = os.path.abspath(path)
        if not os.path.isfile(self.path):
            raise Fail("no config %s: run `python nxvtest.py init` first (or pass --config)" % path)
        self.raw = read_json(self.path, "config")
        self.base = os.path.dirname(self.path)

    def p(self, key, default=""):
        v = self.raw.get(key, default)
        return os.path.normpath(os.path.join(self.base, v)) if v else ""

    @property
    def work(self):
        return self.p("work_dir", "nxvtest-work")

    @property
    def data(self):
        return os.path.join(self.work, "data")

    @property
    def sd(self):
        return os.path.join(self.data, "sdcard", "NexvynOS")

    @property
    def apps(self):
        a = self.raw.get("apps") or ([self.raw["app"]] if self.raw.get("app") else [])
        return [os.path.normpath(os.path.join(self.base, x)) for x in a]


def cmd_init(a):
    path = os.path.abspath(a.config)
    if os.path.exists(path) and not a.force:
        raise Fail("%s exists (use --force to overwrite)" % a.config)
    cfg = {
        "emulator_exe": a.emulator_exe or "C:/path/to/emulator.exe",
        "emulator_args": DEFAULT_EMU_ARGS,
        "emulator_data_template": "",
        "os_nro": a.os_nro or "latest",
        "work_dir": a.work or "nxvtest-work",
        "apps": [a.app] if a.app else [],
        "_help": "emulator_args: {data} = the isolated data folder, {nro} = the OS file on its SD card. "
                 "emulator_data_template: an existing emulator data folder to copy keys and firmware from "
                 "(default: a 'portable' folder next to emulator_exe).",
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    print("wrote %s\nnext: edit emulator_exe (an emulator that already runs homebrew), then `python nxvtest.py setup`" % path)
    return 0


# ------------------------------------------------------------------ setup
def fetch_latest_nro(dest):
    print("looking up the latest release ...")
    try:
        req = urllib.request.Request(RELEASE_API, headers={"User-Agent": "nxvtest", "Accept": "application/vnd.github+json"})
        with urllib.request.urlopen(req, timeout=30) as r:
            rel = json.load(r)
        asset = next(x for x in rel.get("assets", []) if x["name"].lower() == "nexvynos.nro")
        print("downloading %s (%s)" % (asset["name"], rel.get("tag_name", "?")))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with urllib.request.urlopen(asset["browser_download_url"], timeout=120) as r, open(dest + ".part", "wb") as f:
            shutil.copyfileobj(r, f)
        os.replace(dest + ".part", dest)
    except (OSError, StopIteration, ValueError, KeyError) as e:
        raise Fail("could not download the latest release (%s); set os_nro to a local NexvynOS.nro instead" % e)


def app_from(src, tmp):
    """Returns (bundle path to copy, destination name, app id). A lone .lua/.js/.py file gets a generated app.json."""
    src = os.path.abspath(src)
    if not os.path.exists(src):
        raise Fail("app not found: %s" % src)
    ext = os.path.splitext(src)[1].lower()
    name = os.path.basename(src.rstrip("/\\"))
    if os.path.isdir(src):
        m = read_json(os.path.join(src, "app.json"), "app.json") if os.path.isfile(os.path.join(src, "app.json")) else None
        if m is None:
            raise Fail("%s has no app.json (give the app folder, or a single .lua/.js/.py file)" % src)
        return src, name if name.lower().endswith(".nxvapp") else name + ".nxvapp", m.get("id", name)
    if ext in (".nxvapp", ".nxvmod"):
        ident = os.path.splitext(name)[0]
        if ext == ".nxvapp":
            try:
                import zipfile
                with zipfile.ZipFile(src) as z:
                    ident = json.loads(z.read("app.json").decode("utf-8")).get("id", ident)
            except Exception:
                pass
        return src, name, ident
    if ext in (".lua", ".js", ".py"):
        ident = re.sub(r"[^a-z0-9.-]", "-", os.path.splitext(name)[0].lower())
        bundle = os.path.join(tmp, ident + ".nxvapp")
        os.makedirs(bundle, exist_ok=True)
        shutil.copyfile(src, os.path.join(bundle, "main" + ext))
        with open(os.path.join(bundle, "app.json"), "w", encoding="utf-8") as f:
            json.dump({"id": ident, "name": {"en": ident}, "version": "1.0", "main": "main" + ext,
                       "window": {"width": 560, "height": 420}, "minSdk": "1.0", "permissions": []}, f, indent=2)
        return bundle, ident + ".nxvapp", ident
    raise Fail("unsupported app %s (folder with app.json, .nxvapp, .nxvmod, .lua, .js or .py)" % src)


def cmd_setup(a):
    cfg = Config(a.config)
    exe = cfg.p("emulator_exe")
    if not exe or not os.path.isfile(exe):
        raise Fail("emulator_exe not found: %s (edit %s)" % (cfg.raw.get("emulator_exe"), cfg.path))
    os.makedirs(cfg.work, exist_ok=True)
    nro_cfg = cfg.raw.get("os_nro", "latest")
    if nro_cfg == "latest":
        nro = os.path.join(cfg.work, "download", "NexvynOS.nro")
        if a.fresh or not os.path.isfile(nro):
            fetch_latest_nro(nro)
    else:
        nro = cfg.p("os_nro")
        if not os.path.isfile(nro):
            raise Fail("os_nro not found: %s" % nro)
    # Emulator data: keys and firmware come from a template folder, copied once; the SD card is rebuilt on every setup.
    if a.fresh and os.path.isdir(cfg.data):
        shutil.rmtree(cfg.data)
    if not os.path.isdir(os.path.join(cfg.data, "system")):
        tpl = cfg.p("emulator_data_template") or os.path.join(os.path.dirname(exe), "portable")
        if not os.path.isdir(tpl):
            raise Fail("no emulator data to copy keys and firmware from: set emulator_data_template to the data folder "
                       "of an emulator installation that already runs homebrew")
        print("copying emulator data from %s (once) ..." % tpl)
        skip = {"sdcard", "logs", "games", "mods", "profiles"}
        os.makedirs(cfg.data, exist_ok=True)
        for entry in os.listdir(tpl):
            if entry.lower() in skip:
                continue
            s, d = os.path.join(tpl, entry), os.path.join(cfg.data, entry)
            shutil.copytree(s, d) if os.path.isdir(s) else shutil.copyfile(s, d)
    sdroot = os.path.join(cfg.data, "sdcard")
    shutil.rmtree(sdroot, ignore_errors=True)
    os.makedirs(os.path.join(sdroot, "switch"))
    os.makedirs(os.path.join(cfg.sd, "Applications"))
    shutil.copyfile(nro, os.path.join(sdroot, "switch", "NexvynOS.nro"))
    ids = []
    tmp = os.path.join(cfg.work, "tmp")
    shutil.rmtree(tmp, ignore_errors=True)
    for app in cfg.apps:
        bundle, dest, ident = app_from(app, tmp)
        d = os.path.join(cfg.sd, "Applications", dest)
        shutil.copytree(bundle, d, ignore=shutil.ignore_patterns("__pycache__", ".*")) if os.path.isdir(bundle) else shutil.copyfile(bundle, d)
        ids.append(ident)
        print("installed %s (id %s)" % (dest, ident))
    shutil.rmtree(tmp, ignore_errors=True)
    with open(os.path.join(cfg.work, "state.json"), "w", encoding="utf-8") as f:
        json.dump({"apps": ids, "nro": os.path.join(sdroot, "switch", "NexvynOS.nro")}, f)
    print("setup done: %s\nnext: python nxvtest.py run scenario.json" % cfg.data)
    return 0


# ------------------------------------------------------------------ scenario -> autorun
def safe(name):
    return re.sub(r"[^A-Za-z0-9_-]", "_", str(name))[:60] or "shot"


def num(v):
    return ("%g" % float(v))


ACTIONS = {  # step key -> autorun line builder
    "wait": lambda v: "wait " + num(v),
    "screenshot": lambda v: "shot " + safe(v),
    "click": lambda v: "click %s %s" % (num(v[0]), num(v[1])),
    "rclick": lambda v: "rclick %s %s" % (num(v[0]), num(v[1])),
    "move": lambda v: "move %s %s" % (num(v[0]), num(v[1])),
    "wclick": lambda v: "wclick %s %s" % (num(v[0]), num(v[1])),
    "finger": lambda v: "finger %s %s %s %s" % (v[0], v[1], num(v[2]), num(v[3])),
    "key": lambda v: "key " + str(v),
    "hold": lambda v: "hold %s %s" % (v[0], num(v[1])),
    "pad": lambda v: "dpad " + str(v),
    "padhold": lambda v: "padhold %s %s" % (v[0], num(v[1])) if isinstance(v, list) else "padhold " + str(v),
    "text": lambda v: "text " + str(v).replace("\n", " "),
    "close": lambda v: "close",
    "closeall": lambda v: "closeall",
    "log": lambda v: "log " + str(v).replace("\n", " "),
    "stats": lambda v: "stats " + str(v),
    "raw": lambda v: str(v),
}
EXPECTS = ("expect_log", "expect_no_log", "expect_no_crash", "expect_screenshot", "expect_screenshots_differ",
           "max_not_responding", "expect_closed")


def build_script(sc, app_ids, token):
    lines = list(sc.get("boot", BOOT))
    lines.append("log nxvtest-begin-" + token)
    for i, st in enumerate(sc["steps"]):
        keys = [k for k in st if k in ACTIONS or k == "launch" or k in EXPECTS]
        if len(keys) != 1:
            raise Fail("step %d must have exactly one action, got %s: %s" % (i + 1, keys, json.dumps(st)))
        k = keys[0]
        if k in EXPECTS:
            continue
        v = st[k]
        if k == "launch":
            ident = app_ids[0] if v is True and app_ids else v
            if not isinstance(ident, str) or not ident:
                raise Fail("step %d: launch needs an app id (or true for the first installed app)" % (i + 1))
            lines.append("launch " + ident)
        else:
            try:
                lines.append(ACTIONS[k](v))
            except (IndexError, TypeError, ValueError):
                raise Fail("step %d: bad value for %s: %r" % (i + 1, k, v))
        lines.append("log nxvtest-step-%d-%s" % (i + 1, k))
    lines += ["log nxvtest-end-" + token, "exit"]
    return lines


# ------------------------------------------------------------------ PNG (pure python)
def png_stats(path):
    """Decodes an 8-bit PNG and returns dict(width, height, colors, mean, nonblack, pixels(sampled bytes)); None if unreadable."""
    try:
        with open(path, "rb") as f:
            data = f.read()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            return None
        pos, idat, plte = 8, [], b""
        while pos < len(data):
            n, typ = struct.unpack(">I4s", data[pos:pos + 8])
            body = data[pos + 8:pos + 8 + n]
            pos += 12 + n
            if typ == b"IHDR":
                w, h, depth, ctype, _c, _f, inter = struct.unpack(">IIBBBBB", body)
            elif typ == b"PLTE":
                plte = body
            elif typ == b"IDAT":
                idat.append(body)
        if depth != 8 or inter or ctype not in (0, 2, 3, 4, 6):
            return {"width": w, "height": h, "unsupported": True}
        bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
        raw = zlib.decompress(b"".join(idat))
        stride = w * bpp
        prev = bytearray(stride)
        step = max(1, h // 270)  # every row is unfiltered (filters depend on the row above); only some rows are measured
        samples, off = [], 0
        for y in range(h):
            ft = raw[off]
            row = bytearray(raw[off + 1:off + 1 + stride])
            off += 1 + stride
            if ft == 1:
                for i in range(bpp, stride):
                    row[i] = (row[i] + row[i - bpp]) & 255
            elif ft == 2:
                for i in range(stride):
                    row[i] = (row[i] + prev[i]) & 255
            elif ft == 3:
                for i in range(stride):
                    row[i] = (row[i] + (((row[i - bpp] if i >= bpp else 0) + prev[i]) >> 1)) & 255
            elif ft == 4:
                for i in range(stride):
                    a = row[i - bpp] if i >= bpp else 0
                    b = prev[i]
                    c = prev[i - bpp] if i >= bpp else 0
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    row[i] = (row[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            prev = row
            if y % step == 0:
                samples.append(bytes(row))
        colors, total, lum, nonblack = set(), 0, 0, 0
        for row in samples:
            for x in range(0, w, 3):
                px = row[x * bpp:(x + 1) * bpp]
                if ctype == 3:
                    i = px[0] * 3
                    px = plte[i:i + 3]
                rgb = px[:3] if ctype in (2, 3, 6) else px[:1] * 3
                l = (rgb[0] * 299 + rgb[1] * 587 + rgb[2] * 114) // 1000
                colors.add((rgb[0] >> 2, rgb[1] >> 2, rgb[2] >> 2))
                total += 1
                lum += l
                nonblack += l > 12
        return {"width": w, "height": h, "colors": len(colors), "mean": round(lum / max(total, 1), 1),
                "nonblack": round(nonblack / max(total, 1), 4), "grid": [r[::bpp * 2] for r in samples]}
    except (OSError, struct.error, zlib.error, KeyError, IndexError, UnboundLocalError):
        return None


def png_differs(a, b):
    """Fraction of sampled bytes that differ between two png_stats() results (None when sizes differ)."""
    if not a or not b or "grid" not in a or "grid" not in b or (a["width"], a["height"]) != (b["width"], b["height"]):
        return None
    diff = tot = 0
    for ra, rb in zip(a["grid"], b["grid"]):
        for x, y in zip(ra, rb):
            tot += 1
            diff += abs(x - y) > 8
    return diff / max(tot, 1)


# ------------------------------------------------------------------ run
def start_emulator(exe, args):
    kw = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = 7  # SW_SHOWMINNOACTIVE: minimized, never takes the focus
        kw["startupinfo"] = si
    return subprocess.Popen([exe] + args, **kw)


def stop_emulator(proc):
    if proc.poll() is None:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/PID", str(proc.pid), "/T"], capture_output=True)
        else:
            proc.kill()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass


def lines_after(text, token):
    i = text.find("nxvtest-begin-" + token)
    return text[i:].splitlines() if i >= 0 else text.splitlines()


def check(name, ok, detail=""):
    return {"check": name, "ok": bool(ok), "detail": detail}


def evaluate(sc, ctx):
    """Runs every expect_* step against the collected data; returns a list of check results."""
    res = []
    syslog, applog, shots = ctx["system_log"], ctx["app_log"], ctx["shots"]
    res.append(check("run_completed", ctx["completed"], "" if ctx["completed"] else ctx["incomplete_reason"]))
    nr = [l for l in syslog if re.search(NOT_RESPONDING, l)]
    ctx["not_responding"] = nr
    ctx["crash_files"] = ctx["crash_files"]
    crashed = [l for l in syslog if re.search(CRASHED, l) and (not ctx["app_ids"] or any(i in l for i in ctx["app_ids"]))]
    ctx["crash_lines"] = crashed
    implicit_crash = bool(ctx["crash_files"] or crashed or ctx["emulator_died"])
    max_nr = sc.get("max_not_responding", 0)
    for st in sc["steps"]:
        for k in EXPECTS:
            if k not in st:
                continue
            v = st[k]
            if k in ("expect_log", "expect_no_log"):
                o = {"pattern": v} if isinstance(v, str) else dict(v)
                absent = k == "expect_no_log" or o.get("absent", False)
                src = o.get("source", "app")
                pool = {"app": applog, "system": syslog}.get(src, applog + syslog)
                try:
                    hit = [l for l in pool if re.search(o["pattern"], l)]
                except (re.error, KeyError) as e:
                    res.append(check(k, False, "bad pattern: %s" % e))
                    continue
                label = "%s %s /%s/ (%s log)" % (k, "absent" if absent else "present", o["pattern"], src)
                res.append(check(label, (not hit) if absent else bool(hit), hit[0].strip()[:160] if hit else "no matching line"))
            elif k == "expect_no_crash":
                res.append(check("expect_no_crash", not implicit_crash,
                                 "; ".join(ctx["crash_files"][:3] + [l.strip()[:120] for l in crashed[:3]]
                                           + (["emulator exited early"] if ctx["emulator_died"] else [])) or "no crash"))
            elif k == "max_not_responding":
                max_nr = v
            elif k == "expect_closed":
                closed = any(re.search(r"\bclosed\b", l) and any(i in l for i in ctx["app_ids"]) for l in syslog)
                res.append(check("expect_closed", closed, "the OS logged the app window as closed" if closed else "no '<app id> closed' line in system.log"))
            elif k == "expect_screenshot":
                o = {"name": v} if isinstance(v, str) else dict(v)
                p = shots.get(safe(o.get("name", "")))
                if not p:
                    res.append(check("screenshot %s exists" % o.get("name"), False, "file not written"))
                    continue
                s = png_stats(p)
                res.append(check("screenshot %s exists" % o["name"], bool(s), "%dx%d" % (s["width"], s["height"]) if s else "unreadable PNG"))
                if not s or s.get("unsupported"):
                    continue
                ms = o.get("min_size")
                if ms:
                    res.append(check("screenshot %s min_size %s" % (o["name"], ms), s["width"] >= ms[0] and s["height"] >= ms[1], "%dx%d" % (s["width"], s["height"])))
                if o.get("not_blank", True):
                    res.append(check("screenshot %s not blank" % o["name"], s["colors"] > 8, "%d sampled colors" % s["colors"]))
                if o.get("not_black", True):
                    res.append(check("screenshot %s not all black" % o["name"], s["nonblack"] > 0.02, "%.1f%% lit pixels, mean %s" % (s["nonblack"] * 100, s["mean"])))
            elif k == "expect_screenshots_differ":
                a, b = [png_stats(shots.get(safe(n), "")) for n in v[:2]]
                d = png_differs(a, b)
                res.append(check("screenshots %s and %s differ" % (v[0], v[1]), d is not None and d > 0.0003,
                                 "n/a (missing or different sizes)" if d is None else "%.1f%% of sampled pixels changed" % (d * 100)))
    if not any("expect_no_crash" in st for st in sc["steps"]) and sc.get("implicit_crash_check", True):
        res.append(check("no crash (implicit)", not implicit_crash, "no crash report" if not implicit_crash else "crash evidence: see crash_files / system log"))
    res.append(check("not responding <= %s" % max_nr, len(nr) <= max_nr, "%d line(s)%s" % (len(nr), ": " + nr[0].strip()[:120] if nr else "")))
    if sc.get("fail_on_app_error", True):
        pats = sc.get("app_error_patterns", APP_ERROR)
        ignore = [re.compile(p) for p in sc.get("app_error_ignore", [])]
        errs = [l for l in applog if any(re.search(p, l) for p in pats) and not any(i.search(l) for i in ignore)]
        ctx["app_errors"] = errs
        res.append(check("no error lines in the app log", not errs, errs[0].strip()[:160] if errs else "clean"))
    return res


def cmd_run(a):
    cfg = Config(a.config)
    sc = read_json(a.scenario, "scenario")
    if not isinstance(sc.get("steps"), list) or not sc["steps"]:
        raise Fail("scenario needs a non-empty \"steps\" list")
    state_p = os.path.join(cfg.work, "state.json")
    if not os.path.isfile(state_p):
        raise Fail("not set up yet: run `python nxvtest.py setup` first")
    state = read_json(state_p, "state")
    exe = cfg.p("emulator_exe")
    if not os.path.isfile(exe):
        raise Fail("emulator_exe not found: %s" % exe)
    token = "%x" % (int(time.time() * 1000) & 0xffffffff)
    script = build_script(sc, state["apps"], token)
    name = safe(sc.get("name") or os.path.splitext(os.path.basename(a.scenario))[0])
    out = os.path.join(cfg.work, "runs", "%s-%s" % (name, time.strftime("%Y%m%d-%H%M%S")))
    os.makedirs(os.path.join(out, "shots"))
    sd = cfg.sd
    logs = os.path.join(sd, "System", "Logs")
    sys_log = os.path.join(logs, "system.log")
    for sub in ("autoshots", os.path.join("System", "Logs", "Crashes")):
        shutil.rmtree(os.path.join(sd, sub), ignore_errors=True)
    if os.path.isfile(sys_log):
        os.remove(sys_log)
    shutil.rmtree(os.path.join(logs, "Apps"), ignore_errors=True)
    with open(os.path.join(sd, "autorun.txt"), "w", newline="\n", encoding="utf-8") as f:
        f.write("\n".join(script) + "\n")
    limit = float(sc.get("time_limit", 90))
    args = [x.format(data=cfg.data, nro=state["nro"]) for x in cfg.raw.get("emulator_args", DEFAULT_EMU_ARGS)]
    print("running %s (limit %.0f s, %d autorun lines) ..." % (name, limit, len(script)))
    t0 = time.time()
    proc = start_emulator(exe, args)
    completed, reason, died = False, "", False
    try:
        while True:
            time.sleep(1.5)
            if "nxvtest-end-" + token in read_text(sys_log):
                completed = True
                time.sleep(1.5)  # let the last screenshot land
                break
            if proc.poll() is not None:
                died = True
                reason = "emulator exited early (code %s) before the scenario ended" % proc.returncode
                break
            if time.time() - t0 > limit:
                reason = "hard time limit of %.0f s reached before the scenario ended (hang, or raise time_limit)" % limit
                break
    finally:
        stop_emulator(proc)
        try:
            os.remove(os.path.join(sd, "autorun.txt"))  # never leave the script: the next boot would run it again
        except OSError:
            pass
    dur = time.time() - t0
    syslog = lines_after(read_text(sys_log), token)
    applog = []
    appdir = os.path.join(logs, "Apps")
    if os.path.isdir(appdir):
        for f in sorted(os.listdir(appdir)):
            if f.endswith(".log"):
                applog += [l for l in read_text(os.path.join(appdir, f)).splitlines()]
    shots = {}
    shotdir = os.path.join(sd, "autoshots")
    if os.path.isdir(shotdir):
        for f in os.listdir(shotdir):
            if f.lower().endswith(".png"):
                dst = os.path.join(out, "shots", f)
                shutil.copyfile(os.path.join(shotdir, f), dst)
                shots[os.path.splitext(f)[0]] = dst
    cdir = os.path.join(logs, "Crashes")
    crash_files = sorted(os.listdir(cdir)) if os.path.isdir(cdir) else []
    for c in crash_files:
        try:
            shutil.copyfile(os.path.join(cdir, c), os.path.join(out, "crash_" + c))
        except OSError:
            pass
    with open(os.path.join(out, "system.log"), "w", encoding="utf-8") as f:
        f.write("\n".join(syslog) + "\n")
    with open(os.path.join(out, "app.log"), "w", encoding="utf-8") as f:
        f.write("\n".join(applog) + "\n")
    ctx = {"completed": completed, "incomplete_reason": reason, "emulator_died": died, "system_log": syslog, "app_log": applog,
           "shots": shots, "crash_files": crash_files, "app_ids": state["apps"]}
    checks = evaluate(sc, ctx)
    passed = all(c["ok"] for c in checks)
    result = {"tool": "nxvtest " + VERSION, "scenario": name, "result": "PASS" if passed else "FAIL", "passed": passed,
              "duration_s": round(dur, 1), "checks": checks, "screenshots": sorted(shots.values()),
              "crash_files": crash_files, "not_responding": ctx["not_responding"][:10], "crash_lines": ctx["crash_lines"][:10],
              "app_errors": ctx.get("app_errors", [])[:20], "app_log_lines": len(applog), "run_dir": out}
    with open(os.path.join(out, "result.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    with open(os.path.join(cfg.work, "last_run.txt"), "w", encoding="utf-8") as f:
        f.write(out)
    print_summary(result)
    return 0 if passed else 1


def print_summary(r):
    print("=" * 60)
    print("%s  %s  (%.1f s)" % (r["result"], r["scenario"], r["duration_s"]))
    for c in r["checks"]:
        print("  [%s] %s%s" % ("ok" if c["ok"] else "FAIL", c["check"], " - " + c["detail"] if c["detail"] else ""))
    print("screenshots: %d, app log lines: %d, crash files: %d" % (len(r["screenshots"]), r["app_log_lines"], len(r["crash_files"])))
    print("details: %s" % os.path.join(r["run_dir"], "result.json"))


def cmd_report(a):
    p = a.target
    if not p:
        cfg = Config(a.config)
        p = read_text(os.path.join(cfg.work, "last_run.txt")).strip()
        if not p:
            raise Fail("no run yet")
    if os.path.isdir(p):
        p = os.path.join(p, "result.json")
    r = read_json(p, "result")
    print_summary(r)
    return 0 if r.get("passed") else 1


def main():
    ap = argparse.ArgumentParser(prog="nxvtest", description="Automatic test runs for Nexvyn OS apps in an emulator.")
    ap.add_argument("--config", default=DEFAULT_CONFIG, help="config file (default %s)" % DEFAULT_CONFIG)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("init", help="write a config file")
    p.add_argument("--emulator-exe")
    p.add_argument("--os-nro", help="path to NexvynOS.nro, or 'latest' (default)")
    p.add_argument("--work")
    p.add_argument("--app", help="your app: folder with app.json, .nxvapp, .nxvmod, .lua, .js or .py")
    p.add_argument("--force", action="store_true")
    p.set_defaults(fn=cmd_init)
    p = sub.add_parser("setup", help="prepare the isolated emulator data folder, install the OS and your app")
    p.add_argument("--fresh", action="store_true", help="rebuild everything, re-download the latest OS")
    p.set_defaults(fn=cmd_setup)
    p = sub.add_parser("run", help="run a scenario; exit code 0 = PASS, 1 = FAIL")
    p.add_argument("scenario")
    p.set_defaults(fn=cmd_run)
    p = sub.add_parser("report", help="print the summary of a result.json or run folder (default: the last run)")
    p.add_argument("target", nargs="?")
    p.set_defaults(fn=cmd_report)
    a = ap.parse_args()
    try:
        sys.exit(a.fn(a))
    except Fail as e:
        die(str(e))
    except KeyboardInterrupt:
        die("interrupted")


if __name__ == "__main__":
    main()
