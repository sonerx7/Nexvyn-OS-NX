/* My App: a minimal Nexvyn OS app in C (SDK.md section 14, header <nexvyn.h>).
 * Every .c file of the bundle is compiled on the console by TinyCC when the app opens: no build step on the PC.
 * Define only the app_* callbacks you need. Optional numbers are 0, optional strings NULL. */
#include <nexvyn.h>
#include <string.h>

static int taps;

static void bump(int n) {
    taps = n;
    store_setNum("taps", taps);  /* store keeps small values between runs (the app's own data folder) */
}

/* once, when the window opens; arg = the file / link the app was opened with, or "" */
void app_load(const char* arg) {
    taps = (int)store_getNum("taps", 0);
}

/* every frame: draw everything and handle widgets; w, h = content size in pixels */
void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    gfx_color(theme_color("text"));
    gfx_text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w);
    gfx_color(theme_color("text2"));
    gfx_text(TR("edit_me"), 40, h / 2 - 24, 14, NULL, "center", w - 80);
    /* returned strings live for the next 15 SDK calls: nxv_fmt + TR1 are used right away here */
    if (ui_button(TR1("tap", nxv_fmt("%d", taps)), w / 2 - 90, h / 2 + 20, 180, 40, "primary", NULL, true)) {
        bump(taps + 1);
        audio_play("pop", 0, 0);
    }
}

void app_event(const nxv_event* e) {
    if (strcmp(e->type, "keydown") == 0 && e->key && strcmp(e->key, "space") == 0) bump(taps + 1);
}

void app_menu(void) {
    menu_begin(TR("app"));
    menu_item(TR("reset"), 1, NULL, false, true);
}

void app_onmenu(int id) {
    if (id == 1) bump(0);
}
