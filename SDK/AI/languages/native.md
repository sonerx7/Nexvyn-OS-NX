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

## 2. Skeleton (OpenGL + NXUI Retained UI)

```c
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_nxui.h>
#include <glad/glad.h>

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
    int counter = 0;
    float slider_val = 0.5f;

    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && nxn_display_resize(disp, ev.width, ev.height) == NXN_OK) {
                nxn_display_size(disp, &w, &h);
                glViewport(0, 0, (GLsizei)w, (GLsizei)h);
            }
            ev.size = sizeof(ev);
        }

        glClearColor(0.08f, 0.10f, 0.14f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        /* NXUI Retained & Semantic UI overlay */
        nxn_nxui_begin((float)w, (float)h);
        nxn_nxui_card_begin("panel");
            nxn_nxui_label("title", nxn_tr("title"), NXN_NXUI_TEXT_TITLE);
            if (nxn_nxui_button("btn_add", "+1", NXN_NXUI_BTN_PRIMARY)) {
                counter++;
            }
            nxn_nxui_slider("sld", &slider_val, 0.0f, 1.0f);
        nxn_nxui_card_end();
        nxn_nxui_end();

        nxn_display_swap(disp);
    }

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
- **NXUI Retained UI (`<nexvyn/nxn_nxui.h>`):** `nxn_nxui_tokens_get`, `nxn_nxui_begin`, `nxn_nxui_end`, `nxn_nxui_row_begin`/`end`, `nxn_nxui_column_begin`/`end`, `nxn_nxui_card_begin`/`end`, `nxn_nxui_scroll_begin`/`end`, `nxn_nxui_canvas_begin`/`end`, `nxn_nxui_label`, `nxn_nxui_badge`, `nxn_nxui_button`, `nxn_nxui_toggle`, `nxn_nxui_slider`, `nxn_nxui_textfield`, `nxn_nxui_dropdown`, `nxn_nxui_tabs`, `nxn_nxui_table`, `nxn_nxui_virtuallist`, `nxn_nxui_dialog`, `nxn_nxui_spacer`, `nxn_nxui_move_focus`, `nxn_nxui_activate_focused`.
- **Build & Check:**
  - `python SDK/Languages/c/native-kit/tools/nxv_native new myapp --template app`
  - `python SDK/Languages/c/native-kit/tools/nxv_native build myapp`
  - `python SDK/Languages/c/native-kit/tools/nxv_native package myapp`
