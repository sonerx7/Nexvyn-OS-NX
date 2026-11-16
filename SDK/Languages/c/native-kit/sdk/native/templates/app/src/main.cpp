// App template: a small real UI app in the look of Nexvyn OS.
//   - the frame layer of nxn_os_ui.h (nxn_os_frame_begin / nxn_os_frame_end) owns the UI scale, the fonts (text roles),
//     the style and the minimum control sizes: the app follows the theme, the accent colour, the interface size and the
//     accessibility settings without code of its own. Widgets are nxn_os_*; any pixel size goes through NXN_S().
//   - UI-heavy tools are often better as a Lua / JavaScript / Python app (the OS renderer); a native app is for heavy
//     work (see "Choosing a language" in the SDK guide)
//   - every text is a key of lang/<code>.json (nxn_tr): add a language by adding a file; lang/en.json is required
//   - a file picker (nxn_pick) and a setting kept between runs (nxn_fs_write / nxn_fs_read in the data folder)
// Controls: touch or mouse, D-pad + A (the user's confirm button), B or the window's close button to leave.
#include <glad/glad.h>
#include <float.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <nexvyn/nexvyn_native.h>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nxn_os_ui.h>

static nxn_display* g_disp;
static uint32_t g_w = 720, g_h = 480;
static nxn_ui_tokens g_tok = NXN_STRUCT_INIT(nxn_ui_tokens);
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);

// ---- settings kept between runs: a tiny text file in the app's data folder
struct Settings {
    int opened = 0;
    int large_text = 0;
};
static Settings g_set;

static void settings_load() {
    char buf[64] = {0};
    size_t got = 0;
    if (nxn_fs_read(NXN_DIR_DATA, "settings.txt", buf, sizeof buf - 1, &got) == NXN_OK && got > 0)
        sscanf(buf, "%d %d", &g_set.opened, &g_set.large_text);  // a missing or damaged file is just the defaults
}
static void settings_save() {
    char buf[64];
    int n = snprintf(buf, sizeof buf, "%d %d\n", g_set.opened, g_set.large_text);
    if (nxn_fs_write(NXN_DIR_DATA, "settings.txt", buf, (size_t)n) != NXN_OK) nxn_log(NXN_LOG_WARN, "settings not saved");
}

// ---- the OS look: live OS tokens (colours for the nxn_os_* widgets). The frame layer reads them too and builds the
// fonts with the glyphs of the user's language (Turkish "Ä± ÄŸ ÅŸ Ä°", Cyrillic, CJK ...): the app adds no fonts.
static void apply_tokens() { nxn_ui_tokens_get(&g_tok); }

// ---- input: the game pad and the first finger drive ImGui
static void feed_imgui(float dt) {
    static nxn_imgui_input_state backend;
    nxn_imgui_input(backend, g_in, dt);
}

// ---- the UI
static char g_path[512];
static long g_file_size = -1;

static void choose_file() {
    nxn_pick_params p = NXN_STRUCT_INIT(nxn_pick_params);
    p.kind = NXN_PICK_OPEN_FILE;
    p.title = nxn_tr("files.open");
    // nxn_pick waits for the user: it keeps the app "alive" for the not-responding check. A frame loop that must keep
    // drawing while the dialog is open calls it from a worker thread instead.
    char path[512];
    if (nxn_pick(&p, path, sizeof path) != NXN_OK) return;  // cancelled, or the window is closing
    snprintf(g_path, sizeof g_path, "%s", path);
    g_file_size = -1;
    if (FILE* f = fopen(g_path, "rb")) {
        if (fseek(f, 0, SEEK_END) == 0) g_file_size = ftell(f);
        fclose(f);
    }
}

