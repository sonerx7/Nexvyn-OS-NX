// App template: a small real UI app in the look of Nexvyn OS.
//   - colours, sizes and fonts come from the system (nxn_ui_tokens_get, nxn_ui_font_get): the app follows the theme,
//     the accent colour and the accessibility settings, and updates when NXN_EVENT_THEME arrives
//   - every text is a key of lang/<code>.json (nxn_tr): add a language by adding a file; lang/en.json is required
//   - a file picker (nxn_pick) and a setting kept between runs (nxn_fs_write / nxn_fs_read in the data folder)
// Controls: touch or mouse, D-pad + A (the user's confirm button), B or the window's close button to leave.
#include <glad/glad.h>
#include <float.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <nexvyn/nexvyn_native.h>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nxn_imgui.h>

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

// ---- the OS look: ImGui colours from the tokens
static ImVec4 col(uint32_t argb) {
    return ImVec4(((argb >> 16) & 255) / 255.f, ((argb >> 8) & 255) / 255.f, (argb & 255) / 255.f, ((argb >> 24) & 255) / 255.f);
}
static void apply_tokens() {
    nxn_ui_tokens_get(&g_tok);
    ImGuiStyle& s = ImGui::GetStyle();
    ImVec4* c = s.Colors;
    c[ImGuiCol_WindowBg] = col(g_tok.window_bg);
    c[ImGuiCol_ChildBg] = col(g_tok.content_bg);
    c[ImGuiCol_Text] = col(g_tok.text);
    c[ImGuiCol_TextDisabled] = col(g_tok.text_secondary);
    c[ImGuiCol_Border] = col(g_tok.border);
    c[ImGuiCol_Separator] = col(g_tok.separator);
    c[ImGuiCol_Button] = col(g_tok.surface);
    c[ImGuiCol_ButtonHovered] = col(g_tok.surface_hover);
    c[ImGuiCol_ButtonActive] = col(g_tok.surface_pressed);
    c[ImGuiCol_FrameBg] = col(g_tok.field_bg);
    c[ImGuiCol_FrameBgHovered] = col(g_tok.surface_hover);
    c[ImGuiCol_FrameBgActive] = col(g_tok.surface_pressed);
    c[ImGuiCol_CheckMark] = col(g_tok.accent);
    c[ImGuiCol_Header] = col(g_tok.selection);
    c[ImGuiCol_NavHighlight] = col(g_tok.accent);
    s.FrameRounding = g_tok.corner_radius;
    s.WindowRounding = 0;
    s.ItemSpacing = ImVec2(g_tok.spacing[2], g_tok.spacing[1]);
    s.FramePadding = ImVec2(g_tok.spacing[2], g_tok.spacing[1] * 0.75f);
}

static void setup_fonts() {
    // the system font with the glyph ranges of the user's language (nxn_imgui.h): Turkish "ı ğ ş İ" and the other
    // languages' letters are not drawn as "?" (ImGui itself loads Latin-1 only)
    float px = g_tok.font_body > 1.f ? g_tok.font_body : 16.f;
    nxn_imgui_add_font(ImGui::GetIO().Fonts, NXN_UI_FONT_SANS, px, 0, NULL);
}

// ---- input: the game pad and the first finger drive ImGui
static void feed_imgui(float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)g_w, (float)g_h);
    io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
    io.AddKeyEvent(ImGuiKey_GamepadFaceDown, (g_in.actions & NXN_ACT_CONFIRM) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadLeft, (g_in.buttons & NXN_BTN_LEFT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadRight, (g_in.buttons & NXN_BTN_RIGHT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadUp, (g_in.buttons & NXN_BTN_UP) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadDown, (g_in.buttons & NXN_BTN_DOWN) != 0);
    static int was_down;
    nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
    if (g_in.touch_count > 0 && nxn_input_touch(0, &t) == NXN_OK) {
        io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
        io.AddMousePosEvent(t.x, t.y);
        io.AddMouseButtonEvent(0, true);
        was_down = 1;
    } else if (was_down) {
        io.AddMouseButtonEvent(0, false);
        io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
        was_down = 0;
    }
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
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(ImVec2((float)g_w, (float)g_h));
    ImGui::Begin("##main", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings);
    ImGui::SetWindowFontScale(g_tok.text_scale * (g_set.large_text ? 1.25f : 1.f));

    ImGui::TextColored(col(g_tok.accent), "%s", nxn_tr("title"));
    ImGui::Separator();

    ImGui::TextDisabled("%s", nxn_tr("files.heading"));
    if (ImGui::Button(nxn_tr("files.open"))) choose_file();
    if (g_path[0]) {
        ImGui::TextWrapped("%s", g_path);
        if (g_file_size >= 0) {
            char num[32], text[96];
            snprintf(num, sizeof num, "%ld", g_file_size);
            const char* args[1] = {num};
            if (nxn_tr_format("files.size", text, sizeof text, args, 1) == NXN_OK) ImGui::TextDisabled("%s", text);
        }
    } else {
        ImGui::TextDisabled("%s", nxn_tr("files.none"));
    }

    ImGui::Spacing();
    ImGui::TextDisabled("%s", nxn_tr("settings.heading"));
    {
        char num[16], text[96];
        snprintf(num, sizeof num, "%d", g_set.opened);
        const char* args[1] = {num};
        if (nxn_tr_format("settings.counter", text, sizeof text, args, 1) == NXN_OK) ImGui::TextUnformatted(text);
    }
    if (ImGui::Button(nxn_tr("settings.reset"))) {
        g_set.opened = 0;
        settings_save();
    }
    bool large = g_set.large_text != 0;
    if (ImGui::Checkbox(nxn_tr("settings.large_text"), &large)) {
        g_set.large_text = large ? 1 : 0;
        settings_save();
    }

    ImGui::Spacing();
    if (ImGui::Button(nxn_tr("quit"))) quit = true;
    ImGui::End();
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

    nxn_ui_tokens_get(&g_tok);
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    nxn_imgui_enable_gamepad(io);
    setup_fonts();
    apply_tokens();
    ImGui_ImplOpenGL3_Init("#version 330 core");

    uint64_t last = nxn_time_ns();
    bool quit = false;
    while (!quit && !nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
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
        ImGui_ImplOpenGL3_NewFrame();
        ImGui::NewFrame();
        if (draw_ui()) quit = true;
        ImGui::Render();
        glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
        glDisable(GL_SCISSOR_TEST);
        ImVec4 bg = col(g_tok.window_bg);
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
