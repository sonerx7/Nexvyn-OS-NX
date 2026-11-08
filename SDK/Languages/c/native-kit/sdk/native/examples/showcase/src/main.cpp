/* Native SDK Showcase - one app that shows every Native SDK feature and self-tests it (see README.md).
 *
 * UI: Dear ImGui with its OpenGL3 renderer; the platform side is a small glue fed by nxn_input / nxn_event (no SDL2,
 * which windowed mode does not offer). The same source builds for both modes (NEXVYN_WINDOWED is set by the kit for
 * windowed builds). L / R switch pages, D-pad + A navigate, touch works as a mouse.
 * Self-test: when <data>/autotest exists the app runs everything, writes showcase_report.txt and returns code 7.
 * <data>/rtonly: only the runtime rows (W2a), then a clean end; <data>/throwtest: an exception nobody catches. */
#include "showcase.h"
#include <glad/glad.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nxn_imgui.h>

#ifdef NEXVYN_WINDOWED
#define SC_MODE "windowed"
#else
#define SC_MODE "exclusive"
#endif

/* ------------------------------------------------------------------ state */
static nxn_display* g_disp;
static uint32_t g_w = 1280, g_h = 720;
static nxn_audio* g_audio;
nxn_caps g_caps = NXN_STRUCT_INIT(nxn_caps); // tests.cpp, tests_rt.cpp read it too
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static int g_page, g_want_page = -1;
static char g_glinfo[3][160];

static double g_fps, g_ms;
static int g_frames;
static int g_resize_events, g_focus_events, g_last_docked = -1;
static int g_key_events, g_text_bytes, g_mouse_clicks, g_suspend_events, g_resume_events, g_dock_events, g_theme_events;
static uint32_t g_last_w, g_last_h;
static int g_focused = 1;
static char g_evlog[8][96];
static int g_evn;

static float g_cube_rect[4]; /* x, y, w, h in framebuffer pixels (top-left origin) */
static int g_cube_on;

static void ev_log(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void ev_log(const char* fmt, ...) {
    char* slot = g_evlog[g_evn++ % 8];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(slot, 96, fmt, ap);
    va_end(ap);
}

/* ------------------------------------------------------------------ 3D cube (own GL program) */
static GLuint g_prog, g_vao, g_vbo;
static GLint g_u_mvp, g_u_model;

static const char* kVert =
    "#version 330 core\n"
    "layout(location = 0) in vec3 pos;\n"
    "layout(location = 1) in vec3 nrm;\n"
    "uniform mat4 mvp;\n"
    "uniform mat4 model;\n"
    "out vec3 n;\n"
    "void main() { gl_Position = mvp * vec4(pos, 1.0); n = mat3(model) * nrm; }\n";
static const char* kFrag =
    "#version 330 core\n"
    "in vec3 n;\n"
    "out vec4 o;\n"
    "void main() {\n"
    "  vec3 nn = normalize(n);\n"
    "  vec3 base = abs(nn) * 0.55 + vec3(0.35);\n"
    "  float l = 0.35 + 0.65 * max(dot(nn, normalize(vec3(0.5, 0.8, 0.6))), 0.0);\n"
    "  o = vec4(base * l, 1.0);\n"
    "}\n";

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        nxn_log(NXN_LOG_ERROR, "shader: %s", log);
    }
    return s;
}

static void cube_init(void) {
    static const float face[6][4][3] = {
        {{1, -1, -1}, {1, 1, -1}, {1, 1, 1}, {1, -1, 1}},     {{-1, -1, 1}, {-1, 1, 1}, {-1, 1, -1}, {-1, -1, -1}},
        {{-1, 1, -1}, {-1, 1, 1}, {1, 1, 1}, {1, 1, -1}},     {{-1, -1, 1}, {-1, -1, -1}, {1, -1, -1}, {1, -1, 1}},
        {{-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}},     {{1, -1, -1}, {-1, -1, -1}, {-1, 1, -1}, {1, 1, -1}}};
    static const float nrm[6][3] = {{1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0}, {0, 0, 1}, {0, 0, -1}};
    static const int idx[6] = {0, 1, 2, 0, 2, 3};
    float v[36 * 6];
    int k = 0;
    for (int f = 0; f < 6; f++)
        for (int i = 0; i < 6; i++) {
            memcpy(v + k, face[f][idx[i]], 12);
            memcpy(v + k + 3, nrm[f], 12);
            k += 6;
        }
    g_prog = glCreateProgram();
    glAttachShader(g_prog, compile(GL_VERTEX_SHADER, kVert));
    glAttachShader(g_prog, compile(GL_FRAGMENT_SHADER, kFrag));
    glLinkProgram(g_prog);
    g_u_mvp = glGetUniformLocation(g_prog, "mvp");
    g_u_model = glGetUniformLocation(g_prog, "model");
    glGenVertexArrays(1, &g_vao);
    glGenBuffers(1, &g_vbo);
    glBindVertexArray(g_vao);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof v, v, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 24, (void*)0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 24, (void*)12);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
}

/* column-major 4x4 helpers */
static void mat_mul(float* o, const float* a, const float* b) {
    float t[16];
    for (int c = 0; c < 4; c++)
        for (int r = 0; r < 4; r++) {
            float s = 0;
            for (int k = 0; k < 4; k++) s += a[k * 4 + r] * b[c * 4 + k];
            t[c * 4 + r] = s;
        }
    memcpy(o, t, sizeof t);
}
static void mat_rot(float* m, int axis, float a) {
    memset(m, 0, 64);
    m[0] = m[5] = m[10] = m[15] = 1;
    float c = cosf(a), s = sinf(a);
    int i = (axis + 1) % 3, j = (axis + 2) % 3;
    m[i * 4 + i] = c;
    m[j * 4 + j] = c;
    m[j * 4 + i] = -s;
    m[i * 4 + j] = s;
}

