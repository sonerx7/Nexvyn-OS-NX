"""The SDK facts the Nexvyn OS tools share: the SDK version, the runtime table and the app.json version rules.

It mirrors source/core/sdk_version.h (NEXVYN_SDK_VERSION, sdk::target) and source/runtimes/runtime_kind.h
(nxvruntime::kRuntimes, detect); tools/compat_check.py fails when they drift apart. Standard library only, so it also
works in the store CI's sparse checkout of tools/. The rules are in docs/COMPATIBILITY.en.md.
"""
import os
import re

SDK_VERSION = "1.13"
# newest SDK that changed the script API: new script projects use it as minSdk (NEXVYN_SCRIPT_SDK_VERSION)
SCRIPT_SDK_VERSION = "1.12"

# runtime id -> engine, engine version in this build, SDK that added it, main file extensions, default main file
RUNTIMES = {
    "lua": {"engine": "Lua", "version": "5.4.7", "since": "1.0", "ext": (".lua",), "main": "main.lua"},
    "js": {"engine": "QuickJS-ng", "version": "0.17.0", "since": "1.1", "ext": (".js", ".mjs"), "main": "main.js"},
    "python": {"engine": "pocketpy", "version": "2.2.0", "since": "1.3", "ext": (".py",), "main": "main.py"},
    # only by name: a .py main file alone means "python"
    "python3": {"engine": "CPython", "version": "3.12.16", "since": "1.6", "ext": (), "main": "main.py"},
    "squirrel": {"engine": "Squirrel", "version": "3.2", "since": "1.5", "ext": (".nut",), "main": "main.nut"},
    "c": {"engine": "TinyCC", "version": "0.9.28rc", "since": "1.5", "ext": (".c",), "main": "main.c"},
    "java": {"engine": "miniJVM", "version": "2.2.0", "since": "1.5", "ext": (".jar",), "main": "app.jar"},
    # C/C++: a .nxvmod module ("native": "<file>.nxvmod", ABI id) or a full-screen .nro ("mode": "exclusive",
    # "minNative"; NATIVE_KIT.en.md). "version" is the Native SDK version of this build.
    "native": {"engine": "nxn", "version": "1.2", "since": "1.10", "ext": (".nro",), "main": "main.nro"},
}

NATIVE_VERSION = RUNTIMES["native"]["version"]
# A full-screen native package carries "minSdk": this SDK, the one that brought the runtime, so older systems say
# "needs a newer Nexvyn OS" instead of reading the .nro as a script (NATIVE_KIT.en.md section 6).
NATIVE_MIN_SDK = RUNTIMES["native"]["since"]
NATIVE_MODES = ("exclusive", "windowed", "window", "fullscreen")  # window / fullscreen: a .nxvmod in Nexvyn OS (exclusive: retired, old packages only)

VERSION_RE = re.compile(r"v?\d+(\.\d+)*")


def cmp_versions(a, b):
    """Like sdk::compareVersions: "1.2" < "1.10", a leading "v" is ignored, missing parts are 0. <0, 0, >0."""
    def parts(v):
        return [int(x) if x.isdigit() else int(re.match(r"\d*", x).group() or 0)
                for x in str(v).lstrip("vV").split(".")]
    pa, pb = parts(a), parts(b)
    n = max(len(pa), len(pb))
    pa += [0] * (n - len(pa))
    pb += [0] * (n - len(pb))
    return (pa > pb) - (pa < pb)


def version_field(v):
    """An app.json version field ("minSdk": "1.4" or 1.4) as text, "" when missing."""
    if v is None:
        return ""
    if isinstance(v, (int, float)) and not isinstance(v, bool):
        return "%g" % v
    return str(v).strip()


def supports(min_sdk, sdk=SDK_VERSION):
    return not min_sdk or cmp_versions(min_sdk, sdk) <= 0


def target_sdk(app):
    """The SDK an app was built and tested against: "targetSdk", else "minSdk", else "1.0"; never below minSdk."""
    m = version_field(app.get("minSdk")) or "1.0"
    t = version_field(app.get("targetSdk"))
    return m if not t or cmp_versions(t, m) < 0 else t


def runtime_of(app):
    """Like nxvruntime::detect: "native" for C++ modules, an explicit "runtime" (an unknown one as it is, lower case),
    else the main file's extension (Lua by default)."""
    if isinstance(app.get("native"), str):
        return "native"
    r = str(app.get("runtime") or "").strip().lower()
    if r == "javascript":
        return "js"
    if r:
        return r
    ext = os.path.splitext(str(app.get("main") or ""))[1].lower()
    for rid, info in RUNTIMES.items():
        if ext in info["ext"]:
            return rid
    return "lua"


def main_file(app):
    """The file the bundle must have: "main", or the runtime's default ("" for a runtime this SDK does not know)."""
    if isinstance(app.get("native"), str):
        return app["native"]
    rt = RUNTIMES.get(runtime_of(app))
    return app.get("main") or (rt["main"] if rt else "")