static bool draw_ui() {
    bool quit = false;
    nxn_os_set_text_zoom(g_set.large_text ? 1.25f : 1.f);  // the app's own "Large text": fonts rebuilt, never stretched

    nxn_os_row_begin();
    nxn_os_text(NXN_OS_TEXT_TITLE, nxn_tr("title"));
    nxn_os_badge(nxn_tr("kit"), g_tok.accent, g_tok);
    nxn_os_row_end();
    nxn_os_separator(g_tok);
    nxn_os_gap(NXN_OS_SP_S);

    nxn_os_section_label(nxn_tr("files.heading"), g_tok);
    nxn_os_card_begin("files_card", g_tok);
    if (nxn_os_button(nxn_tr("files.open"), NXN_OS_BTN_PRIMARY, g_tok)) choose_file();
    if (g_path[0]) {
        nxn_os_separator(g_tok);
        nxn_os_text_wrapped(NXN_OS_TEXT_BODY, g_path);
        if (g_file_size >= 0) {
            char num[32], text[96];
            snprintf(num, sizeof num, "%ld", g_file_size);
            const char* args[1] = {num};
            if (nxn_tr_format("files.size", text, sizeof text, args, 1) == NXN_OK)
                nxn_os_kv_row(nxn_tr("size_label"), text, g_tok, false);
        }
    } else {
        nxn_os_text(NXN_OS_TEXT_CAPTION, nxn_tr("files.none"));
    }
    nxn_os_card_end();

    nxn_os_gap(NXN_OS_SP_S);
    nxn_os_section_label(nxn_tr("settings.heading"), g_tok);
    nxn_os_card_begin("settings_card", g_tok);
    {
        char num[16], text[96];
        snprintf(num, sizeof num, "%d", g_set.opened);
        const char* args[1] = {num};
        if (nxn_tr_format("settings.counter", text, sizeof text, args, 1) == NXN_OK) {
            nxn_os_kv_row(text, num, g_tok, true);
        }
    }
    bool large = g_set.large_text != 0;
    if (nxn_os_switch_row(nxn_tr("settings.large_text"), &large)) {
        g_set.large_text = large ? 1 : 0;
        settings_save();
    }
    nxn_os_separator(g_tok);
    if (nxn_os_button(nxn_tr("settings.reset"), NXN_OS_BTN_DEFAULT, g_tok)) {
        g_set.opened = 0;
        settings_save();
    }
    nxn_os_card_end();

    nxn_os_gap(NXN_OS_SP_S);
    if (nxn_os_button(nxn_tr("quit"), NXN_OS_BTN_DESTRUCTIVE, g_tok)) quit = true;
    return quit;
}

static int app_main(int, char**) {
    if (nxn_display_open(NULL, &g_disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL is not available");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h);

    settings_load();
    g_set.opened++;
    settings_save();

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    nxn_imgui_enable_gamepad(io);
    apply_tokens();
    ImGui_ImplOpenGL3_Init("#version 330 core");

    uint64_t last = nxn_time_ns();
    bool quit = false;
    while (!quit && !nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            nxn_imgui_input_event(ev);
            if (ev.type == NXN_EVENT_RESIZE) {
                if (nxn_display_resize(g_disp, ev.width, ev.height) == NXN_OK) nxn_display_size(g_disp, &g_w, &g_h);
            } else if (ev.type == NXN_EVENT_THEME) {
                apply_tokens();
            } else if (ev.type == NXN_EVENT_QUIT) {
                quit = true;
            }
            ev = NXN_STRUCT_INIT(nxn_event);
        }
        nxn_input_poll(&g_in);
        if (g_in.actions & NXN_ACT_CANCEL) quit = true;

        uint64_t now = nxn_time_ns();
        feed_imgui((float)((now - last) / 1e9));
        last = now;
        nxn_os_frame_begin(&g_tok, (int)g_w, (int)g_h);  // scale, fonts, style, ImGui frame, root window
        if (draw_ui()) quit = true;
        nxn_os_frame_end();                              // ImGui::Render()
        glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
        glDisable(GL_SCISSOR_TEST);
        ImVec4 bg = nxn_os_clear_color(g_tok);
        glClearColor(bg.x, bg.y, bg.z, 1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(g_disp);
    }
    ImGui_ImplOpenGL3_Shutdown();
    ImGui::DestroyContext();
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
