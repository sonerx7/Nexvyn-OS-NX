#!/usr/bin/env python3
"""
Nexvyn OS N2 Smart App Creator & 4-Track Generator.
Guides language selection based on workload profile and generates ready-to-pack project templates.

Official 4 Tracks:
  1. Lua 5.4.7 (PUC Lua - default for utilities, calculators, settings, lightweight tools)
  2. JavaScript ES2023 (QuickJS-ng 0.17.0 - default for dynamic/network/REST/JSON apps)
  3. Python 3.12 (CPython 3.12.16 - default for data processing, stdlib, automation tools)
  4. Native C/C++ (devkitA64 GCC AOT - default for 2D/3D games, OpenGL, emulators, heavy ports)
"""
import sys
import json
import re
import struct
import zlib
import argparse
from pathlib import Path

VALID_RUNTIMES = ("lua", "js", "python", "native")
VALID_PROFILES = ("calculator", "utility", "network", "data", "game", "qemu", "emulator", "port")

PROFILE_RECOMMENDATIONS = {
    "calculator": {
        "runtime": "lua",
        "reason": "Fastest cold-start time, lowest RAM footprint, and responsive NXUI layout for utility tools.",
        "perfBudget": {"maxRamMb": 16, "targetFps": 60, "profile": "utility"}
    },
    "utility": {
        "runtime": "lua",
        "reason": "Lightweight resource usage and immediate NXUI scripting for system utilities and panels.",
        "perfBudget": {"maxRamMb": 24, "targetFps": 60, "profile": "utility"}
    },
    "network": {
        "runtime": "js",
        "reason": "Native JSON modeling, Promises/async-await, and REST/WebSocket integration via QuickJS-ng ES2023.",
        "perfBudget": {"maxRamMb": 32, "targetFps": 60, "profile": "media/network"}
    },
    "data": {
        "runtime": "python",
        "reason": "Full CPython 3.12 standard library, data analysis, and rich scripting ecosystem.",
        "perfBudget": {"maxRamMb": 48, "targetFps": 60, "profile": "utility"}
    },
    "game": {
        "runtime": "native",
        "reason": "Direct OpenGL 4.3 / NexGFX GPU control, deterministic 60 FPS frame pacing, and full AArch64 speed.",
        "perfBudget": {"maxRamMb": 128, "targetFps": 60, "profile": "2D/3D game"}
    },
    "qemu": {
        "runtime": "native",
        "reason": "Ahead-Of-Time GCC compilation, virtual memory W^X JIT support, and low-level Port Kit architecture.",
        "perfBudget": {"maxRamMb": 256, "targetFps": 60, "profile": "emulator/heavy port"}
    },
    "emulator": {
        "runtime": "native",
        "reason": "Low-level CPU loops, W^X JIT code memory, multi-threaded audio/video, and Port Kit foundation.",
        "perfBudget": {"maxRamMb": 256, "targetFps": 60, "profile": "emulator/heavy port"}
    },
    "port": {
        "runtime": "native",
        "reason": "Direct C/C++ compilation with devkitA64 GCC and Native SDK ABI v1 window/OpenGL/audio bridges.",
        "perfBudget": {"maxRamMb": 192, "targetFps": 60, "profile": "emulator/heavy port"}
    }
}

def make_png(size=256):
    """Pure-Python gradient PNG icon generator."""
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            rows += bytes((20 + x // 5, 30 + y // 6, 90 + (x + y) // 8))
    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))

def score_workload(answers):
    scores = {"lua": 0, "js": 0, "python": 0, "native": 0}
    if answers.get("has_c_deps"):
        scores["native"] += 12
    if answers.get("is_emulator_or_vm"):
        scores["native"] += 15
    if answers.get("is_heavy_3d"):
        scores["native"] += 10
    if answers.get("is_network_json"):
        scores["js"] += 10
    if answers.get("is_data_script"):
        scores["python"] += 10
    if answers.get("is_lightweight_tool"):
        scores["lua"] += 12
    if answers.get("fast_startup_low_ram"):
        scores["lua"] += 8
    best = max(scores, key=scores.get)
    return best, scores

