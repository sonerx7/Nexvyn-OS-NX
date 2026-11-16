#include <nexvyn.h>
#include <stdio.h>
#include <string.h>
static float volume = 0.5f, zoom = 1, angle = 0;
static char name[96];
static int selected;
static char last[128];
static float lastw, lasth;
void app_event(const nxv_event* e) {
    if (!strcmp(e->type, "pinch")) { zoom *= e->scale; if (zoom < .25f) zoom = .25f; if (zoom > 4) zoom = 4; }
    if (!strcmp(e->type, "rotate")) angle += e->angle;
}
void app_draw(float w, float h) {
    int compact = w < 620;
    float shift = compact ? 46 : 0;
    if (w != lastw || h != lasth) {
        sys_log("Layout %s %.0f %.0f", compact ? "compact" : "wide", w, h);
        lastw = w; lasth = h;
    }
    const char* modes[] = {"Touch", "Gamepad", "Keyboard / mouse"};
    char status[128], label[40];
    gfx_clear(theme_color("window")); gfx_color(theme_color("text"));
    gfx_text("Input Lab", 20, 16, 19, "bold", "left", 0);
    gfx_text(compact ? "Touch, scroll, type and try two fingers" : "Drag sliders, swipe inside frames, type and try two fingers", 20, 48, 13.8f, NULL, "left", 0);
    selected = ui_dropdown("mode", modes, 3, selected, 20, 80, 230, 30);
    ui_textfield("name", name, sizeof name, compact ? 20 : 270, 80+shift, compact ? w-40 : w-290, 30, "Type here", NULL);
    volume = ui_slider("volume", volume, 0, 1, 20, 126+shift, w-40, 0);
    snprintf(status, sizeof status, "Value %.2f | Pinch %.2f | Rotation %.2f", volume, zoom, angle);
    if (strcmp(status, last)) { sys_log("%s", status); snprintf(last, sizeof last, "%s", status); }
    if (compact) snprintf(status, sizeof status, "Value %.2f | Pinch %.2f", volume, zoom);
    gfx_text(status, 20, 164+shift, 13.8f, NULL, "left", 0);
    ui_beginScroll("outer", 20, 200+shift, w-40, h-220-shift, 1100, 0, NULL);
    gfx_text(compact ? "Nested frame: swipe rows" : "Outer frame: swipe this text or any row", 12, 8, 15, "bold", "left", 0);
    ui_beginScroll("inner", 12, 44, w-90, 180, 900, 0, NULL);
    for (int i=0;i<20;++i) { snprintf(label,sizeof label,"Inner row %d",i+1); ui_button(label,8,i*44,w-130,36,"default",NULL,true); }
    ui_endScroll();
    for (int i=0;i<18;++i) { snprintf(label,sizeof label,"Outer row %d",i+1); ui_button(label,12,244+i*44,w-90,36,"default",NULL,true); }
    ui_endScroll();
}