/* runs inside ImGui's draw list: draws the cube into g_cube_rect, clipped to the command's clip rect */
static void cube_callback(const ImDrawList*, const ImDrawCmd* cmd) {
    float x0 = fmaxf(g_cube_rect[0], cmd->ClipRect.x), y0 = fmaxf(g_cube_rect[1], cmd->ClipRect.y);
    float x1 = fminf(g_cube_rect[0] + g_cube_rect[2], cmd->ClipRect.z), y1 = fminf(g_cube_rect[1] + g_cube_rect[3], cmd->ClipRect.w);
    if (x1 <= x0 || y1 <= y0) return;
    glEnable(GL_SCISSOR_TEST);
    glScissor((GLint)x0, (GLint)((float)g_h - y1), (GLsizei)(x1 - x0), (GLsizei)(y1 - y0));
    glViewport((GLint)g_cube_rect[0], (GLint)((float)g_h - g_cube_rect[1] - g_cube_rect[3]), (GLsizei)g_cube_rect[2], (GLsizei)g_cube_rect[3]);
    glClearColor(0.05f, 0.06f, 0.09f, 1.f);
    glClearDepth(1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glEnable(GL_DEPTH_TEST);
    glDisable(GL_BLEND);
    glDisable(GL_CULL_FACE);
    float t = (float)(nxn_time_ns() / 1000000) / 1000.f;
    float ry[16], rx[16], model[16], view[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, -4.2f, 1}, proj[16] = {0}, mv[16], mvp[16];
    mat_rot(ry, 1, t * 0.9f);
    mat_rot(rx, 0, t * 0.55f + 0.4f);
    mat_mul(model, rx, ry);
    float aspect = g_cube_rect[2] / fmaxf(g_cube_rect[3], 1.f), f = 1.f / tanf(0.4f);
    proj[0] = f / aspect;
    proj[5] = f;
    proj[10] = (20.f + 0.1f) / (0.1f - 20.f);
    proj[11] = -1.f;
    proj[14] = 2.f * 20.f * 0.1f / (0.1f - 20.f);
    mat_mul(mv, view, model);
    mat_mul(mvp, proj, mv);
    glUseProgram(g_prog);
    glUniformMatrix4fv(g_u_mvp, 1, GL_FALSE, mvp);
    glUniformMatrix4fv(g_u_model, 1, GL_FALSE, model);
    glBindVertexArray(g_vao);
    glDrawArrays(GL_TRIANGLES, 0, 36);
    glBindVertexArray(0);
    glDisable(GL_DEPTH_TEST);
}

/* ------------------------------------------------------------------ audio */
static int g_tone_on;
static float g_tone_hz = 440.f, g_tone_pan; /* pan -1 (left) .. 1 (right) */
static double g_tone_phase;

static void tone_fill(int16_t* out, int frames) {
    float a = (g_tone_pan + 1.f) * 0.7853982f; /* equal power pan */
    float gl = cosf(a), gr = sinf(a);
    for (int i = 0; i < frames; i++) {
        float v = sinf((float)g_tone_phase) * 7000.f;
        g_tone_phase += 6.2831853 * g_tone_hz / 48000.0;
        if (g_tone_phase > 6.2831853 * 1000) g_tone_phase -= 6.2831853 * 1000;
        out[i * 2] = (int16_t)(v * gl);
        out[i * 2 + 1] = (int16_t)(v * gr);
    }
}

static void tone_pump(void) {
    if (!g_audio || !g_tone_on) return;
    static int16_t buf[1024 * 2];
    int pushed = 0;
    while (nxn_audio_queued_bytes(g_audio) < 32768 && pushed < 4) {
        tone_fill(buf, 1024);
        nxn_result r = nxn_audio_queue(g_audio, buf, sizeof buf);
        if (r != NXN_OK) {
            feat_set(F_AUDIO_TONE, RES_FAIL, "nxn_audio_queue -> %d (%s)", (int)r, nxn_last_error());
            g_tone_on = 0;
            return;
        }
        pushed++;
    }
    if (pushed && g_feat[F_AUDIO_TONE].res != RES_OK) feat_set(F_AUDIO_TONE, RES_OK, "queue accepted S16 stereo 48 kHz (listen to confirm)");
}

static void audio_reopen(void) {
    if (g_audio) nxn_audio_close(g_audio);
    g_audio = NULL;
    nxn_result r = nxn_audio_open(NULL, &g_audio);
    if (r == NXN_OK) r = nxn_audio_pause(g_audio, 0);
    if (r == NXN_OK)
        feat_set(F_AUDIO_OPEN, RES_OK, "48 kHz stereo S16, push mode");
    else
        feat_set(F_AUDIO_OPEN, RES_FAIL, "nxn_audio_open -> %d (%s)", (int)r, nxn_last_error());
}

/* nxn_audio_clear on a paused stream (the mixer takes nothing): 16 KB queued, then none */
static void audio_clear_test(void) {
    if (!(g_caps.features & NXN_CAP_AUDIO_CLEAR)) {
        feat_set(F_AUDIO_STOP, RES_NA, "NXN_CAP_AUDIO_CLEAR is not set (a system older than Native 1.1)");
        return;
    }
    static int16_t silence[2048 * 2];
    nxn_audio_pause(g_audio, 1);
    nxn_result q = nxn_audio_queue(g_audio, silence, sizeof silence);
    uint32_t before = nxn_audio_queued_bytes(g_audio);
    nxn_result c = nxn_audio_clear(g_audio);
    uint32_t after = nxn_audio_queued_bytes(g_audio);
    nxn_audio_pause(g_audio, 0);
    if (q == NXN_OK && c == NXN_OK && before > 0 && after == 0)
        feat_set(F_AUDIO_STOP, RES_OK, "%u bytes queued, 0 after nxn_audio_clear", before);
    else
        feat_set(F_AUDIO_STOP, RES_FAIL, "queue %d, clear %d, queued %u -> %u", (int)q, (int)c, before, after);
}

static void tone_stop(void) {
    g_tone_on = 0;
    if (g_caps.features & NXN_CAP_AUDIO_CLEAR) {
        nxn_audio_clear(g_audio); /* what is queued is gone at once, the stream stays open */
        return;
    }
    audio_reopen(); /* a system older than Native 1.1: closing the stream drops what is still queued */
}

/* ------------------------------------------------------------------ ImGui platform glue */
static const struct { uint64_t bit; ImGuiKey key; } kPadMap[] = {
    {NXN_BTN_X, ImGuiKey_GamepadFaceUp},   {NXN_BTN_Y, ImGuiKey_GamepadFaceLeft}, {NXN_BTN_L, ImGuiKey_GamepadL1},
    {NXN_BTN_R, ImGuiKey_GamepadR1},       {NXN_BTN_ZL, ImGuiKey_GamepadL2},      {NXN_BTN_ZR, ImGuiKey_GamepadR2},
    {NXN_BTN_LEFT, ImGuiKey_GamepadDpadLeft}, {NXN_BTN_RIGHT, ImGuiKey_GamepadDpadRight},
    {NXN_BTN_UP, ImGuiKey_GamepadDpadUp},  {NXN_BTN_DOWN, ImGuiKey_GamepadDpadDown}, {NXN_BTN_PLUS, ImGuiKey_GamepadStart},
    {NXN_BTN_MINUS, ImGuiKey_GamepadBack}};

static void feed_imgui(float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)g_w, (float)g_h);
    io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
    /* confirm / cancel follow the user's mapping in Nexvyn OS */
    io.AddKeyEvent(ImGuiKey_GamepadFaceDown, (g_in.actions & NXN_ACT_CONFIRM) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadFaceRight, (g_in.actions & NXN_ACT_CANCEL) != 0);
    for (const auto& m : kPadMap) io.AddKeyEvent(m.key, (g_in.buttons & m.bit) != 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickLeft, g_in.lx < -0.2f, g_in.lx < 0 ? -g_in.lx : 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickRight, g_in.lx > 0.2f, g_in.lx > 0 ? g_in.lx : 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickUp, g_in.ly > 0.2f, g_in.ly > 0 ? g_in.ly : 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickDown, g_in.ly < -0.2f, g_in.ly < 0 ? -g_in.ly : 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadRStickUp, g_in.ry > 0.2f, g_in.ry > 0 ? g_in.ry : 0);
    io.AddKeyAnalogEvent(ImGuiKey_GamepadRStickDown, g_in.ry < -0.2f, g_in.ry < 0 ? -g_in.ry : 0);
    /* the first finger is the mouse */
    static int was_down;
    if (g_in.touch_count > 0) {
        nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(0, &t) == NXN_OK) {
#ifndef NEXVYN_WINDOWED
            float sc = (float)g_w / 1280.f; /* exclusive: touch is reported in a 1280x720 space */
            t.x *= sc;
            t.y *= sc;
#endif
            io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
            io.AddMousePosEvent(t.x, t.y);
            io.AddMouseButtonEvent(0, true);
            was_down = 1;
        }
    } else if (was_down) {
        io.AddMouseButtonEvent(0, false);
        io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
        was_down = 0;
    }
}

