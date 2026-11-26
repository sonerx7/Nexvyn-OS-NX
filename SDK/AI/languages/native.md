# Language pack: Native C / C++ (`.nxvmod` — Frozen ABI v1, Native SDK 1.3)

Add this after `system-prompt.md` when building a Native C or C++ app, game, port or emulator (`"runtime": "native"`).
Full references: `SDK/Guides/NATIVE_GUIDE.md`, `SDK/Guides/NATIVE_KIT.md`, and `SDK/Languages/c/native-kit/include/nexvyn/`.

## 1. Manifest (`app.json`)

```json
{
  "id": "com.yourname.nativeapp",
  "name": {"en": "Native App"},
  "description": {"en": "High-speed native C/C++ application"},
  "version": "1.0.0",
  "runtime": "native",
  "mode": "window",
  "main": "com.yourname.nativeapp.nxvmod",
  "minSdk": "1.10",
  "targetSdk": "1.16",
  "minNative": "1.2",
  "targetNative": "1.2",
  "window": {"width": 960, "height": 540, "resizable": true},
  "permissions": []
}
```

## 2. Skeleton (OpenGL + ImGui in the OS look)

**Choose the language first:** UI-heavy tools, utilities and productivity apps (chat clients, editors, settings, dashboards, store fronts) are written in Lua, JavaScript or Python with `nxui.*` / `ui.*` (the OS renderer and its text: the best typography, no build). Native C/C++ only for heavy computation (LLM inference, emulators, 3D engines, codecs, ports). A hybrid (native engine + script UI) is not possible yet: a script app cannot load native code.

```cpp
/* Native GL apps draw their UI with Dear ImGui + the FRAME LAYER of <nexvyn/nxn_os_ui.h> (the OS look). nxn_nxui_* never
 * paints in a GL window. Start from the app template (nxv_native new myapp --template app).
 * Setup once: ImGui::CreateContext(); nxn_imgui_enable_gamepad(io); nxn_ui_tokens_get(&tok);
 *             ImGui_ImplOpenGL3_Init("#version 330 core");          -- NO fonts, NO style code: the kit does both
 * Every frame (replaces ImGui_ImplOpenGL3_NewFrame / ImGui::NewFrame / ImGui::Render): */
nxn_os_frame_begin(&tok, (int)fb_w, (int)fb_h);   /* UI scale, fonts (text roles), style, full-window root */
nxn_os_text(NXN_OS_TEXT_TITLE, nxn_tr("title"));
nxn_os_card_begin("panel", tok);
    nxn_os_row_begin();                            /* one line: equal height, vertically centred */
        nxn_os_select("mode", modes, 3, &mode, nxn_os_fill(0.5f));
        if (nxn_os_button(nxn_tr("increment"), NXN_OS_BTN_PRIMARY, tok)) counter++;
        nxn_os_toggle_button(nxn_tr("web"), &web);
    nxn_os_row_end();
    nxn_os_switch_row(nxn_tr("sync"), &sync);
    nxn_os_labeled(nxn_tr("volume"), [&] { nxn_os_slider("vol", &volume, 0.0f, 1.0f, tok); });
    nxn_os_input("name", nxn_tr("name_hint"), name, sizeof name);
nxn_os_card_end();
nxn_os_frame_end();                               /* ImGui::Render() */
ImVec4 bg = nxn_os_clear_color(tok);              /* never a constant glClearColor */
glViewport(0, 0, fb_w, fb_h);
glClearColor(bg.x, bg.y, bg.z, 1.0f);
glClear(GL_COLOR_BUFFER_BIT);
ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
nxn_display_swap(disp);
/* Rules (python tools/nxv_native check-design / nxv.py check FAIL otherwise): no raw ImGui::Button / Combo / Checkbox /
 * SliderFloat / InputText (use nxn_os_*), no FontGlobalScale / SetWindowFontScale / AddFont*, every pixel number as
 * NXN_S(px) (spacing nxn_os_sp(NXN_OS_SP_M), widths nxn_os_fill(frac), 0 = the widget default). On NXN_EVENT_THEME
 * read the tokens again (nxn_ui_tokens_get); the kit re-applies the style itself. */
```

## 3. Core Native SDK Rules

- **Initialize every struct** with `NXN_STRUCT_INIT(type)` (sets `.size = sizeof(type)`).
- **Load GL functions** via `nxn_display_proc` (`gladLoadGLLoader((GLADloadproc)nxn_display_proc)`). Never link `libEGL` or `libGLESv2` directly in a windowed `.nxvmod`.
- **Handle `NXN_EVENT_RESIZE`** by calling `nxn_display_resize(disp, ev.width, ev.height)` so docked/handheld and window resizing work seamlessly.
- **Check capabilities (`nxn_caps_get(&caps)`)** before calling optional features (`NXN_CAP_WINDOW_CTL`, `NXN_CAP_POWER_STATE`, `NXN_CAP_DIALOG`, `NXN_CAP_JIT`, `NXN_CAP_SHARED_LIBS`).
- **Native SDK 1.2 system integration:**
  - `nxn_window_set_title(title, subtitle)`, `nxn_window_set_mode(NXN_WIN_MODE_WINDOW | NXN_WIN_MODE_MAXIMIZED | NXN_WIN_MODE_FULLSCREEN)`, `nxn_window_set_modified(dirty)`
  - `nxn_power_get(&power)` (`battery_percent`, `charger`, `docked`, `online`) and `NXN_EVENT_POWER`
  - `nxn_dialog(&dlg, &choice)` and `nxn_prompt(&pr, buf, cap, &len)`
- **NXUI Retained UI (`<nexvyn/nxn_nxui.h>`; does not paint in a Native GL window: `nxn_nxui_end_ex()` returns `NXN_ERR_UNSUPPORTED`, use ImGui + `<nexvyn/nxn_os_ui.h>` there):** `nxn_nxui_end_ex`, `nxn_nxui_tokens_get`, `nxn_nxui_begin`, `nxn_nxui_end`, `nxn_nxui_row_begin`/`end`, `nxn_nxui_column_begin`/`end`, `nxn_nxui_card_begin`/`end`, `nxn_nxui_scroll_begin`/`end`, `nxn_nxui_canvas_begin`/`end`, `nxn_nxui_label`, `nxn_nxui_badge`, `nxn_nxui_button`, `nxn_nxui_toggle`, `nxn_nxui_slider`, `nxn_nxui_textfield`, `nxn_nxui_dropdown`, `nxn_nxui_tabs`, `nxn_nxui_table`, `nxn_nxui_virtuallist`, `nxn_nxui_dialog`, `nxn_nxui_spacer`, `nxn_nxui_move_focus`, `nxn_nxui_activate_focused`.
- **Build & Check:**
  - `python SDK/Languages/c/native-kit/tools/nxv_native new myapp --template app`
  - `python SDK/Languages/c/native-kit/tools/nxv_native build myapp`
  - `python SDK/Languages/c/native-kit/tools/nxv_native package myapp`
