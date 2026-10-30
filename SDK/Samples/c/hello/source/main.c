/* Merhaba C / Hello C: a small tour of the Nexvyn OS SDK in C (sdk/SDK.md, section "C").
 *  - A counter saved with store_*
 *  - Bouncing balls drawn with gfx_* (app_update makes the window redraw every frame)
 *  - Live JSON with net_json(url, callback)  (Open-Meteo current weather, no API key)
 * There is no build step: Nexvyn OS compiles every .c file of the bundle with TinyCC when the app opens.
 * The SDK is <nexvyn.h>; the small C library (stdio, stdlib, string, math...) is there too. */
#include <nexvyn.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "balls.h"

#define WEATHER_URL "https://api.open-meteo.com/v1/forecast?latitude=41.0082&longitude=28.9784&current=temperature_2m,wind_speed_10m"

static int tab;
static int count;
static char note[128];
static bool loading;
static char status[160];
static char weather[2048];

void app_load(const char* arg) {
    count = (int)store_getNum("count", 0);
    tab = (int)store_getNum("tab", 0);
    snprintf(note, sizeof note, "%s", store_getStr("note", ""));
    balls_init(8);
    printf("helloc started (arg \"%s\")\n", arg);
}

void app_update(float dt) {
    if (tab == 1) balls_step(dt);
}

static void bump(int n) {
    count = n;
    store_setNum("count", count);
}

static void draw_counter(float w, float h) {
    gfx_color(theme_color("text"));
    gfx_text(TR("counter_title"), 0, 70, 22, "bold", "center", w);
    gfx_color(theme_color("accent"));
    gfx_text(nxv_fmt("%d", count), 0, 110, 64, "semibold", "center", w);
    gfx_color(theme_color("text2"));
    gfx_text(TR1("times", nxv_fmt("%d", count)), 0, 190, 14, NULL, "center", w);
    if (ui_button("+1", w / 2 - 110, 226, 100, 36, "primary", "add", true)) {
        bump(count + 1);
        audio_play("click", 0, 0);
    }
    if (ui_button(TR("reset"), w / 2 + 10, 226, 100, 36, NULL, NULL, true)) bump(0);
    /* ui_textfield edits a char buffer in place */
    if (ui_textfield("note", note, sizeof note, w / 2 - 160, 290, 320, 34, TR("note_hint"), NULL)) store_setStr("note", note);
}

static void on_weather(const char* json, const char* error, void* user) {
    (void)user;
    loading = false;
    if (!json) {
        snprintf(status, sizeof status, "%s", TR1("failed", error));
        return;
    }
    snprintf(status, sizeof status, "%s", TR("loaded"));
    snprintf(weather, sizeof weather, "%s", json_pretty(json));
}

static void draw_network(float w, float h) {
    gfx_color(theme_color("text"));
    gfx_text(TR("net_title"), 24, 62, 20, "bold", NULL, 0);
    gfx_color(theme_color("text2"));
    gfx_wrap(TR("net_body"), 24, 92, w - 48, 13, NULL, NULL, 0);
    if (ui_button(TR("fetch"), 24, 140, 160, 34, "primary", "cloud_download", !loading)) {
        if (!sys_online()) {
            snprintf(status, sizeof status, "%s", TR("offline"));
        } else {
            loading = true;
            status[0] = 0;
            net_json(WEATHER_URL, NULL, on_weather, NULL);  /* the answer arrives later, in on_weather */
        }
    }
    if (loading) ui_spinner(206, 157, 10);
    gfx_color(theme_color("text2"));
    gfx_text(status, 200, 148, 13, NULL, NULL, 0);
    ui_group(24, 190, w - 48, h - 206);
    gfx_color(theme_color("text"));
    gfx_wrap(weather[0] ? weather : TR("no_data"), 40, 204, w - 80, 12, "mono", NULL, 0);
}

void app_draw(float w, float h) {
    const char* tabs[] = {TR("tab_counter"), TR("tab_balls"), TR("tab_net")};
    gfx_clear(theme_color("bg"));
    int t = ui_segmented("tabs", tabs, 3, tab, w / 2 - 180, 14, 360, 30);
    if (t != tab) {
        tab = t;
        store_setNum("tab", tab);
    }
    if (tab == 0) draw_counter(w, h);
    else if (tab == 1) balls_draw(w, h);
    else draw_network(w, h);
}

void app_event(const nxv_event* e) {
    if (tab == 0 && strcmp(e->type, "keydown") == 0 && strcmp(e->key, "space") == 0) bump(count + 1);
    if (tab == 1 && strcmp(e->type, "mousedown") == 0) balls_push(e->x, e->y);
}

void app_menu(void) {
    menu_begin(TR("app_name"));
    menu_item(TR("reset"), 1, NULL, false, count > 0);
    menu_separator();
    menu_item(TR("about"), 2, NULL, false, true);
}

static void on_about(int button, void* user) {
    (void)user;
    if (button == 1) sys_open("bundle:/main.c");
}

void app_onmenu(int id) {
    if (id == 1) bump(0);
    if (id == 2) {
        const char* buttons[] = {TR("ok"), TR("open_code")};
        ui_alert(TR("about"), TR("about_body"), buttons, 2, on_about, NULL);
    }
}