/* ------------------------------------------------------------------ UI helpers */
static ImVec4 res_color(Res r) {
    switch (r) {
    case RES_OK: return ImVec4(0.35f, 0.9f, 0.45f, 1);
    case RES_FAIL: return ImVec4(1.0f, 0.4f, 0.4f, 1);
    case RES_NA: return ImVec4(0.6f, 0.62f, 0.68f, 1);
    case RES_TODO: return ImVec4(1.0f, 0.75f, 0.3f, 1);
    default: return ImVec4(0.55f, 0.75f, 1.0f, 1);
    }
}

static void lines_page(int which, void (*rerun)(void)) {
    if (ImGui::Button("Run again")) {
        rerun();
        g_feat_dirty = 1;
    }
    ImGui::Separator();
    const Lines& L = g_lines[which];
    for (int i = 0; i < L.n; i++) {
        ImGui::PushStyleColor(ImGuiCol_Text, res_color(L.res[i]));
        ImGui::Text("%-4s", L.res[i] == RES_OK ? "OK" : L.res[i] == RES_FAIL ? "FAIL" : L.res[i] == RES_NA ? "-" : "TODO");
        ImGui::PopStyleColor();
        ImGui::SameLine();
        ImGui::TextWrapped("%s", L.text[i]);
    }
}

static double g_worst_ms; /* longest frame since the last report */
static void header_text(char* out, size_t n) {
    snprintf(out, n, "mode %s | surface %ux%u | %.1f fps, %.1f ms, longest %.1f ms | OS %s | SDK %s | native %s | GL %s | renderer %s", SC_MODE, g_w, g_h, g_fps, g_ms, g_worst_ms,
             nxn_info_string(NXN_INFO_OS_VERSION), nxn_info_string(NXN_INFO_SDK_VERSION), nxn_info_string(NXN_INFO_NATIVE_VERSION),
             g_glinfo[0], g_glinfo[1]);
}

/* ------------------------------------------------------------------ pages */
static void page_status(void) {
    int cnt[5] = {0};
    for (int i = 0; i < F_COUNT; i++) cnt[g_feat[i].res]++;
    ImGui::TextColored(res_color(RES_OK), "%d OK", cnt[RES_OK]);
    ImGui::SameLine();
    ImGui::TextColored(res_color(RES_FAIL), "%d FAIL", cnt[RES_FAIL]);
    ImGui::SameLine();
    ImGui::TextColored(res_color(RES_NA), "%d not available here", cnt[RES_NA]);
    ImGui::SameLine();
    ImGui::TextColored(res_color(RES_TODO), "%d not implemented", cnt[RES_TODO]);
    ImGui::SameLine();
    ImGui::TextColored(res_color(RES_PEND), "%d not run / waiting", cnt[RES_PEND]);
    if (ImGui::Button("Run all tests again")) {
        tests_run_all();
    }
    ImGui::SameLine();
    if (ImGui::Button("Save report")) {
        char h[400];
        header_text(h, sizeof h);
        report_write(h);
    }
    ImGui::SameLine();
    ImGui::TextDisabled("-> showcase_report.txt in the app data folder");
    if (ImGui::BeginTable("status", 4, ImGuiTableFlags_RowBg | ImGuiTableFlags_Borders | ImGuiTableFlags_ScrollY | ImGuiTableFlags_Resizable)) {
        ImGui::TableSetupScrollFreeze(0, 1);
        ImGui::TableSetupColumn("Feature", ImGuiTableColumnFlags_WidthStretch, 3.2f);
        ImGui::TableSetupColumn("Mode", ImGuiTableColumnFlags_WidthFixed, 70.f);
        ImGui::TableSetupColumn("Result", ImGuiTableColumnFlags_WidthFixed, 150.f);
        ImGui::TableSetupColumn("Detail", ImGuiTableColumnFlags_WidthStretch, 4.f);
        ImGui::TableHeadersRow();
        const char* group = "";
        for (int i = 0; i < F_COUNT; i++) {
            const Feature& f = g_feat[i];
            if (strcmp(group, f.group) != 0) {
                group = f.group;
                ImGui::TableNextRow(ImGuiTableRowFlags_Headers);
                ImGui::TableNextColumn();
                ImGui::TextDisabled("%s", group);
            }
            ImGui::TableNextRow();
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(f.name);
            ImGui::TableNextColumn();
            ImGui::TextUnformatted(f.modes == 'B' ? "both" : f.modes == 'E' ? "exclusive" : "windowed");
            ImGui::TableNextColumn();
            ImGui::TextColored(res_color(f.res), "%s", res_text(f.res));
            ImGui::TableNextColumn();
            ImGui::TextWrapped("%s", f.note);
        }
        ImGui::EndTable();
    }
}

static void page_display(void) {
    ImGui::Text("GL_VERSION   %s", g_glinfo[0]);
    ImGui::Text("GL_RENDERER  %s", g_glinfo[1]);
    ImGui::Text("GL_VENDOR    %s", g_glinfo[2]);
    ImGui::Text("surface %ux%u   |   %.1f fps   |   frame %.2f ms   |   frames %d", g_w, g_h, g_fps, g_ms, g_frames);
    ImGui::Text("resize events %d (last %ux%u, docked %d)   focus events %d (focused %d)", g_resize_events, g_last_w, g_last_h, g_last_docked,
                g_focus_events, g_focused);
    ImGui::TextDisabled("Resize the window, or dock / undock the console: the surface follows (nxn_display_resize).");
    ImGui::Separator();
    for (int i = 0; i < 8 && i < g_evn; i++) ImGui::TextUnformatted(g_evlog[(g_evn - 1 - i) % 8]);
    ImVec2 p = ImGui::GetCursorScreenPos(), avail = ImGui::GetContentRegionAvail();
    if (avail.y > 60 && avail.x > 60) {
        g_cube_rect[0] = p.x;
        g_cube_rect[1] = p.y;
        g_cube_rect[2] = avail.x;
        g_cube_rect[3] = avail.y;
        g_cube_on = 1;
        ImDrawList* dl = ImGui::GetWindowDrawList();
        dl->AddCallback(cube_callback, nullptr);
        dl->AddCallback(ImDrawCallback_ResetRenderState, nullptr);
        ImGui::Dummy(avail);
    }
}

