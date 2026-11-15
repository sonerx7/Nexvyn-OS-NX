# Language pack: Native C / C++ (`.nxvmod` — Frozen ABI v1, Native SDK 1.2)

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
  "targetSdk": "2.0",
  "minNative": "1.2",
  "targetNative": "2.0",
  "window": {"width": 960, "height": 540, "resizable": true},
  "permissions": []
}
```

## 2. Skeleton (OpenGL + Unified OS Design Kit `nxn_os_ui.h`)

For utility apps, editors, dashboards, and system tools, use `<nexvyn/nxn_imgui.h>` + `<nexvyn/nxn_os_ui.h>` parameterized live by `nxn_ui_tokens_get` so Light/Dark mode, accent color, grouped cards, switches, segmented tabs, and badges match Lua/JS/Python `ui.*` & `nxui.*` apps. (Games build their own art direction directly in OpenGL / NexGFX. Note: `nxn_nxui_*` in `nxn_nxui.h` runs layout/focus state only and does not paint inside an OpenGL `nxn_display` framebuffer.)

```cpp
#include <nexvyn/nexvyn_native.h>
#include <glad/glad.h>
#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nxn_imgui.h>
#include <nexvyn/nxn_os_ui.h>

static int app_main(int argc, char** argv) {
    (void)argc; (void)argv;
    nxn_display* disp = NULL;
    if (nxn_display_open(NULL, &disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "Failed to open display");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);

    uint32_t w = 960, h = 540;
    nxn_display_size(disp, &w, &h);
    nxn_ui_tokens tok = NXN_STRUCT_INIT(nxn_ui_tokens);
    nxn_ui_tokens_get(&tok);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    nxn_imgui_enable_gamepad(ImGui::GetIO());
    // Scale OS point sizes by 1.21x (Inter FreeType EM factor) so stb_truetype matches OS FreeType at 1:1 resolution
    float sc = tok.text_scale > 0.5f ? tok.text_scale : 1.0f;
    ImFont* f_body   = nxn_imgui_add_font(ImGui::GetIO().Fonts, NXN_UI_FONT_MEDIUM, floorf(13.8f * 1.21f * sc + 0.5f), 0, NULL);
    ImFont* f_card   = nxn_imgui_add_font(ImGui::GetIO().Fonts, NXN_UI_FONT_BOLD,   floorf(15.2f * 1.21f * sc + 0.5f), 0, NULL);
    ImFont* f_title  = nxn_imgui_add_font(ImGui::GetIO().Fonts, NXN_UI_FONT_BOLD,   floorf(19.2f * 1.21f * sc + 0.5f), 0, NULL);
    ImFont* f_small  = nxn_imgui_add_font(ImGui::GetIO().Fonts, NXN_UI_FONT_MEDIUM, floorf(12.0f * 1.21f * sc + 0.5f), 0, NULL);
    ImGui::GetIO().FontDefault = f_body;
    nxn_os_apply_style(tok);
    ImGui_ImplOpenGL3_Init("#version 330 core");

    int tab = 0;
    bool opt_on = true;
    const char* tabs[] = {nxn_tr("general"), nxn_tr("options")};

    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && nxn_display_resize(disp, ev.width, ev.height) == NXN_OK) {
                nxn_display_size(disp, &w, &h);
            } else if (ev.type == NXN_EVENT_THEME) {
                nxn_ui_tokens_get(&tok);
                nxn_os_apply_style(tok);
            }
            ev = NXN_STRUCT_INIT(nxn_event);
        }

        ImGui::GetIO().DisplaySize = ImVec2((float)w, (float)h);
        ImGui_ImplOpenGL3_NewFrame();
        ImGui::NewFrame();
        ImGui::SetNextWindowPos(ImVec2(0, 0));
        ImGui::SetNextWindowSize(ImVec2((float)w, (float)h));
        ImGui::Begin("##main", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings);
        nxn_os_segmented_tabs("nav", tabs, 2, &tab, tok);
        ImGui::Spacing();
        nxn_os_card_begin("panel", tok);
            nxn_os_kv_row(nxn_tr("title"), "Ready", tok, true);
            nxn_os_switch("opt_sw", &opt_on, tok);
            nxn_os_separator(tok);
            nxn_os_button(nxn_tr("apply"), NXN_OS_BTN_PRIMARY, tok);
        nxn_os_card_end();
        ImGui::End();
        ImGui::Render();

        glViewport(0, 0, (GLsizei)w, (GLsizei)h);
        ImVec4 bg = nxn_os_clear_color(tok);
        glClearColor(bg.x, bg.y, bg.z, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(disp);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui::DestroyContext();
    nxn_display_close(disp);
    return 0;
}

int main(int argc, char** argv) {
    return nxn_run(argc, argv, app_main, NULL);
}
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
- **Unified OS Widget Kit (`<nexvyn/nxn_os_ui.h>` + `<nexvyn/nxn_imgui.h>`):** `nxn_os_apply_style`, `nxn_os_clear_color`, `nxn_os_segmented_tabs`, `nxn_os_card_begin`/`end`, `nxn_os_kv_row`, `nxn_os_switch`, `nxn_os_dropdown`, `nxn_os_button`, `nxn_os_badge`, `nxn_os_progress_bar`, `nxn_os_separator`. Drives Dear ImGui from live `nxn_ui_tokens_get` for Light/Dark OS consistency. (`<nexvyn/nxn_nxui.h>` computes semantic layout/focus trees in memory and does not paint inside an OpenGL `nxn_display` framebuffer.)
- **Port Input (`<nexvyn/nxn_port_input.h>` & SDL2 Gestures):**
  - `"minNative": "1.2"` enables 16-finger multi-touch. `sdl2-nexvyn` automatically converts two-finger pinch-to-zoom to `SDL_MOUSEWHEEL` (or `Ctrl +/-` with `NEXVYN_PINCH_MODE=ctrl_pm`), two-finger tap & long-press to right-click, two-finger pan to scroll, and supports `NEXVYN_GAMEPAD_MOUSE=1` + `SDL_JoystickRumble`.
  - For non-SDL2 or custom PC/RTS/CRPG/FPS ports, `#include <nexvyn/nxn_port_input.h>` (`NXN_PI_PROFILE_RTS`, `CRPG`, `FPS`, `GAMEPAD`) gives ready-made pinch-zoom, gestures, stick cursor, and custom key/mouse bindings.
  - Call `SDL_StopTextInput()` (or `nxn_input_text_request(0)`) when no text field is active so the OSK stays hidden.
- **Build & Check:**
  - `python SDK/Languages/c/native-kit/tools/nxv_native new myapp --template app`
  - `python SDK/Languages/c/native-kit/tools/nxv_native build myapp`
  - `python SDK/Languages/c/native-kit/tools/nxv_native package myapp`
