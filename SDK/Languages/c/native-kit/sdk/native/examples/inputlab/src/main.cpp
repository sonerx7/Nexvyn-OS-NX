// Input Lab (Native C++): interaction and responsive-layout parity canary for all SDK lanes.
// Canonical metrics (OS pixels at scale 1): margin 20, card padding 16x13, card radius 10, button 30 (radius 6),
// segmented 32, switch 38x22, dropdown 30, text field 30, slider 22, badge 22 (radius 11, min width 58), progress 6, row 30.
// The frame layer of nxn_os_ui.h owns the rest: UI scale, the text roles (Title / Header / Body / Caption, pixel size
// floor(pt * 1.21 + 0.5) x scale), the font atlas and the style. Every size below goes through NXN_S().
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
static uint32_t g_w = 860, g_h = 560;
static nxn_ui_tokens g_tok = NXN_STRUCT_INIT(nxn_ui_tokens);
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);

// canonical metrics (OS pixels; NXN_S() turns them into surface pixels)
static const float MARGIN = 20.f, PADX = 16.f, PADY = 13.f;
static const float BTN_H = 30.f, SEG_H = 32.f, SW_W = 38.f, SW_H = 22.f, FIELD_H = 30.f, BADGE_H = 22.f, PROG_H = 6.f, ROW_H = 30.f;
static const float BTN_W = 96.f, DROP_W = 200.f, GAP = 12.f, BTN_GAP = 10.f;

static void apply_tokens() { nxn_ui_tokens_get(&g_tok); }  // the frame layer applies the style every frame

static void feed_imgui(float dt) {
    static nxn_imgui_input_state backend;
    nxn_imgui_input(backend, g_in, dt);
}

// The same interaction inventory as the Lua/JS/Python Input Lab.
static float volume = 0.5f;
static float zoom = 1.0f, angle = 0.0f;
static void update_gesture() {
    static bool previous = false;
    static uint32_t id0 = 0, id1 = 0;
    static float distance = 0, direction = 0;
    nxn_touch a = NXN_STRUCT_INIT(nxn_touch), b = NXN_STRUCT_INIT(nxn_touch);
    if (g_in.touch_count != 2 || nxn_input_touch(0, &a) != NXN_OK || nxn_input_touch(1, &b) != NXN_OK) {
        previous = false; return;
    }
    float dx = b.x - a.x, dy = b.y - a.y;
    float d = sqrtf(dx * dx + dy * dy), r = atan2f(dy, dx);
    if (previous && id0 == a.id && id1 == b.id && distance > 1.0f && d > 1.0f) {
        zoom = fmaxf(0.25f, fminf(4.0f, zoom * d / distance));
        angle += atan2f(sinf(r - direction), cosf(r - direction));
    }
    id0 = a.id; id1 = b.id; distance = d; direction = r; previous = true;
}
static char name[96] = "";
static int mode = 0;
static void draw_ui() {
    bool compact = g_w < NXN_S(620);
    float shift = compact ? NXN_S(46) : 0;
    static uint32_t lastw = 0, lasth = 0;
    if (lastw != g_w || lasth != g_h) {
        char layout[80]; snprintf(layout, sizeof layout, "Layout %s %u %u", compact ? "compact" : "wide", (unsigned)g_w, (unsigned)g_h);
        nxn_log(NXN_LOG_INFO, layout); lastw = g_w; lasth = g_h;
    }
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(16)));
    nxn_os_text(NXN_OS_TEXT_TITLE, nxn_tr("title"));
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(48)));
    nxn_os_text(NXN_OS_TEXT_BODY, nxn_tr(compact ? "hint.compact" : "hint.wide"));
    const char* const modes[] = {nxn_tr("mode.touch"), nxn_tr("mode.pad"), nxn_tr("mode.keyboard")};
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(80)));
    nxn_os_row_begin(NXN_S(30), NXN_S(20));
    nxn_os_dropdown("mode", modes, 3, &mode, NXN_S(230), g_tok);
    if (!compact) nxn_os_input("name", nxn_tr("placeholder"), name, sizeof name, nxn_os_fill());
    nxn_os_row_end();
    if (compact) {
        ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(126)));
        nxn_os_input("name", nxn_tr("placeholder"), name, sizeof name, nxn_os_fill());
    }
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(126) + shift));
    nxn_os_slider("volume", &volume, 0, 1, g_tok, nxn_os_fill(), NXN_S(24));
    update_gesture();
    char status[160];
    snprintf(status, sizeof status, "Value %.2f | Pinch %.2f | Rotation %.2f | Fingers %u", volume, zoom, angle, (unsigned)g_in.touch_count);
    static char last[160] = "";
    if (strcmp(last, status)) { nxn_log(NXN_LOG_INFO, status); snprintf(last, sizeof last, "%s", status); }
    if (compact) snprintf(status, sizeof status, "%s %.2f | %s %.2f", nxn_tr("value"), volume, nxn_tr("pinch"), zoom);
    else snprintf(status, sizeof status, "%s %.2f | %s %.2f | %s %.2f | %s %u",
                  nxn_tr("value"), volume, nxn_tr("pinch"), zoom, nxn_tr("rotation"), angle,
                  nxn_tr("fingers"), (unsigned)g_in.touch_count);
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(164) + shift));
    nxn_os_text(NXN_OS_TEXT_BODY, status);
    ImGui::SetCursorPos(ImVec2(NXN_S(20), NXN_S(200) + shift));
    ImGui::PushStyleColor(ImGuiCol_ChildBg, nxn_os_imvec4(g_tok.window_bg));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
    ImGui::BeginChild("outer", ImVec2(0, (float)g_h - NXN_S(220) - shift));
    ImGui::SetCursorPos(ImVec2(NXN_S(12), NXN_S(8)));
    nxn_os_text(NXN_OS_TEXT_HEADER, nxn_tr(compact ? "frame.compact" : "frame.wide"));
    ImGui::SetCursorPos(ImVec2(NXN_S(12), NXN_S(44)));
    ImGui::BeginChild("inner", ImVec2(ImGui::GetWindowWidth() - NXN_S(50), NXN_S(180)));
    for (int i = 0; i < 20; ++i) {
        char label[96]; snprintf(label, sizeof label, "%s %d", nxn_tr("row.inner"), i + 1);
        ImGui::SetCursorPos(ImVec2(NXN_S(8), NXN_S(i * 44)));
        nxn_os_button(label, NXN_OS_BTN_DEFAULT, g_tok, ImVec2(ImGui::GetWindowWidth() - NXN_S(40), NXN_S(36)));
    }
    ImGui::EndChild();
    for (int i = 0; i < 18; ++i) {
        char label[96]; snprintf(label, sizeof label, "%s %d", nxn_tr("row.outer"), i + 1);
        ImGui::SetCursorPos(ImVec2(NXN_S(12), NXN_S(244 + i * 44)));
        nxn_os_button(label, NXN_OS_BTN_DEFAULT, g_tok, ImVec2(ImGui::GetWindowWidth() - NXN_S(50), NXN_S(36)));
    }
    ImGui::EndChild();
    ImGui::PopStyleVar();
    ImGui::PopStyleColor();
}

static int app_main(int, char**) {
    if (nxn_display_open(NULL, &g_disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, nxn_tr("error.gl"));
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h);

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


        uint64_t now = nxn_time_ns();
        feed_imgui((float)((now - last) / 1e9));
        last = now;
        nxn_os_frame_begin(&g_tok, (int)g_w, (int)g_h);  // scale, fonts, style, ImGui frame, root window
        draw_ui();
        nxn_os_frame_end();
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