static void page_input(void) {
    static const struct { uint64_t bit; const char* name; } names[] = {
        {NXN_BTN_A, "A"}, {NXN_BTN_B, "B"}, {NXN_BTN_X, "X"}, {NXN_BTN_Y, "Y"}, {NXN_BTN_L, "L"}, {NXN_BTN_R, "R"},
        {NXN_BTN_ZL, "ZL"}, {NXN_BTN_ZR, "ZR"}, {NXN_BTN_PLUS, "+"}, {NXN_BTN_MINUS, "-"}, {NXN_BTN_UP, "Up"},
        {NXN_BTN_DOWN, "Down"}, {NXN_BTN_LEFT, "Left"}, {NXN_BTN_RIGHT, "Right"}, {NXN_BTN_LSTICK, "LS click"},
        {NXN_BTN_RSTICK, "RS click"}};
    ImGui::Text("buttons 0x%04llx   actions 0x%x (confirm = bit 0, cancel = bit 1)", (unsigned long long)g_in.buttons, g_in.actions);
    for (size_t i = 0; i < sizeof names / sizeof names[0]; i++) {
        bool down = (g_in.buttons & names[i].bit) != 0;
        ImGui::PushStyleColor(ImGuiCol_Button, down ? ImVec4(0.2f, 0.7f, 0.3f, 1) : ImVec4(0.18f, 0.2f, 0.26f, 1));
        ImGui::PushStyleColor(ImGuiCol_ButtonHovered, down ? ImVec4(0.2f, 0.7f, 0.3f, 1) : ImVec4(0.18f, 0.2f, 0.26f, 1));
        ImGui::PushStyleColor(ImGuiCol_ButtonActive, down ? ImVec4(0.2f, 0.7f, 0.3f, 1) : ImVec4(0.18f, 0.2f, 0.26f, 1));
        ImGui::Button(names[i].name, ImVec2(84, 0));
        ImGui::PopStyleColor(3);
        if ((i % 8) != 7) ImGui::SameLine();
    }
    ImGui::NewLine();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = 54;
    ImVec2 p = ImGui::GetCursorScreenPos();
    const float sx[2] = {g_in.lx, g_in.rx}, sy[2] = {g_in.ly, g_in.ry};
    for (int s = 0; s < 2; s++) {
        ImVec2 c(p.x + r + 10 + s * (2 * r + 30), p.y + r + 4);
        dl->AddCircle(c, r, IM_COL32(150, 160, 190, 255), 32, 2.f);
        dl->AddLine(ImVec2(c.x - r, c.y), ImVec2(c.x + r, c.y), IM_COL32(80, 90, 110, 255));
        dl->AddLine(ImVec2(c.x, c.y - r), ImVec2(c.x, c.y + r), IM_COL32(80, 90, 110, 255));
        dl->AddCircleFilled(ImVec2(c.x + sx[s] * r, c.y - sy[s] * r), 9, IM_COL32(90, 220, 120, 255));
    }
    /* touch pad: a small map of the WHOLE app surface (not a pad you tap inside). The dot sits where the finger is, in
     * proportion to the surface, and a ring on the foreground layer marks the exact point under the finger so the two
     * are never confused (a tap on the map's own area lands on the map at the surface position, which is not the same
     * spot, as a small map of the window shows it). */
    ImVec2 tp(p.x + 4 * r + 80, p.y);
    float tw = fminf(ImGui::GetContentRegionAvail().x - 4 * r - 90, 320.f), pad_h = 0;
    if (tw > 80) {
        float refw = g_windowed ? (float)g_w : 1280.f, refh = g_windowed ? (float)g_h : 720.f;
        float th = tw * refh / refw; /* the map keeps the aspect of the surface */
        dl->AddRectFilled(tp, ImVec2(tp.x + tw, tp.y + th), IM_COL32(24, 28, 38, 255));
        dl->AddRect(tp, ImVec2(tp.x + tw, tp.y + th), IM_COL32(150, 160, 190, 255));
        for (uint32_t i = 0; i < g_in.touch_count && i < 10; i++) {
            nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
            if (nxn_input_touch(i, &t) != NXN_OK) continue;
            dl->AddCircleFilled(ImVec2(tp.x + t.x / refw * tw, tp.y + t.y / refh * th), 8, IM_COL32(255, 190, 70, 220));
            float sc = g_windowed ? 1.f : (float)g_w / 1280.f;
            ImGui::GetForegroundDrawList()->AddCircle(ImVec2(t.x * sc, t.y * sc), 18, IM_COL32(255, 190, 70, 255), 24, 2.f);
        }
        pad_h = th + 4;
    }
    ImGui::Dummy(ImVec2(0, fmaxf(2 * r + 12, pad_h)));
    ImGui::Text("left stick  %+.2f %+.2f      right stick  %+.2f %+.2f      touches %u", g_in.lx, g_in.ly, g_in.rx, g_in.ry, g_in.touch_count);
    char keys[40] = "";
    int kn = 0;
    for (uint32_t k = 4; k < 30 && kn < 30; k++)
        if (nxn_input_key_held(k) > 0) keys[kn++] = (char)('a' + (k - 4));
    keys[kn] = 0;
    ImGui::Text("USB keyboard letters held: %s", kn ? keys : "(none)");
    if (ImGui::Button("Rumble 0.6 for 300 ms")) nxn_rumble(0.6f, 300);
    ImGui::SameLine();
    if (ImGui::Button("Stop rumble")) nxn_rumble(0.f, 0);
    ImGui::TextDisabled("nxn_rumble: only while this window has focus; stops by itself when the time is up.");
}

static void page_audio(void) {
    if (ImGui::Button(g_tone_on ? "Tone is playing" : "Play tone")) {
        g_tone_on = 1;
        if (!g_audio) audio_reopen();
    }
    ImGui::SameLine();
    if (ImGui::Button("Stop")) tone_stop();
    ImGui::SameLine();
    if (ImGui::Button("Left")) g_tone_pan = -1;
    ImGui::SameLine();
    if (ImGui::Button("Center")) g_tone_pan = 0;
    ImGui::SameLine();
    if (ImGui::Button("Right")) g_tone_pan = 1;
    ImGui::SliderFloat("pan (-1 left, +1 right)", &g_tone_pan, -1.f, 1.f);
    ImGui::SliderFloat("frequency (Hz)", &g_tone_hz, 110.f, 1760.f, "%.0f");
    ImGui::Text("stream %s, queued %u bytes", g_audio ? "open" : "closed", g_audio ? nxn_audio_queued_bytes(g_audio) : 0u);
    ImGui::TextDisabled("Push mode: the app keeps about 0.17 s queued (nxn_audio_queue). Equal-power pan is computed in the app.");
    ImGui::TextColored(res_color(RES_TODO), "Missing: a call to drop queued samples. Stop closes and re-opens the stream.");
}

