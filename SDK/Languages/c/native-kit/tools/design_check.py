#!/usr/bin/env python3
"""Strict OS design-language checker ("one design language, four languages").

Scans app packages (romfs/Applications/*.nxvapp, showcase/*, sdk/native/templates/*, sdk/native/examples/*,
tools/tests/recipes/*.nxvapp) and reports PASS / WARN / FAIL per package. Only FAIL breaks the gate.

Native C/C++ (a source that uses ImGui::). Every finding names the fix (the nxn_os_* replacement):
  FAIL  no <nexvyn/nxn_os_ui.h> include, or no nxn_os_frame_begin() (the frame layer: UI scale, fonts, style), or no
        nxn_os_clear_color() call; a constant glClearColor() in a package that never calls nxn_os_clear_color()
  FAIL  io.FontGlobalScale / SetWindowFontScale (blurry stretched text: the frame layer rasterises at the real size)
  FAIL  fonts added by the app (AddFont*, nxn_imgui_add_font): the frame layer builds the text roles
  FAIL  raw ImGui widgets that have an OS widget: Button, SmallButton, ArrowButton, Combo / BeginCombo, Checkbox,
        RadioButton, SliderFloat / SliderInt, InputText / InputTextWithHint / InputTextMultiline, ProgressBar,
        BeginTabBar (nxn_os_button, nxn_os_icon_button, nxn_os_select, nxn_os_switch_row / nxn_os_toggle_button,
        nxn_os_segmented_tabs, nxn_os_slider / nxn_os_slider_int, nxn_os_input / nxn_os_input_multiline,
        nxn_os_progress_bar)
  FAIL  pixel literals (>= 2) outside NXN_S() / nxn_os_s(): in SetNextItemWidth, PushItemWidth, Dummy, SameLine
        (spacing), SetCursorPos*, Indent, BeginChild, SetNextWindowSize, as an ImVec2(...) component, and as a float
        argument of an nxn_os_* widget
  Scenes and games (`nxn-design: scene` in a source, app.json "category": "games" / "type": "game") are exempt from
  the widget, font and pixel rules; their other findings are WARN, like every native finding of a "scene" package.
Scripts (Lua, JavaScript, Python):
  WARN  raw colour literal (0xRRGGBB, "#RRGGBB", rgb( ) instead of theme.*
  WARN  gfx.text / ui.label size literal that is not a canonical role size (11.5 12 13 13.8 14 15 15.2 17 19 19.2)

Tiers: "app" packages (romfs, showcase, sdk/native/templates) are strict. "scene" packages (sdk/native/examples,
recipes) are samples, benchmarks and engine scenes: native findings there are capped at WARN. A source file with the
marker `nxn-design: scene` is treated as a scene too. Games (app.json "category": "games" / "type": "game") and
sources that draw through ui.canvas / g3d are exempt from the script colour and size warnings.

  python tools/design_check.py            print the report, write qa/n2/design_report.json, exit 1 on any FAIL
  python tools/design_check.py --no-write print only
  python tools/design_check.py --json     print the JSON report
  python tools/design_check.py <folder>   check one app or native project, strict (what `nxv check` runs)
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
REPORT = os.path.join(ROOT, "qa", "n2", "design_report.json")

# floor(pt * 1.21 + 0.5): Title 19.2 -> 23, CardHeader 15.2 -> 18, Body 13.8 -> 17, Caption 11.5 -> 14, Subtitle 12 -> 15
CANON_NATIVE_PX = {23, 18, 17, 14, 15}
CANON_SCRIPT_PT = {11.5, 12.0, 13.0, 13.8, 14.0, 15.0, 15.2, 17.0, 19.0, 19.2}

NATIVE_EXT = (".c", ".cc", ".cpp", ".cxx", ".h", ".hpp")
SCRIPT_EXT = (".lua", ".js", ".py")
SKIP_DIRS = {"build", "third_party", "imgui", "lib", ".git", "node_modules"}

# raw ImGui widget -> the OS widget that replaces it
RAW_WIDGETS = {
    "Button": "nxn_os_button", "SmallButton": "nxn_os_button", "ArrowButton": "nxn_os_icon_button",
    "Combo": "nxn_os_select", "BeginCombo": "nxn_os_select", "Checkbox": "nxn_os_switch_row / nxn_os_toggle_button",
    "RadioButton": "nxn_os_segmented_tabs", "SliderFloat": "nxn_os_slider", "SliderInt": "nxn_os_slider_int",
    "InputText": "nxn_os_input", "InputTextWithHint": "nxn_os_input", "InputTextMultiline": "nxn_os_input_multiline",
    "ProgressBar": "nxn_os_progress_bar", "BeginTabBar": "nxn_os_segmented_tabs",
}
RAW_RE = re.compile(r"ImGui::(%s)\s*\(" % "|".join(sorted(RAW_WIDGETS, key=len, reverse=True)))
# calls whose arguments are pixel sizes: every literal >= 2 in them must go through NXN_S()
SIZE_CALLS = ["SetNextItemWidth", "PushItemWidth", "Dummy", "SameLine", "SetCursorPosX", "SetCursorPosY", "SetCursorPos",
              "Indent", "Unindent", "BeginChild", "SetNextWindowSize"]
SIZE_RE = re.compile(r"ImGui::(%s)\s*\(" % "|".join(sorted(SIZE_CALLS, key=len, reverse=True)))
SCALED_RE = re.compile(r"\b(NXN_S|nxn_os_s|nxn_os_sp|nxn_os_radius|nxn_os_fill)\s*\(")
LIT_RE = re.compile(r"(?<![\w.])(\d+\.\d*|\.\d+|\d+)([fF])?(?![\w.])")
FLOAT_LIT_RE = re.compile(r"-?(\d+\.\d*|\.\d+)[fF]?|-?\d+[fF]")
FONT_ADD_RE = re.compile(r"(\bAddFont\w*|\bnxn_imgui_add_font)\s*\(")
UNSCALED_OK = ("nxn_os_s", "nxn_os_sp", "nxn_os_fill", "nxn_os_radius", "nxn_os_set_text_zoom", "nxn_os_text_colored",
               "nxn_os_badge", "nxn_os_imvec4", "nxn_os_u32", "nxn_os_shift_u32", "nxn_os_lerp_u32")
# widgets with value arguments (range, fraction): only these argument positions are pixel sizes
PX_ARGS = {"nxn_os_slider": (5, 6), "nxn_os_slider_int": (4,), "nxn_os_progress_bar": (1, 2)}
FIX = {
    "frame": "call nxn_os_frame_begin(&tok, fb_w, fb_h) / nxn_os_frame_end() instead of ImGui::NewFrame / Render",
    "scale": "remove it: the frame layer builds the fonts at the real size (nxn_os_set_text_zoom for an app text size)",
    "font": "remove it: the frame layer builds the text roles; draw text with nxn_os_text(NXN_OS_TEXT_*, s)",
    "px": "wrap the number in NXN_S() or use nxn_os_sp() / nxn_os_fill() / the widget default (0)",
}


def strip_c_comments(s):
    s = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), s, flags=re.S)
    return re.sub(r"//[^\n]*", "", s)


def split_args(s, start):
    """Top-level comma split of the call whose '(' is just before `start`."""
    depth, cur, out, i, q = 0, "", [], start, None
    while i < len(s):
        c = s[i]
        if q:
            cur += c
            if c == "\\":
                i += 1
                cur += s[i:i + 1]
            elif c == q:
                q = None
        elif c in "\"'":
            q = c
            cur += c
        elif c in "([{":
            depth += 1
            cur += c
        elif c in ")]}":
            if depth == 0:
                out.append(cur.strip())
                return out
            depth -= 1
            cur += c
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        elif c == "\n" and depth == 0 and not cur.strip():
            pass
        else:
            cur += c
        i += 1
    return out


def num(a):
    a = a.strip().rstrip("fF")
    try:
        return float(a)
    except ValueError:
        return None


def read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def walk(pkg, exts):
    for d, dirs, files in os.walk(pkg):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in sorted(files):
            if f.lower().endswith(exts):
                yield os.path.join(d, f)


def is_game(pkg):
    try:
        j = json.loads(read(os.path.join(pkg, "app.json")) or "{}")
        return j.get("category") == "games" or j.get("type") == "game"
    except ValueError:
        return False


def scaled_free(expr):
    """`expr` without the NXN_S(...) / nxn_os_s(...) / nxn_os_sp(...) / nxn_os_fill(...) calls (their numbers are OS pixels)."""
    out, i = "", 0
    for m in SCALED_RE.finditer(expr):
        if m.start() < i:
            continue
        out += expr[i:m.start()] + "S"
        depth, k = 1, m.end()
        while k < len(expr) and depth:
            depth += {"(": 1, ")": -1}.get(expr[k], 0)
            k += 1
        i = k
    return out + expr[i:]


def px_literals(expr):
    """Numbers >= 2 written in `expr` outside the scaling helpers."""
    found = []
    for m in LIT_RE.finditer(scaled_free(expr)):
        try:
            v = float(m.group(1))
        except ValueError:
            continue
        if abs(v) >= 2:
            found.append(m.group(0))
    return found


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def native_findings(files, scene):
    """The widget and pixel rules for (relative path, comment-free source) pairs: [(rel, line, message)]."""
    out = []
    if scene:
        return out
    for rel, c in files:
        for m in RAW_RE.finditer(c):
            out.append((rel, line_of(c, m.start()), "raw ImGui::%s: use %s" % (m.group(1), RAW_WIDGETS[m.group(1)])))
        for m in SIZE_RE.finditer(c):
            args = split_args(c, m.end())
            if m.group(1) == "BeginChild":
                args = args[1:2]  # the size
            elif m.group(1) == "SameLine":
                args = args[1:2]  # SameLine(offset_from_start_x, spacing): the offset is a position the app computed
            lits = []
            for a in args:
                lits += px_literals(a)
            if lits:
                out.append((rel, line_of(c, m.start()), "pixel literal %s in ImGui::%s: %s" %
                            (", ".join(lits[:3]), m.group(1), FIX["px"])))
        for m in re.finditer(r"\bImVec2\s*\(", c):
            args = split_args(c, m.end())
            bare = [a for a in args if num(a) is not None and abs(num(a)) >= 2]
            if bare:
                out.append((rel, line_of(c, m.start()), "pixel literal ImVec2(%s): %s" % (", ".join(args), FIX["px"])))
        for m in re.finditer(r"\b(nxn_os_\w+)\s*\(", c):
            if m.group(1) in UNSCALED_OK:
                continue
            args = split_args(c, m.end())
            if m.group(1) in PX_ARGS:
                args = [args[k] for k in PX_ARGS[m.group(1)] if k < len(args)]
            lits = [a for a in args if FLOAT_LIT_RE.fullmatch(a.strip()) and abs(num(a)) >= 2]
            if lits:
                out.append((rel, line_of(c, m.start()), "pixel literal %s in %s(): %s" %
                            (", ".join(lits[:3]), m.group(1), FIX["px"])))
    return out


def check_native(pkg, relaxed, issues):
    files = [(p, strip_c_comments(read(p)), read(p)) for p in walk(pkg, NATIVE_EXT)]
    # a package-wide view: the helpers may sit in another file of the same package
    blob = "\n".join(c for _, c, _ in files)
    if "ImGui::" not in blob:
        return
    scene = any("nxn-design: scene" in raw for _, _, raw in files) or is_game(pkg)
    sev = "WARN" if (relaxed or scene) else "FAIL"
    rel = lambda p: os.path.relpath(p, pkg).replace("\\", "/")
    if not re.search(r"#\s*include\s*[<\"][^>\"]*nxn_os_ui\.h", blob):
        issues.append((sev, "ImGui used without <nexvyn/nxn_os_ui.h>"))
    if "nxn_os_frame_begin" not in blob:
        if scene or relaxed:
            if "nxn_os_apply_style(" not in blob:
                issues.append((sev, "ImGui used without nxn_os_apply_style(tok) or nxn_os_frame_begin()"))
        else:
            issues.append((sev, "ImGui used without the frame layer: " + FIX["frame"]))
    if not scene and not re.search(r"\bnxn_imgui_input\s*\(", blob):
        issues.append((sev, "no shared input backend: call nxn_imgui_input(backend, state, dt) once before nxn_os_frame_begin(); it handles touch capture, mouse/wheel, keyboard/text and gamepad"))
    if not scene and not re.search(r"\bnxn_imgui_input_event\s*\(", blob):
        issues.append((sev, "no input lifecycle forwarding: call nxn_imgui_input_event(event) for each polled event so focus loss releases held keys and touch motion"))
    has_clear = "nxn_os_clear_color(" in blob
    if not has_clear:
        issues.append((sev, "no nxn_os_clear_color(tok): the window clears to a private colour"))
    for p, c, _ in files:
        for m in re.finditer(r"glClearColor\s*\(", c):
            args = split_args(c, m.end())
            if len(args) >= 3 and all(num(a) is not None for a in args[:3]):
                if has_clear:
                    issues.append(("WARN", "%s: constant glClearColor (scene clear) next to nxn_os_clear_color" % rel(p)))
                else:
                    issues.append((sev, "%s: constant glClearColor(%s)" % (rel(p), ", ".join(args[:3]))))
                break
        for m in re.finditer(r"FontGlobalScale\s*=\s*([^;]+);", c):
            issues.append((sev, "%s:%d: io.FontGlobalScale = %s: %s" %
                           (rel(p), line_of(c, m.start()), m.group(1).strip(), FIX["scale"])))
        for m in re.finditer(r"SetWindowFontScale\s*\(", c):
            issues.append((sev, "%s:%d: SetWindowFontScale(): %s" % (rel(p), line_of(c, m.start()), FIX["scale"])))
        if not scene and not relaxed:
            for m in FONT_ADD_RE.finditer(c):
                issues.append((sev, "%s:%d: %s(): %s" % (rel(p), line_of(c, m.start()), m.group(1), FIX["font"])))
        else:
            for m in re.finditer(r"nxn_imgui_add_font\s*\(", c):
                args = split_args(c, m.end())
                if len(args) >= 3:
                    v = num(args[2])
                    if v is not None and int(v) not in CANON_NATIVE_PX:
                        issues.append((sev, "%s: font size %g is not a canonical role size %s" %
                                       (rel(p), v, sorted(CANON_NATIVE_PX))))
    for r, line, msg in native_findings([(rel(p), c) for p, c, _ in files], scene):
        issues.append((sev, "%s:%d: %s" % (r, line, msg)))


def check_folder(path):
    """One app or native project (strict, as `nxv check` runs it): [(severity, message)]."""
    issues = []
    check_native(path, False, issues)
    check_script(path, issues)
    seen, uniq = set(), []
    for s, m in issues:
        if m not in seen:
            seen.add(m)
            uniq.append((s, m))
    return uniq


COLOR_RES = [re.compile(r"\b0[xX][0-9A-Fa-f]{6,8}\b"), re.compile(r"[\"']#[0-9A-Fa-f]{6,8}[\"']"),
             re.compile(r"\brgba?\s*\(")]


def strip_script_comment(line, ext):
    if ext == ".py":
        return re.sub(r"\s#.*$", "", line) if not line.lstrip().startswith("#") else ""
    if ext == ".lua":
        return "" if line.lstrip().startswith("--") else re.sub(r"\s--.*$", "", line)
    return "" if line.lstrip().startswith("//") else re.sub(r"\s//.*$", "", line)


def check_script(pkg, issues):
    if is_game(pkg):
        return
    colors, sizes = {}, {}
    for p in walk(pkg, SCRIPT_EXT):
        src = read(p)
        if re.search(r"\b(ui\.canvas|g3d\.)", src):
            continue
        ext = os.path.splitext(p)[1].lower()
        name = os.path.relpath(p, pkg).replace("\\", "/")
        cleaned = "\n".join(strip_script_comment(l, ext) for l in src.split("\n"))
        for rx in COLOR_RES:
            for m in rx.finditer(cleaned):
                colors.setdefault(name, set()).add(m.group(0))
        for m in re.finditer(r"\b(gfx\.text|ui\.label)\s*\(", cleaned):
            args = split_args(cleaned, m.end())
            idx = 3 if m.group(1) == "gfx.text" else 3
            if len(args) > idx:
                v = num(args[idx])
                if v is not None and v not in CANON_SCRIPT_PT:
                    sizes.setdefault(name, set()).add(v)
    for n in sorted(colors):
        issues.append(("WARN", "%s: raw colour literal(s) %s: use theme.*" % (n, ", ".join(sorted(colors[n])[:4]))))
    for n in sorted(sizes):
        issues.append(("WARN", "%s: non-canonical text size(s) %s" % (n, ", ".join("%g" % x for x in sorted(sizes[n])))))


def packages():
    out = []

    def add(d, tier):
        if os.path.isdir(d):
            for n in sorted(os.listdir(d)):
                p = os.path.join(d, n)
                if os.path.isdir(p) and not n.endswith(".legacy") and not n.startswith("."):
                    out.append((os.path.relpath(p, ROOT).replace("\\", "/"), p, tier))

    def add_apps(d, tier):
        if os.path.isdir(d):
            for n in sorted(os.listdir(d)):
                p = os.path.join(d, n)
                if os.path.isdir(p) and n.endswith(".nxvapp"):
                    out.append((os.path.relpath(p, ROOT).replace("\\", "/"), p, tier))

    add_apps(os.path.join(ROOT, "romfs", "Applications"), "app")
    add(os.path.join(ROOT, "showcase"), "app")
    add(os.path.join(ROOT, "sdk", "samples", "inputlab"), "app")
    for n in sorted(os.listdir(os.path.join(ROOT, "sdk", "native", "templates"))) if os.path.isdir(os.path.join(ROOT, "sdk", "native", "templates")) else []:
        out.append(("sdk/native/templates/" + n, os.path.join(ROOT, "sdk", "native", "templates", n), "app"))
    add(os.path.join(ROOT, "sdk", "native", "examples"), "scene")
    add_apps(os.path.join(ROOT, "tools", "tests", "recipes"), "scene")
    return out


def main():
    args = sys.argv[1:]
    folders = [a for a in args if not a.startswith("-")]
    if folders:
        bad = 0
        for f in folders:
            found = check_folder(os.path.abspath(f))
            for sev, msg in found:
                print("%-4s %s" % (sev, msg))
            fails = sum(1 for sev, _ in found if sev == "FAIL")
            bad += fails
            print("design:    %s (%d FAIL, %d WARN)" % ("FAIL" if fails else "ok", fails, len(found) - fails))
        return 1 if bad else 0
    rows = []
    for rel, p, tier in packages():
        issues = []
        check_native(p, tier == "scene", issues)
        check_script(p, issues)
        seen, uniq = set(), []
        for s, m in issues:
            if m not in seen:
                seen.add(m)
                uniq.append({"severity": s, "message": m})
        status = "FAIL" if any(i["severity"] == "FAIL" for i in uniq) else ("WARN" if uniq else "PASS")
        rows.append({"package": rel, "tier": tier, "status": status, "issues": uniq})
    summary = {k: sum(1 for r in rows if r["status"] == k) for k in ("PASS", "WARN", "FAIL")}
    report = {"summary": summary, "packages": rows}
    if "--json" in args:
        print(json.dumps(report, indent=2))
    else:
        for r in rows:
            if r["status"] != "PASS" or "-v" in args:
                print("%-4s %s" % (r["status"], r["package"]))
                for i in r["issues"][:5]:
                    print("       %s: %s" % (i["severity"], i["message"]))
                if len(r["issues"]) > 5:
                    print("       ... %d more" % (len(r["issues"]) - 5))
        print("design_check: %d packages, %d PASS, %d WARN, %d FAIL" %
              (len(rows), summary["PASS"], summary["WARN"], summary["FAIL"]))
    if "--no-write" not in args:
        os.makedirs(os.path.dirname(REPORT), exist_ok=True)
        with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
            json.dump(report, f, indent=2)
            f.write("\n")
    return 1 if summary["FAIL"] else 0


if __name__ == "__main__":
    sys.exit(main())
