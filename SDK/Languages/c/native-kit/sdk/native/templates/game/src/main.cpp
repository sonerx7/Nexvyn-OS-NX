// Game template: the building blocks of a native game, with a tiny demo on top (a square you move and jump with).
// No menu, no title screen, no theme: those are your game's own. What is here:
//   - a loop with a fixed 120 Hz update and a free render rate (frame time never changes the game's speed)
//   - resize (window <-> full screen), focus loss and suspend handled: the game pauses, the sound stops
//   - quads.h: one GL shader and a batch of rectangles; actions.h: pad / keyboard / touch behind named actions
//   - sound: nxn_sfx_play (system sounds or your own wav / ogg files) and nxn_tone, played by the OS mixer
//   - a save file in the data folder (nxn_fs_write / nxn_fs_read)
// The same build runs in a window or full screen: set "mode" in app.json.
#include <glad/glad.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <nexvyn/nexvyn_native.h>

#include "actions.h"
#include "quads.h"

static nxn_display* g_disp;
static uint32_t g_w = 1280, g_h = 720;
static QuadBatch g_quads;
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static ActionState g_act;

struct World {
    float x = 600, y = 0, vy = 0;
    bool on_ground = true;
    int jumps = 0;
};
static World g_world;

static void save_game() {
    char buf[32];
    int n = snprintf(buf, sizeof buf, "%d\n", g_world.jumps);
    nxn_fs_write(NXN_DIR_DATA, "save.txt", buf, (size_t)n);
}
static void load_game() {
    char buf[32] = {0};
    size_t got = 0;
    if (nxn_fs_read(NXN_DIR_DATA, "save.txt", buf, sizeof buf - 1, &got) == NXN_OK && got > 0) sscanf(buf, "%d", &g_world.jumps);
}

// One fixed step (1/120 s): game rules only, no drawing, no waiting.
static void update(float dt) {
    World& w = g_world;
    w.x += g_act.axis_x * 420.f * dt;
    if (g_act.pressed[ACT_JUMP] && w.on_ground) {
        w.vy = -620.f;
        w.on_ground = false;
        w.jumps++;
        nxn_tone(660.f, 0.08f, 0.25f, 1);  // a short square-wave blip from the OS mixer
    }
    w.vy += 1600.f * dt;
    w.y += w.vy * dt;
    const float floor_y = (float)g_h - 140.f;
    if (w.y >= floor_y) {
        w.y = floor_y;
        w.vy = 0;
        w.on_ground = true;
    }
    if (w.x < 0) w.x = 0;
    if (w.x > (float)g_w - 48.f) w.x = (float)g_w - 48.f;
}

static void render() {
    glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
    glDisable(GL_SCISSOR_TEST);
    glClearColor(0.05f, 0.06f, 0.09f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    g_quads.rect(0, (float)g_h - 92.f, (float)g_w, 92.f, 0.14f, 0.16f, 0.22f);
    g_quads.rect(g_world.x, g_world.y, 48.f, 48.f, 0.95f, 0.72f, 0.25f);
    for (int i = 0; i < g_world.jumps % 20; i++) g_quads.rect(16.f + i * 14.f, 16.f, 10.f, 10.f, 0.4f, 0.8f, 0.6f);
    g_quads.flush((float)g_w, (float)g_h);
}

static int app_main(int, char**) {
    if (nxn_display_open(NULL, &g_disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL is not available");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h);
    if (!g_quads.init()) {
        nxn_log(NXN_LOG_ERROR, "the quad shader did not compile");
        nxn_request_return(NXN_RETURN_ERROR, 2, "shader error");
        nxn_display_close(g_disp);
        return 2;
    }
    load_game();

    const float step = 1.f / 120.f;
    float acc = 0;
    uint64_t last = nxn_time_ns();
    bool paused = false, quit = false;
    while (!quit && !nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE) {
                if (nxn_display_resize(g_disp, ev.width, ev.height) == NXN_OK) nxn_display_size(g_disp, &g_w, &g_h);
            } else if (ev.type == NXN_EVENT_FOCUS) {
                if (!ev.focused) paused = true;
            } else if (ev.type == NXN_EVENT_SUSPEND) {
                paused = true;
                nxn_sfx_stop_all();
                save_game();
            } else if (ev.type == NXN_EVENT_QUIT) {
                quit = true;
            }
            ev = NXN_STRUCT_INIT(nxn_event);
        }
        nxn_input_poll(&g_in);
        actions_update(g_act, g_in);
        if (g_act.pressed[ACT_PAUSE]) paused = !paused;

        uint64_t now = nxn_time_ns();
        float dt = (float)((now - last) / 1e9);
        last = now;
        if (dt > 0.1f) dt = 0.1f;  // after a stall (dialog, suspend) do not run a burst of steps
        if (!paused) {
            acc += dt;
            while (acc >= step) {
                update(step);
                acc -= step;
            }
        }
        render();
        nxn_display_swap(g_disp);  // paced by the display: no busy loop
    }
    save_game();
    g_quads.destroy();
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