/* The dialogs wait for the user, so they run on a worker thread: the frame loop keeps drawing. */
static volatile int g_pick_busy = 0;
static nxn_thread* g_pick_thread = NULL;
static char g_pick_text[360] = "";
static nxn_pick_params g_pick_params;
static void pick_worker(void*) {
    char path[320];
    nxn_result r = nxn_pick(&g_pick_params, path, sizeof path);
    if (r == NXN_OK) snprintf(g_pick_text, sizeof g_pick_text, "picked: %s", path);
    else if (r == NXN_ERR_CANCELLED) snprintf(g_pick_text, sizeof g_pick_text, "cancelled");
    else snprintf(g_pick_text, sizeof g_pick_text, "nxn_pick -> %d", (int)r);
    g_pick_busy = 0;
}
static void pick_start(uint32_t kind, uint32_t flags, const char* exts) {
    if (g_pick_busy) return;
    if (g_pick_thread) {  /* the last dialog's thread has ended: join it before the next one */
        nxn_thread_join(g_pick_thread);
        g_pick_thread = NULL;
    }
    g_pick_params = NXN_STRUCT_INIT(nxn_pick_params);
    g_pick_params.kind = kind;
    g_pick_params.flags = flags;
    g_pick_params.title = "Showcase";
    g_pick_params.extensions = exts;
    g_pick_params.default_name = "showcase.txt";
    nxn_thread_params tp = NXN_STRUCT_INIT(nxn_thread_params);
    tp.fn = pick_worker;
    tp.name = "pick";
    g_pick_busy = 1;
    if (nxn_thread_start(&tp, &g_pick_thread) != NXN_OK) {
        g_pick_thread = NULL;
        g_pick_busy = 0;
    }
}
static void page_files(void) {
    lines_page(L_FILES, test_files);
    ImGui::TextDisabled("Files live in <data>/showcase; the report is <data>/showcase_report.txt.");
    ImGui::Separator();
    ImGui::Text("Dialogs (nxn_pick) and kept folder access (nxn_grant_*):");
    if (ImGui::Button("Open file...")) pick_start(NXN_PICK_OPEN_FILE, 0, ".txt;.png;.jpg");
    ImGui::SameLine();
    if (ImGui::Button("Save file...")) pick_start(NXN_PICK_SAVE_FILE, 0, NULL);
    ImGui::SameLine();
    if (ImGui::Button("Folder (kept)...")) pick_start(NXN_PICK_FOLDER, NXN_PICK_REMEMBER, NULL);
    ImGui::SameLine();
    if (ImGui::Button("Forget kept folders")) {
        char gp[320];
        while (nxn_grant_get(0, gp, sizeof gp) == NXN_OK && nxn_grant_revoke(gp) == NXN_OK) {}
    }
    char gp[320];
    for (uint32_t i = 0; i < 8 && nxn_grant_get(i, gp, sizeof gp) == NXN_OK; i++) ImGui::BulletText("kept: %s", gp);
    ImGui::TextDisabled("%s", g_pick_text[0] ? g_pick_text : "(nothing picked yet)");
}
static void page_system(void) { lines_page(L_SYSTEM, test_system); }
static void page_threads(void) { lines_page(L_THREADS, test_threads); }
static void page_compat(void) { lines_page(L_COMPAT, test_compat); }
/* ---- UI tokens page: a few controls drawn only with the values nxn_ui_tokens_get gives (the OS look) */
static ImFont* g_icon_font;
static ImU32 tok_col(uint32_t argb) { return IM_COL32((argb >> 16) & 255, (argb >> 8) & 255, argb & 255, argb >> 24); }
static void utf8_of(uint32_t cp, char* out) {
    if (cp < 0x80) { out[0] = (char)cp; out[1] = 0; }
    else if (cp < 0x800) { out[0] = (char)(0xC0 | (cp >> 6)); out[1] = (char)(0x80 | (cp & 63)); out[2] = 0; }
    else { out[0] = (char)(0xE0 | (cp >> 12)); out[1] = (char)(0x80 | ((cp >> 6) & 63)); out[2] = (char)(0x80 | (cp & 63)); out[3] = 0; }
}
static void page_ui(void) {
    lines_page(L_UI, test_ui);
    if (!(g_caps.features & NXN_CAP_UI_TOKENS)) {
        ImGui::TextDisabled("The OS look is available inside a Nexvyn OS window.");
        return;
    }
    const nxn_ui_tokens& t = g_tok;
    ImGui::Separator();
    ImGui::TextDisabled("Drawn only with nxn_ui_tokens (revision %u, %s). Switch light / dark in Settings: this page follows.", t.revision, t.dark ? "dark" : "light");
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p0 = ImGui::GetCursorScreenPos();
    float w = ImGui::GetContentRegionAvail().x, sp = t.spacing[3], k = t.text_scale, h = 230.f;
    ImFont* f = ImGui::GetFont();
    dl->AddRectFilled(p0, ImVec2(p0.x + w, p0.y + h), tok_col(t.window_bg), t.corner_radius);
    ImVec2 side0(p0.x, p0.y), side1(p0.x + 150, p0.y + h);
    dl->AddRectFilled(side0, side1, tok_col(t.sidebar_bg), t.corner_radius);
    const char* rows[] = {"Documents", "Pictures", "Music"};
    const char* icons[] = {"folder", "image", "music_note"};
    for (int i = 0; i < 3; i++) {
        float ry = p0.y + sp + i * (t.row_height + 2);
        ImVec2 a(p0.x + 8, ry), b(p0.x + 142, ry + t.row_height);
        if (i == 0) dl->AddRectFilled(a, b, tok_col(t.selection), t.corner_radius_row);
        else if (i == 1) dl->AddRectFilled(a, b, tok_col(t.hover), t.corner_radius_row);
        ImU32 tc = tok_col(i == 0 ? t.selection_text : t.text);
        char ic[8];
        utf8_of(nxn_ui_icon_code(icons[i]), ic);
        float iy = ry + (t.row_height - t.font_large * k) / 2;
        if (g_icon_font) dl->AddText(g_icon_font, t.font_large * k * 1.2f, ImVec2(a.x + 8, iy - 2), tc, ic);
        dl->AddText(f, t.font_body * k, ImVec2(a.x + 34, ry + (t.row_height - t.font_body * k) / 2), tc, rows[i]);
    }
    float cx = p0.x + 150 + sp, cy = p0.y + sp;
    dl->AddText(f, t.font_title * k, ImVec2(cx, cy), tok_col(t.text), "Documents");
    dl->AddText(f, t.font_small * k, ImVec2(cx, cy + t.font_title * k + 4), tok_col(t.text_secondary), "12 items, last changed today");
    float by = cy + t.font_title * k + 4 + t.font_small * k + sp;
    ImVec2 b0(cx, by), b1(cx + 110, by + t.control_height);
    dl->AddRectFilled(b0, b1, tok_col(t.accent), t.corner_radius);
    dl->AddText(f, t.font_body * k, ImVec2(cx + 30, by + (t.control_height - t.font_body * k) / 2), tok_col(t.accent_text), "Save");
    ImVec2 c0(cx + 110 + t.spacing[1], by), c1(cx + 230 + t.spacing[1], by + t.control_height);
    dl->AddRectFilled(c0, c1, tok_col(t.surface), t.corner_radius);
    dl->AddRect(c0, c1, tok_col(t.border), t.corner_radius);
    dl->AddText(f, t.font_body * k, ImVec2(c0.x + 28, by + (t.control_height - t.font_body * k) / 2), tok_col(t.text), "Cancel");
    float fy = by + t.control_height + t.spacing[2];
    ImVec2 d0(cx, fy), d1(cx + 340, fy + t.control_height);
    dl->AddRectFilled(d0, d1, tok_col(t.field_bg), t.corner_radius_field);
    dl->AddRect(d0, d1, tok_col(t.field_border), t.corner_radius_field);
    dl->AddText(f, t.font_body * k, ImVec2(d0.x + t.spacing[2], fy + (t.control_height - t.font_body * k) / 2), tok_col(t.text_tertiary), "Search...");
    float gy = fy + t.control_height + t.spacing[2];
    dl->AddLine(ImVec2(cx, gy - t.spacing[1]), ImVec2(p0.x + w - sp, gy - t.spacing[1]), tok_col(t.separator));
    const struct { const char* n; uint32_t c; } badges[] = {{"Error", t.error}, {"Warning", t.warning}, {"Success", t.success}, {"Info", t.info}};
    float bx = cx;
    for (auto& bd : badges) {
        float bw = ImGui::CalcTextSize(bd.n).x * (t.font_small * k / ImGui::GetFontSize()) + 2 * t.spacing[1];
        dl->AddRectFilled(ImVec2(bx, gy), ImVec2(bx + bw, gy + 22), tok_col(bd.c), 11);
        dl->AddText(f, t.font_small * k, ImVec2(bx + t.spacing[1], gy + 4), IM_COL32(255, 255, 255, 255), bd.n);
        bx += bw + t.spacing[1];
    }
    ImGui::Dummy(ImVec2(w, h + sp));
}

