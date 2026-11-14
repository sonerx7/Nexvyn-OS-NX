"""The SDK facts the Nexvyn OS tools share: the SDK version, the runtime table and the app.json version rules.

It mirrors source/core/sdk_version.h (NEXVYN_SDK_VERSION, sdk::target); the runtime table comes from the one registry
(tools/registry/runtimes.json, generated into tools/sdkinfo_runtime.py and source/runtimes/runtime_table.inc).
tools/compat_check.py fails when they drift apart. Standard library only, so it also works in the store CI's sparse
checkout of tools/. The rules are in docs/COMPATIBILITY.md.
"""
import os
import re

from sdkinfo_runtime import ALIASES, DEFAULT_RUNTIME, NATIVE_MODES, RUNTIMES  # noqa: F401  (re-exported)

SDK_VERSION = "1.13"
# newest SDK that changed the script API: new script projects use it as minSdk (NEXVYN_SCRIPT_SDK_VERSION)
SCRIPT_SDK_VERSION = "1.12"

NATIVE_VERSION = RUNTIMES["native"]["version"]
# A full-screen native package carries "minSdk": this SDK, the one that brought the runtime, so older systems say
# "needs a newer Nexvyn OS" instead of reading the .nro as a script (NATIVE_KIT.md section 6).
NATIVE_MIN_SDK = RUNTIMES["native"]["since"]

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
    if r in ALIASES:
        return ALIASES[r]
    if r:
        return r
    ext = os.path.splitext(str(app.get("main") or ""))[1].lower()
    for rid, info in RUNTIMES.items():
        if ext in info["ext"]:
            return rid
    return DEFAULT_RUNTIME


def main_file(app):
    """The file the bundle must have: "main", or the runtime's default ("" for a runtime this SDK does not know)."""
    if isinstance(app.get("native"), str):
        return app["native"]
    rt = RUNTIMES.get(runtime_of(app))
    return app.get("main") or (rt["main"] if rt else "")