def create_project(dest_dir, app_id, name, runtime, profile="utility"):
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    perf_info = PROFILE_RECOMMENDATIONS.get(profile, PROFILE_RECOMMENDATIONS["utility"])
    perf_budget = perf_info["perfBudget"]

    manifest = {
        "id": app_id,
        "name": name,
        "version": "1.0.0",
        "build": 1,
        "type": "app",
        "runtime": runtime,
        "minSdk": "1.12",
        "targetSdk": "2.0",
        "targetNative": "2.0",
        "dataSchema": 1,
        "uiApi": 2,
        "uiTheme": 2,
        "perfBudget": perf_budget,
        "author": "Nexvyn Developer",
        "description": f"{name} - built for Nexvyn OS N2",
        "window": {
            "width": 920,
            "height": 580,
            "minWidth": 480,
            "minHeight": 320,
            "resizable": True
        },
        "permissions": []
    }

    if runtime == "native":
        manifest["runtime"] = "native"
        manifest["mode"] = "window"
        manifest["minNative"] = "1.2"
        manifest["targetNative"] = "2.0"
        manifest["main"] = f"{app_id}.nxvmod"
    elif runtime == "lua":
        manifest["main"] = "main.lua"
    elif runtime == "js":
        manifest["main"] = "main.js"
    elif runtime == "python":
        manifest["main"] = "main.py"

    (dest / "app.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lang_dir = dest / "lang"
    lang_dir.mkdir(exist_ok=True)
    lang_en = {
        "title": name,
        "greeting": f"Welcome to {name}!",
        "action.confirm": "Confirm",
        "action.back": "Back"
    }
    (lang_dir / "en.json").write_text(json.dumps(lang_en, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (dest / "icon.png").write_bytes(make_png())

    if runtime == "lua":
        code = f"""-- {name} (Nexvyn OS N2 — Official Lua 5.4.7 Track)
local app = {{
    count = 0,
    sliderVal = 0.5
}}

function app.load(arg)
    print("[{name}] Loaded with Nexvyn OS N2 Lua 5.4.7 runtime")
end

function app.update(dt)
end

function app.draw(w, h)
    gfx.clear(theme.bg)
    nxui.begin(w, h)
    nxui.card("main_card")
        nxui.label("hdr", TR("greeting"), "title")
        nxui.label("sub", "Counter: " .. tostring(app.count), "body")
        if nxui.button("btn_inc", TR("action.confirm") .. " (+1)", "primary") then
            app.count = app.count + 1
        end
        app.sliderVal = nxui.slider("sl_demo", app.sliderVal, 0.0, 1.0)
    nxui.cardEnd()
    nxui.endFrame()
end

function app.event(e)
end

return app
"""
        (dest / "main.lua").write_text(code, encoding="utf-8")

    elif runtime == "js":
        code = f"""// {name} (Nexvyn OS N2 — Official QuickJS-ng ES2023 Track)

export default {{
    count: 0,
    sliderVal: 0.5,

    load(arg) {{
        print("[{name}] Loaded with Nexvyn OS N2 QuickJS-ng ES2023 runtime");
    }},

    update(dt) {{
    }},

    draw(w, h) {{
        gfx.clear(theme.bg);
        nxui.begin(w, h);
        nxui.card("main_card");
            nxui.label("hdr", TR("greeting"), "title");
            nxui.label("sub", `Counter: ${{this.count}}`, "body");
            if (nxui.button("btn_inc", `${{TR("action.confirm")}} (+1)`, "primary")) {{
                this.count += 1;
            }}
            this.sliderVal = nxui.slider("sl_demo", this.sliderVal, 0.0, 1.0);
        nxui.cardEnd();
        nxui.endFrame();
    }},

    event(e) {{
    }}
}};
"""
        (dest / "main.js").write_text(code, encoding="utf-8")

    elif runtime == "python":
        code = f"""# {name} (Nexvyn OS N2 — Official CPython 3.12 Track)


class App:
    def __init__(self):
        self.count = 0
        self.slider_val = 0.5

    def load(self, arg=""):
        print("[{name}] Loaded with Nexvyn OS N2 CPython 3.12 runtime")

    def update(self, dt):
        pass

    def draw(self, w, h):
        gfx.clear(theme.bg)
        nxui.begin(w, h)
        nxui.card("main_card")
        nxui.label("hdr", TR("greeting"), "title")
        nxui.label("sub", f"Counter: {{self.count}}", "body")
        if nxui.button("btn_inc", f"{{TR('action.confirm')}} (+1)", "primary"):
            self.count += 1
        self.slider_val = nxui.slider("sl_demo", self.slider_val, 0.0, 1.0)
        nxui.cardEnd()
        nxui.endFrame()

    def event(self, e):
        pass


app = App()
"""
        (dest / "main.py").write_text(code, encoding="utf-8")

    elif runtime == "native":
        src_dir = dest / "source"
        src_dir.mkdir(exist_ok=True)
        c_code = f"""/* {name} (Nexvyn OS N2 — Official devkitA64 GCC AOT Native C/C++ Track) */
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_nxui.h>
#include <glad/glad.h>
#include <stdio.h>

static int app_main(int argc, char** argv) {{
    (void)argc;
    (void)argv;

    nxn_display* disp = NULL;
    if (nxn_display_open(NULL, &disp) != NXN_OK) {{
        nxn_request_return(NXN_RETURN_ERROR, 1, "Failed to open OpenGL display");
        return 1;
    }}
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);

    uint32_t sw = 920, sh = 580;
    nxn_display_size(disp, &sw, &sh);
    glViewport(0, 0, (GLsizei)sw, (GLsizei)sh);

    nxn_log(NXN_LOG_INFO, "[{name}] Native ABI v1 module started (%ux%u)", sw, sh);

    while (!nxn_should_quit()) {{
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {{
            if (ev.type == NXN_EVENT_RESIZE && nxn_display_resize(disp, ev.width, ev.height) == NXN_OK) {{
                nxn_display_size(disp, &sw, &sh);
                glViewport(0, 0, (GLsizei)sw, (GLsizei)sh);
            }}
            ev.size = sizeof(ev);
        }}

        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        if (in.pressed & NXN_BTN_PLUS) {{
            nxn_request_return(NXN_RETURN_USER, 0, NULL);
        }}

        glClearColor(0.08f, 0.10f, 0.14f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        nxn_display_swap(disp);
    }}

    nxn_display_close(disp);
    return 0;
}}

int main(int argc, char** argv) {{
    return nxn_run(argc, argv, app_main, NULL);
}}
"""
        (src_dir / "main.c").write_text(c_code, encoding="utf-8")

        makefile_code = f"""# Nexvyn OS N2 — Windowed Native Module (.nxvmod) Makefile
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment.")
endif
include $(DEVKITPRO)/libnx/switch_rules

TARGET   := {app_id}
NXN_SDK  ?= $(abspath ../../SDK/Languages/c/native-kit)
ARCH     := -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -fPIC
CFLAGS   := -g -Wall -O2 -ffunction-sections $(ARCH) -D__SWITCH__ -I$(NXN_SDK)/include -I$(PORTLIBS)/include -I$(LIBNX)/include
LDFLAGS  := -shared -nostartfiles -nostdlib -g $(ARCH) -Wl,-Bsymbolic -Wl,-z,now -Wl,-z,text -Wl,-z,max-page-size=0x1000 -Wl,--hash-style=sysv -Wl,--gc-sections -Wl,--undefined=nxnwin_identity

all: $(TARGET).nxvmod

$(TARGET).nxvmod: source/main.c
\t$(CC) $(CFLAGS) -c source/main.c -o main.o
\t$(CC) $(LDFLAGS) main.o -L$(NXN_SDK)/lib -lnexvyn_window -L$(PORTLIBS)/lib -lglad -lgcc -o $@
\t@rm -f main.o

clean:
\t@rm -f main.o $(TARGET).nxvmod
"""
        (dest / "Makefile").write_text(makefile_code, encoding="utf-8")

    return dest

def main():
    parser = argparse.ArgumentParser(description="Nexvyn OS N2 Smart App Creator")
    parser.add_argument("name", nargs="?", default="MyNewApp", help="Application display name")
    parser.add_argument("--id", help="Reverse domain package ID (e.g. com.example.calc)")
    parser.add_argument("--profile", choices=VALID_PROFILES, help="Target workload profile")
    parser.add_argument("--runtime", choices=VALID_RUNTIMES, help="Explicitly force runtime (lua, js, python, native)")
    parser.add_argument("--dir", help="Destination folder (defaults to ./<name>)")
    parser.add_argument("--recommend-only", action="store_true", help="Print recommendation without creating files")
    args = parser.parse_args()

    profile = args.profile or "utility"
    rec = PROFILE_RECOMMENDATIONS.get(profile, PROFILE_RECOMMENDATIONS["utility"])
    chosen_runtime = args.runtime or rec["runtime"]

    if args.recommend_only:
        print(f"Profile:        {profile}")
        print(f"Recommendation: {rec['runtime']}")
        print(f"Reason:         {rec['reason']}")
        print(f"RAM Budget:     {rec['perfBudget']['maxRamMb']} MB")
        print(f"Target FPS:     {rec['perfBudget']['targetFps']}")
        return

    safe_name = re.sub(r"[^a-zA-Z0-9_\-]", "", args.name.lower())
    app_id = args.id or f"com.nexvyn.{safe_name}"
    target_dir = args.dir or str(Path(safe_name))

    print("--- Nexvyn OS N2 App Creator ---")
    print(f"App Name:       {args.name}")
    print(f"Package ID:     {app_id}")
    print(f"Profile:        {profile}")
    print(f"Runtime:        {chosen_runtime} (Recommended: {rec['runtime']})")
    print(f"Target Dir:     {target_dir}")

    created = create_project(target_dir, app_id, args.name, chosen_runtime, profile)
    print(f"\nSUCCESS: Project created at {created}")
    print(f"To pack:   python SDK/Tools/nxv/nxv.py pack {target_dir}")
    print(f"To check:  python SDK/Tools/nxv/nxv.py check {target_dir}")

if __name__ == "__main__":
    main()