static void page_libs(void) { lines_page(L_LIBS, test_libs); }

static void page_lifecycle(void) {
    static int pending = -1;
    ImGui::TextColored(res_color(RES_TODO), "These buttons stop or break this app on purpose. Each one asks first.");
    ImGui::TextWrapped("Crash tests should close the window / return to Nexvyn OS and leave a report in System/Logs/Crashes. The report file is saved first.");
    ImGui::Separator();
    struct Act { const char* label; const char* what; };
    static const Act acts[] = {
        {"Crash a worker thread", "A worker thread writes to an invalid address. Expected: the app is closed and Nexvyn OS reports a crash."},
        {"Crash the main thread", "The main thread writes to an invalid address. Expected: the app is closed and Nexvyn OS reports a crash."},
        {"Abort the main thread", "abort() deep in a call chain. Expected: the app is closed and the report shows a backtrace."},
        {"Hang for 10 s", "The main thread stops answering for 10 seconds. Expected: Nexvyn OS may show 'not responding' (Wait / Close)."},
        {"Quit with code 42", "nxn_request_return(NORMAL, 42): the app leaves cleanly with exit code 42."}};
    for (int i = 0; i < 5; i++) {
        if (ImGui::Button(acts[i].label, ImVec2(260, 0))) {
            pending = i;
            ImGui::OpenPopup("Are you sure?");
        }
        ImGui::SameLine();
        ImGui::TextDisabled("%s", acts[i].what);
    }
    ImGui::SetNextWindowPos(ImVec2((float)g_w * 0.5f, (float)g_h * 0.5f), ImGuiCond_Always, ImVec2(0.5f, 0.5f));
    if (ImGui::BeginPopupModal("Are you sure?", nullptr, ImGuiWindowFlags_AlwaysAutoResize)) {
        ImGui::TextWrapped("%s", pending >= 0 ? acts[pending].label : "");
        ImGui::TextWrapped("%s", pending >= 0 ? acts[pending].what : "");
        if (ImGui::Button("Cancel", ImVec2(160, 0))) ImGui::CloseCurrentPopup();
        ImGui::SetItemDefaultFocus();
        ImGui::SameLine();
        if (ImGui::Button("Yes, do it", ImVec2(160, 0))) {
            ImGui::CloseCurrentPopup();
            int a = pending;
            pending = -1;
            if (a == 0) action_crash_worker();
            if (a == 1) action_crash_main();
            if (a == 2) action_crash_abort();
            if (a == 3) action_hang(10);
            if (a == 4) action_quit42();
        }
        ImGui::EndPopup();
    }
}

static const struct { const char* name; void (*fn)(void); } kPages[] = {
    {"Status", page_status}, {"Display & GL", page_display}, {"Input", page_input},   {"Audio", page_audio},
    {"Files", page_files},   {"System", page_system},        {"Threads", page_threads}, {"Compat", page_compat},
    {"Libraries", page_libs}, {"UI tokens", page_ui},     {"Crash", page_lifecycle}};
#define N_PAGES ((int)(sizeof kPages / sizeof kPages[0]))

static void draw_ui(void) {
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(ImVec2((float)g_w, (float)g_h));
    ImGui::Begin("showcase", nullptr, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoBringToFrontOnFocus);
    ImGui::Text("Native SDK Showcase   %s   %ux%u   %.0f fps", SC_MODE, g_w, g_h, g_fps);
    ImGui::SameLine();
    ImGui::TextDisabled("  L / R: page   D-pad + A: select   touch works");
    if (ImGui::BeginTabBar("pages", ImGuiTabBarFlags_FittingPolicyScroll)) {
        for (int i = 0; i < N_PAGES; i++) {
            ImGuiTabItemFlags fl = (g_want_page == i) ? ImGuiTabItemFlags_SetSelected : 0;
            if (ImGui::BeginTabItem(kPages[i].name, nullptr, fl)) {
                g_page = i;
                ImGui::BeginChild("page", ImVec2(0, 0), false, ImGuiWindowFlags_NavFlattened);
                kPages[i].fn();
                ImGui::EndChild();
                ImGui::EndTabItem();
            }
        }
        ImGui::EndTabBar();
    }
    g_want_page = -1;
    ImGui::End();
}

/* ------------------------------------------------------------------ main loop */
static int app_main(int, char**) {
    stage("start");
    nxn_caps_get(&g_caps);
    char probe[16] = {0};
    size_t got = 0;
    int autotest = nxn_fs_read(NXN_DIR_DATA, "autotest", probe, sizeof probe - 1, &got) == NXN_OK;

    tests_init(g_caps.features & NXN_CAP_WINDOWED ? 1 : 0);
    if (nxn_fs_read(NXN_DIR_DATA, "throwtest", probe, sizeof probe - 1, &got) == NXN_OK) {
        report_write("uncaught exception requested");
        action_throw_uncaught();  // never returns: the app ends as a crash
    }
    if (nxn_fs_read(NXN_DIR_DATA, "rtonly", probe, sizeof probe - 1, &got) == NXN_OK) {
        test_runtime();  // open / close loops (W2a): libraries, thread_local blocks, exception frames, then a clean end
        report_write("runtime only");
        return 0;
    }
    if (!(g_caps.features & NXN_CAP_EVENTS)) feat_set(F_RESIZE_EVT, RES_NA, "NXN_CAP_EVENTS is not set");
    if (!(g_caps.features & NXN_CAP_TOUCH)) feat_set(F_TOUCH, RES_NA, "NXN_CAP_TOUCH is not set");
    if (!g_windowed && g_feat[F_FOCUS_EVT].res == RES_PEND) feat_set(F_FOCUS_EVT, RES_NA, "windowed mode only");

    nxn_result r = nxn_display_open(NULL, &g_disp);
    if (r != NXN_OK) {
        feat_set(F_GL, RES_FAIL, "nxn_display_open -> %d (%s)", (int)r, nxn_last_error());
        tests_run_all();
        report_write("display could not be opened");
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available");
        return 1;
    }
    int glad_ok = gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h);
    if (!g_w || !g_h) {
        g_w = 1280;
        g_h = 720;
    }
    const char* v = (const char*)glGetString(GL_VERSION);
    const char* rr = (const char*)glGetString(GL_RENDERER);
    const char* vn = (const char*)glGetString(GL_VENDOR);
    snprintf(g_glinfo[0], sizeof g_glinfo[0], "%s", v ? v : "?");
    snprintf(g_glinfo[1], sizeof g_glinfo[1], "%s", rr ? rr : "?");
    snprintf(g_glinfo[2], sizeof g_glinfo[2], "%s", vn ? vn : "?");
    if (glad_ok)
        feat_set(F_GLAD, RES_OK, "glad loaded GL %d.%d through nxn_display_proc", GLVersion.major, GLVersion.minor);
    else
        feat_set(F_GLAD, RES_FAIL, "gladLoadGLLoader returned %d", glad_ok);
    feat_set(F_GL, (v && glad_ok) ? RES_OK : RES_FAIL, "%s on %s, surface %ux%u", g_glinfo[0], g_glinfo[1], g_w, g_h);
