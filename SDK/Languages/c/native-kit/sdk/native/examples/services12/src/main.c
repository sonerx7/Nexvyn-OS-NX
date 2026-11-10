/* Native 1.2 services sample: window control (nxn_window.h), power / network state (nxn_power.h) and OS dialogs (nxn_dialog.h). Windowed only.
 *
 *   A       full screen on / off          (nxn_window_set_mode)
 *   B       maximized on / off
 *   X       "unsaved work" mark on / off  (nxn_window_set_modified: the OS "edited" mark in the title)
 *   Y       a new subtitle                (nxn_window_set_title)
 *   L       an OS question with three buttons (nxn_dialog)
 *   R       an OS text prompt for the subtitle (nxn_prompt)
 *   (both wait for the user: the app thread is paused, the OS keeps drawing)
 * The picture's brightness follows the battery; the log says when the battery, charger, dock or network changed
 * (NXN_EVENT_POWER, only for an app.json "minNative" of 1.2).
 * Every call is checked against NXN_CAP_WINDOW_CTL first, so the same build still runs on a system without it. */
#include <nexvyn/nexvyn_native.h>
#include <stdio.h>

typedef void (*clear_color_fn)(float, float, float, float);
typedef void (*clear_fn)(unsigned);

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    int has_ctl = (caps.features & NXN_CAP_WINDOW_CTL) != 0;
    int has_dialog = (caps.features & NXN_CAP_DIALOG) != 0;
    int has_power = (caps.features & NXN_CAP_POWER_STATE) != 0;
    nxn_power pw = NXN_STRUCT_INIT(nxn_power);
    pw.percent = -1;
    if (has_power) nxn_power_get(&pw);
    nxn_log(NXN_LOG_INFO, "window control: %s", has_ctl ? "yes" : "no");

    nxn_display* d = NULL;
    if (nxn_display_open(NULL, &d) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL is not available");
        return 1;
    }
    clear_color_fn clear_color = (clear_color_fn)nxn_display_proc("glClearColor");
    clear_fn clear = (clear_fn)nxn_display_proc("glClear");

    int fullscreen = 0, maximized = 0, modified = 0, level = 0;
    if (has_ctl) nxn_window_set_title("Services Sample", "Level 0");
    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE) nxn_display_resize(d, ev.width, ev.height);
            if (ev.type == NXN_EVENT_POWER && has_power) {
                nxn_power_get(&pw);
                nxn_log(NXN_LOG_INFO, "power: %d%% charging=%u docked=%u online=%u", (int)pw.percent, pw.charging, pw.docked, pw.online);
            }
            ev.size = sizeof ev;
        }
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        if (has_ctl) {
            if (in.pressed & NXN_BTN_A) {
                fullscreen = !fullscreen;
                nxn_window_set_mode(fullscreen ? NXN_WIN_FULLSCREEN : NXN_WIN_NORMAL);
            }
            if (in.pressed & NXN_BTN_B) {
                maximized = !maximized;
                nxn_window_set_mode(maximized ? NXN_WIN_MAXIMIZED : NXN_WIN_NORMAL);
            }
            if (in.pressed & NXN_BTN_X) nxn_window_set_modified(modified = !modified);
            if (in.pressed & NXN_BTN_Y) {
                char sub[32];
                snprintf(sub, sizeof sub, "Level %d", ++level);
                nxn_window_set_title("Services Sample", sub);
            }
        }
        if (has_dialog && (in.pressed & NXN_BTN_L)) {
            const char* labels[] = {"Overwrite", "Keep both", "Cancel"};
            nxn_dialog_params dp = NXN_STRUCT_INIT(nxn_dialog_params);
            dp.title = "Overwrite the file?";
            dp.message = "A file with this name already exists.\nWhat should happen?";
            dp.buttons = labels;
            dp.button_count = 3;
            dp.danger_button = 0; /* drawn in the destructive style */
            dp.cancel_button = 2; /* Esc / B */
            uint32_t picked = 0;
            nxn_result r = nxn_dialog(&dp, &picked);
            nxn_log(NXN_LOG_INFO, "dialog: result %d, picked %u", (int)r, picked);
        }
        if (has_dialog && (in.pressed & NXN_BTN_R)) {
            char text[64];
            nxn_result r = nxn_prompt("Subtitle", "Text for the title bar:", "Level", text, sizeof text);
            nxn_log(NXN_LOG_INFO, "prompt: result %d, text \"%s\"", (int)r, r == NXN_OK ? text : "");
            if (r == NXN_OK && has_ctl) nxn_window_set_title("Services Sample", text);
        }
        if (clear_color && clear) {
            float lvl = pw.percent >= 0 ? 0.15f + 0.5f * (float)pw.percent / 100.f : 0.35f;
            clear_color(modified ? 0.45f : 0.1f, 0.2f, fullscreen ? 0.6f : lvl, 1.f);
            clear(0x4000); /* GL_COLOR_BUFFER_BIT */
        }
        nxn_display_swap(d);
    }
    nxn_display_close(d);
    return 0;
}