#ifdef SHOWCASE_COMPAT
    nexgfx_selftest();  /* its own GL state; the frame below sets everything it draws with */
#else
    feat_set(F_NEXGFX, RES_NA, "windowed builds only");
#endif
    stage("cube");
    cube_init();

    stage("imgui");
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    nxn_imgui_enable_gamepad(io);
    io.BackendPlatformName = "nexvyn_native";
    ImFontConfig fc;
    fc.SizePixels = 20.f;
    const void* osFont = NULL;
    size_t osFontSize = 0;
    if (g_caps.features & NXN_CAP_UI_TOKENS) {
        static ImWchar iconRange[7];
        const char* want[] = {"folder", "image", "music_note"};
        for (int i = 0; i < 3; i++) iconRange[i * 2] = iconRange[i * 2 + 1] = (ImWchar)nxn_ui_icon_code(want[i]);
        iconRange[6] = 0;
        /* the system font with the glyph ranges of the user's language (nxn_imgui.h); the icons are their own font here */
        nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 20.f, 0, NULL);
        const void* iconData = NULL;
        size_t iconSize = 0;
        if (iconRange[0] && nxn_ui_font_get(NXN_UI_FONT_ICONS, &iconData, &iconSize) == NXN_OK) {
            ImFontConfig ic;
            ic.FontDataOwnedByAtlas = false;
            g_icon_font = io.Fonts->AddFontFromMemoryTTF((void*)iconData, (int)iconSize, 20.f, &ic, iconRange);
        }
    } else {
        io.Fonts->AddFontDefault(&fc);
    }
    ImGui::StyleColorsDark();
    ImGui::GetStyle().WindowRounding = 0;
    ImGui::GetStyle().FrameRounding = 4;
    ImGui::GetStyle().ItemSpacing = ImVec2(10, 7);
    ImGui::GetStyle().FramePadding = ImVec2(10, 6);
    if (!ImGui_ImplOpenGL3_Init("#version 330 core")) nxn_log(NXN_LOG_ERROR, "ImGui_ImplOpenGL3_Init failed");

    stage("audio");
    audio_reopen();
    audio_clear_test();
    tests_run_all();
    stage("input");
    nxn_input_state probe_in = NXN_STRUCT_INIT(nxn_input_state);
    nxn_result ir = nxn_input_poll(&probe_in);
    if (ir == NXN_OK)
        feat_set(F_PAD, RES_OK, "nxn_input_poll works (press buttons on the Input page)");
    else
        feat_set(F_PAD, RES_FAIL, "nxn_input_poll -> %d", (int)ir);
    if (nxn_input_key_held(4) >= 0) feat_set(F_KEYS, RES_OK, "callable; hold a letter on a USB keyboard: the Input page lists it");
    else feat_set(F_KEYS, RES_FAIL, "nxn_input_key_held returned an error");
    if (g_caps.features & NXN_CAP_USB_INPUT) {
        nxn_mouse pm = NXN_STRUCT_INIT(nxn_mouse);
        nxn_key_event pk = NXN_STRUCT_INIT(nxn_key_event);
        char pt[16];
        nxn_result mr = nxn_input_mouse(&pm);
        int kr = nxn_input_key_poll(&pk), tr = nxn_input_text(pt, sizeof pt);
        feat_set(F_USB_MOUSE, mr == NXN_OK ? RES_OK : RES_FAIL, "nxn_input_mouse -> %d (move the pointer over the window and click)", (int)mr);
        feat_set(F_KEYPOLL, kr >= 0 && tr >= 0 ? RES_OK : RES_FAIL, "key_poll -> %d, text -> %d (type on a USB keyboard)", kr, tr);
    } else {
        feat_set(F_USB_MOUSE, RES_NA, "NXN_CAP_USB_INPUT is not set");
        feat_set(F_KEYPOLL, RES_NA, "NXN_CAP_USB_INPUT is not set");
    }
    if (!(g_caps.features & NXN_CAP_POWER_EVENTS)) {
        feat_set(F_DOCK_EVT, RES_NA, "NXN_CAP_POWER_EVENTS is not set");
        feat_set(F_SLEEP_EVT, RES_NA, "NXN_CAP_POWER_EVENTS is not set");
    }
    {
        char h[400];
        header_text(h, sizeof h);
        report_write(h);
    }

    stage("loop");
    uint64_t start = nxn_time_ns(), last = start, last_fps = start, last_report = start;
    int fps_frames = 0;
    while (!nxn_should_quit()) {
        uint64_t now = nxn_time_ns();
        float dt = (float)(now - last) / 1e9f;
        last = now;
        g_ms = g_ms * 0.9 + dt * 1000.0 * 0.1;
        if (now != start && dt * 1000.0 > g_worst_ms) g_worst_ms = dt * 1000.0;
        fps_frames++;
        if (now - last_fps >= 500000000ull) {
            g_fps = fps_frames * 1e9 / (double)(now - last_fps);
            fps_frames = 0;
            last_fps = now;
            if (g_frames > 30 && g_feat[F_SWAP].res != RES_OK) feat_set(F_SWAP, RES_OK, "%d frames, %.1f fps, %.2f ms per frame", g_frames, g_fps, g_ms);
        }

        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE) {
                g_resize_events++;
                g_last_w = ev.width;
                g_last_h = ev.height;
                g_last_docked = (int)ev.docked;
                feat_set(F_RESIZE_EVT, RES_OK, "%d event(s), last %ux%u docked %u", g_resize_events, ev.width, ev.height, ev.docked);
                ev_log("%6.1fs RESIZE %ux%u docked %u", (now - start) / 1e9, ev.width, ev.height, ev.docked);
                if (ev.width && ev.height) {
                    nxn_result rr2 = nxn_display_resize(g_disp, ev.width, ev.height);
                    nxn_display_size(g_disp, &g_w, &g_h);
                    if (rr2 == NXN_OK)
                        feat_set(F_RESIZE, RES_OK, "surface now %ux%u", g_w, g_h);
                    else
                        feat_set(F_RESIZE, RES_FAIL, "nxn_display_resize -> %d (%s)", (int)rr2, nxn_last_error());
                }
            } else if (ev.type == NXN_EVENT_FOCUS) {
                g_focus_events++;
                g_focused = (int)ev.focused;
                feat_set(F_FOCUS_EVT, RES_OK, "%d event(s), focused now %d", g_focus_events, g_focused);
                ev_log("%6.1fs FOCUS %u", (now - start) / 1e9, ev.focused);
            } else if (ev.type == NXN_EVENT_THEME) {
                g_theme_events++;
                nxn_result tr = nxn_ui_tokens_get(&g_tok);
                feat_set(F_UI_THEME_EVT, tr == NXN_OK ? RES_OK : RES_FAIL, "%d event(s), now %s, revision %u", g_theme_events, g_tok.dark ? "dark" : "light",
                         g_tok.revision);
                nxn_log(NXN_LOG_INFO, "NXN_EVENT_THEME: now %s, revision %u", g_tok.dark ? "dark" : "light", g_tok.revision);
                ev_log("%6.1fs THEME %s rev %u", (now - start) / 1e9, g_tok.dark ? "dark" : "light", g_tok.revision);
            } else if (ev.type == NXN_EVENT_MENU) {
                nxn_log(NXN_LOG_INFO, "NXN_EVENT_MENU: item %u", ev.item_id);
                ev_log("%6.1fs MENU %u", (now - start) / 1e9, ev.item_id);
            } else if (ev.type == NXN_EVENT_DOCK) {
                g_dock_events++;
                feat_set(F_DOCK_EVT, RES_OK, "%d event(s), docked %u, output %ux%u", g_dock_events, ev.docked, ev.width, ev.height);
                ev_log("%6.1fs DOCK %u %ux%u", (now - start) / 1e9, ev.docked, ev.width, ev.height);
            } else if (ev.type == NXN_EVENT_SUSPEND || ev.type == NXN_EVENT_RESUME) {
                if (ev.type == NXN_EVENT_SUSPEND) g_suspend_events++;
                else g_resume_events++;
                feat_set(F_SLEEP_EVT, g_suspend_events && g_resume_events ? RES_OK : RES_PEND, "%d suspend, %d resume event(s)",
                         g_suspend_events, g_resume_events);
                ev_log("%6.1fs %s", (now - start) / 1e9, ev.type == NXN_EVENT_SUSPEND ? "SUSPEND" : "RESUME");
            } else if (ev.type == NXN_EVENT_QUIT) {
                ev_log("%6.1fs QUIT", (now - start) / 1e9);
            }
            ev.size = sizeof ev;
        }

        nxn_input_poll(&g_in);
        if (g_caps.features & NXN_CAP_USB_INPUT) { /* count what the USB keyboard and the pointer send */
            nxn_key_event ke = NXN_STRUCT_INIT(nxn_key_event);
            while (nxn_input_key_poll(&ke) > 0) {
                g_key_events++;
                ke.size = sizeof ke;
            }
            char tb[64];
            int tn;
            while ((tn = nxn_input_text(tb, sizeof tb)) > 0) g_text_bytes += tn;
            nxn_mouse mo = NXN_STRUCT_INIT(nxn_mouse);
            if (nxn_input_mouse(&mo) == NXN_OK && mo.pressed) g_mouse_clicks++;
            if (g_key_events || g_text_bytes)
                feat_set(F_KEYPOLL, RES_OK, "%d key event(s), %d byte(s) of text", g_key_events, g_text_bytes);
            if (g_mouse_clicks) feat_set(F_USB_MOUSE, RES_OK, "%d click(s) seen, pointer at %.0f,%.0f", g_mouse_clicks, (double)mo.x, (double)mo.y);
        }
        if (g_in.touch_count > 0 && g_feat[F_TOUCH].res == RES_PEND) feat_set(F_TOUCH, RES_OK, "%u touch point(s) seen", g_in.touch_count);
        if (g_in.pressed & NXN_BTN_L) g_want_page = (g_page + N_PAGES - 1) % N_PAGES;
        if (g_in.pressed & NXN_BTN_R) g_want_page = (g_page + 1) % N_PAGES;
        if (autotest && g_want_page < 0) { /* the self-test shows Status, then Display, then walks the other pages */
            double t = (now - start) / 1e9;
            int p = t < 2.5 ? 0 : t < 5.0 ? 1 : (int)((t - 5.0) / 0.3) % N_PAGES;
            if (p != g_page) g_want_page = p;
        }
        tone_pump();

        feed_imgui(dt);
        ImGui_ImplOpenGL3_NewFrame();
        ImGui::NewFrame();
        g_cube_on = 0;
        draw_ui();
        ImGui::Render();
        glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
        glDisable(GL_SCISSOR_TEST);
        glClearColor(0.08f, 0.09f, 0.12f, 1.f);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(g_disp);
        g_frames++;
        if (g_frames == 10 || g_frames == 90) { /* crash test hook (the emulator runs): <data>/crashtest = "main" | "abort" |
                                 "worker" | "Worker-abort" at frame 90; a leading digit n crashes the next n starts at
                                 frame 10 ("3W": three runs) */
            char how[16] = {0};
            size_t hg = 0;
            if (nxn_fs_read(NXN_DIR_DATA, "crashtest", how, sizeof how - 1, &hg) == NXN_OK && hg > 0 &&
                (g_frames == 90 || (how[0] >= '1' && how[0] <= '9'))) {
                const char* h = how;
                char next[16] = {0};
                if (how[0] >= '2' && how[0] <= '9') snprintf(next, sizeof next, "%c%s", how[0] - 1, how + 1);
                if (how[0] >= '1' && how[0] <= '9') h = how + 1;
                nxn_fs_write(NXN_DIR_DATA, "crashtest", next, strlen(next)); /* once, or one start less */
                if (h[0] == 'a') action_crash_abort();
                else if (h[0] == 'W') action_crash_worker_abort();
                else if (h[0] == 'w') action_crash_worker();
                else action_crash_main();
            }
        }

        /* on a change (at most once a second) and every 10 s: a run that is killed still leaves a recent report */
        if ((g_feat_dirty && now - last_report > 1000000000ull) || now - last_report > 10000000000ull) {
            char h[400];
            header_text(h, sizeof h);
            report_write(h);
            last_report = now;
            g_worst_ms = 0;
        }
        if (autotest && now - start > 8000000000ull) {
            char h[400];
            header_text(h, sizeof h);
            report_write(h);
            nxn_request_return(NXN_RETURN_NORMAL, 7, NULL);
        }
    }
    char h[400];
    header_text(h, sizeof h);
    report_write(h);
    if (g_pick_thread) nxn_thread_join(g_pick_thread);  /* a dialog still open: nxn_pick returns once the window closes */
    ImGui_ImplOpenGL3_Shutdown();
    ImGui::DestroyContext();
    nxn_audio_close(g_audio);
    glDeleteBuffers(1, &g_vbo);
    glDeleteVertexArrays(1, &g_vao);
    glDeleteProgram(g_prog);
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
