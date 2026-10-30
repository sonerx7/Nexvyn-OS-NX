/* nexvyn.h - the Nexvyn OS app SDK (1.5) for C apps (sdk/SDK.en.md, section "C").
 *
 * A C app is a .nxvapp bundle whose app.json has "runtime": "c" (or "main": "main.c"). Every .c file of the bundle is
 * compiled on the console by TinyCC when the app starts; there is no build step on the PC. Define the callbacks you need
 * (all optional) and call the SDK functions below: they are the Lua/Python SDK with the dot replaced by an underscore
 * (gfx.rect -> gfx_rect, ui.iconButton -> ui_iconButton).
 *
 * Conventions
 *   - Optional arguments: pass 0 for numbers and NULL for strings to get the SDK default.
 *   - Colors are strings: "#RRGGBB", "#RRGGBBAA", theme_color("accent") or rgba(r, g, b, a). NULL = the current color.
 *   - Returned strings belong to the system and stay valid for the next 15 SDK calls: copy them to keep them.
 *   - Indexes are 0-based (ui_segmented, ui_alert buttons, g3d_custom vertex indices).
 *   - Callbacks get the `user` pointer you passed along.
 *   - malloc/free are counted: an app may use 64 MB (malloc returns NULL past it). Memory still allocated is freed
 *     when the window closes.
 * C apps run native code: they are not sandboxed like Lua/JavaScript/Python apps and a crash or an endless loop stops
 * Nexvyn OS. The user is asked once before a third-party C app runs. */
#ifndef NEXVYN_H
#define NEXVYN_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define NEXVYN_SDK_VERSION "1.5"

/* ------------------------------------------------------------------ records */
typedef struct {
    const char* type;    /* "mousedown" "mouseup" "mousemove" "scroll" "keydown" "keyup" "text" "paddown" "padup" "pinch" "rotate" */
    float x, y, dx, dy, scale, angle;
    const char* button;  /* "left" "right" "middle" */
    const char* key;     /* "a".."z" "0".."9" "left" "enter" "escape" "space" ... */
    const char* text;    /* typed UTF-8 (type "text") */
    const char* pad;     /* "a" "b" "x" "y" "l" "r" "zl" "zr" "plus" "minus" "up" "down" "left" "right" ... */
    int clicks;
    bool touch, shift, ctrl, cancel;
} nxv_event;

typedef struct {
    bool hovered, held, pressed, clicked, rightClicked, doubleClicked;
    float dx, dy;
} nxv_hit;

typedef struct {
    int year, month, day, hour, min, sec, wday, yday;
    int64_t epoch;
} nxv_date;

typedef struct {
    char name[256];
    char path[768];
    bool dir;
    double size, mtime;
} nxv_entry;

typedef struct {
    bool ok;               /* 2xx/3xx */
    int status;
    const char* body;
    size_t bodyLen;
    const char* error;
    const char* url;       /* after redirects */
    const char* contentType;
    const char* headers;   /* "name: value\n" lines, lowercase names */
} nxv_response;

typedef struct {
    const char* label;     /* "-" = separator */
    int id;
    const char* icon;      /* Material icon name or NULL */
    bool checked, disabled;
} nxv_menu_item;

typedef struct {
    int id;
    int64_t at;
    char title[128], body[256], arg[256];
} nxv_scheduled;

/* ------------------------------------------------------------------ callback types */
typedef void (*nxv_fn)(void* user);
typedef void (*nxv_int_fn)(int value, void* user);
typedef void (*nxv_bool_fn)(bool value, void* user);
typedef void (*nxv_str_fn)(const char* text, void* user);          /* NULL when cancelled */
typedef void (*nxv_net_fn)(const nxv_response* res, void* user);
typedef void (*nxv_json_fn)(const char* json, const char* error, void* user);  /* JSON text, or NULL + error */
typedef void (*nxv_done_fn)(bool ok, const char* pathOrError, void* user);
typedef void (*nxv_progress_fn)(double now, double total, void* user);

/* ------------------------------------------------------------------ callbacks your app defines (all optional) */
void app_load(const char* arg);   /* once; arg = file / link / "" the app was opened with */
void app_open(const char* arg);   /* asked to open something else while running */
void app_update(float dt);        /* every frame; define it only for animation (the window is then redrawn every frame) */
void app_draw(float w, float h);  /* every frame: draw and handle widgets */
void app_event(const nxv_event* e);
void app_menu(void);              /* build the menu bar with menu_begin / menu_item / menu_separator */
void app_onmenu(int id);
bool app_close(void);             /* false keeps the window open */
void app_search(const char* query); /* answer with search_result(...) */
void app_suspend(void);
void app_resume(void);
void app_focus(bool focused);
void app_autosave(void);
bool app_unsaved(void);

void menu_begin(const char* title);
void menu_item(const char* label, int id, const char* shortcut, bool checked, bool enabled);
void menu_separator(void);
void search_result(const char* title, const char* subtitle, const char* icon, const char* arg);

/* ------------------------------------------------------------------ gfx */
void gfx_color(const char* color);
void gfx_clear(const char* color);
void gfx_rect(float x, float y, float w, float h, float radius, const char* color);
void gfx_rectLine(float x, float y, float w, float h, float radius, float width);
void gfx_circle(float x, float y, float r, const char* color);
void gfx_circleLine(float x, float y, float r, float width);
void gfx_line(float x1, float y1, float x2, float y2, float width);
void gfx_lines(const float* xy, int points, float width, bool closed);
void gfx_poly(const float* xy, int points, const char* color);
void gfx_gradient(float x, float y, float w, float h, const char* c1, const char* c2, bool horizontal, float radius);
void gfx_arc(float x, float y, float r, float a0, float a1, float width);
void gfx_pie(float x, float y, float r, float a0, float a1);
void gfx_shadow(float x, float y, float w, float h, float radius, float blur, float dy);
float gfx_text(const char* s, float x, float y, float size, const char* font, const char* align, float width);
float gfx_textWidth(const char* s, float size, const char* font);
float gfx_textHeight(float size, const char* font);
float gfx_wrap(const char* s, float x, float y, float w, float size, const char* font, const char* align, float spacing);
float gfx_measureWrap(const char* s, float w, float size, const char* font);
void gfx_icon(const char* name, float x, float y, float size, const char* color);
bool gfx_image(const char* path, int* w, int* h);  /* loads (cached); "bundle:/img.png" for files in the bundle */
void gfx_draw(const char* path, float x, float y, float w, float h, float radius, const char* tint);  /* w, h 0 = natural */
void gfx_drawRegion(const char* path, float sx, float sy, float sw, float sh, float x, float y, float w, float h, float angleDeg);
void gfx_push(float dx, float dy);
void gfx_pop(void);
void gfx_clip(float x, float y, float w, float h);
void gfx_unclip(void);
void gfx_alpha(float a);
void gfx_unalpha(void);
void gfx_size(float* w, float* h);
const char* rgba(int r, int g, int b, int a);  /* "#RRGGBBAA" */
const char* theme_color(const char* name);      /* "bg" "text" "accent" "red" ... */
bool theme_dark(void);

/* ------------------------------------------------------------------ ui (immediate mode, call inside app_draw) */
bool ui_button(const char* label, float x, float y, float w, float h, const char* style, const char* icon, bool enabled);
bool ui_iconButton(const char* icon, float x, float y, float w, float h, const char* tint, bool active, const char* id);
bool ui_toggle(const char* id, bool value, float x, float y);
bool ui_checkbox(const char* label, bool value, float x, float y);
bool ui_radio(const char* label, bool selected, float x, float y);
float ui_slider(const char* id, float value, float lo, float hi, float x, float y, float w, float step);
/* edits buf (size bytes, always 0-terminated); true when the text changed */
bool ui_textfield(const char* id, char* buf, size_t size, float x, float y, float w, float h, const char* placeholder, const char* flags);
bool ui_submitted(const char* id);
int ui_segmented(const char* id, const char** items, int count, int selected, float x, float y, float w, float h);
int ui_dropdown(const char* id, const char** items, int count, int selected, float x, float y, float w, float h);
void ui_label(const char* s, float x, float y, float size, const char* color, const char* font);
void ui_progress(float value, float x, float y, float w, float h);
void ui_spinner(float x, float y, float r);
int ui_row(const char* id, float x, float y, float w, float h, bool selected);  /* 0, 1 clicked, 2 double-clicked */
void ui_group(float x, float y, float w, float h);
void ui_separator(float x1, float y, float x2);
float ui_beginScroll(const char* id, float x, float y, float w, float h, float contentH, float contentW, float* scrollX);
void ui_endScroll(void);
nxv_hit ui_hit(const char* id, float x, float y, float w, float h);
void ui_mouse(float* x, float* y, bool* down, bool* hovering);
void ui_focus(const char* id);
void ui_contextMenu(const nxv_menu_item* items, int count, nxv_int_fn fn, void* user);
void ui_alert(const char* title, const char* message, const char** buttons, int count, nxv_int_fn fn, void* user);
void ui_prompt(const char* title, const char* message, const char* text, nxv_str_fn fn, void* user);
void ui_openFile(nxv_str_fn fn, void* user, const char** exts, int count, const char* title);
void ui_saveFile(nxv_str_fn fn, void* user, const char* name, const char* title);
void ui_keyboard(const char* text, nxv_str_fn fn, void* user, const char* guide);

/* ------------------------------------------------------------------ files (relative paths: the app's data folder) */
char* fs_read(const char* path, size_t* len);  /* malloc'd and 0-terminated (free it), NULL on failure */
bool fs_write(const char* path, const char* data, size_t len);
bool fs_append(const char* path, const char* data, size_t len);
bool fs_exists(const char* path);
bool fs_isdir(const char* path);
int fs_list(const char* path, bool hidden, nxv_entry* out, int max);  /* returns the number of entries (may be > max) */
bool fs_mkdir(const char* path);
bool fs_remove(const char* path, bool permanently);
bool fs_rename(const char* from, const char* to);
bool fs_copy(const char* from, const char* to);
const char* fs_path(const char* path);
const char* fs_dir(const char* which);

/* ------------------------------------------------------------------ store (small values kept between runs) */
double store_getNum(const char* key, double def);
const char* store_getStr(const char* key, const char* def);
bool store_getBool(const char* key, bool def);
const char* store_getJson(const char* key);  /* NULL when missing */
void store_setNum(const char* key, double v);
void store_setStr(const char* key, const char* v);
void store_setBool(const char* key, bool v);
bool store_setJson(const char* key, const char* json);
void store_save(void);
const char* json_pretty(const char* json);    /* NULL for invalid JSON */

/* ------------------------------------------------------------------ network (asynchronous; needs "network") */
void net_get(const char* url, const char* headers, nxv_net_fn fn, void* user);  /* headers: "Name: value\n" lines or NULL */
void net_post(const char* url, const char* body, const char* contentType, const char* headers, nxv_net_fn fn, void* user);
void net_request(const char* method, const char* url, const char* body, const char* contentType, const char* headers,
                 nxv_net_fn fn, void* user);
void net_json(const char* url, const char* headers, nxv_json_fn fn, void* user);
void net_download(const char* url, const char* path, nxv_done_fn fn, nxv_progress_fn progress, void* user);
const char* net_encode(const char* s);

/* ------------------------------------------------------------------ system */
double sys_time(void);
int64_t sys_epoch(void);
nxv_date sys_date(int64_t epoch);  /* 0 = now */
void sys_battery(int* percent, bool* charging);
bool sys_online(void);
const char* sys_lang(void);
const char* sys_username(void);
const char* sys_model(void);
const char* sys_firmware(void);
bool sys_notify(const char* title, const char* body);
bool sys_open(const char* pathOrLink);
bool sys_launch(const char* appId, const char* arg);
const char* sys_clipboard(void);           /* every app may use the clipboard (no permission) */
bool sys_setClipboard(const char* text);
void sys_log(const char* fmt, ...);        /* printf-style, to the app's log (printf and puts go there too) */
void sys_exit(void);
void sys_title(const char* text);
float sys_fps(void);
void sys_vibrate(float strength, int ms);
void sys_speak(const char* text, const char* lang);  /* text to speech, queued; lang NULL = the voice setting (no permission) */
void sys_stopSpeaking(void);
const char* sys_appid(void);
const char* sys_sdkVersion(void);
bool sys_share(const char* textOrPath);
int sys_schedule(int64_t epoch, const char* title, const char* body, const char* arg);  /* id, 0 on failure (see the log) */
bool sys_unschedule(int id);
int sys_scheduled(nxv_scheduled* out, int max);
bool sys_hasPermission(const char* name);
void sys_requestPermission(const char* name, nxv_bool_fn fn, void* user);
void sys_memory(size_t* used, size_t* limit);
const char* sys_appUrl(const char* appId, const char* arg);
const char* nxv_fmt(const char* fmt, ...);  /* snprintf into a system buffer: TR1("score", nxv_fmt("%d", n)) */

/* ------------------------------------------------------------------ audio */
int audio_tone(float freq, float seconds, float volume, const char* wave);
int audio_play(const char* nameOrPath, float volume, int loops);
void audio_stop(int channel);
bool audio_music(const char* path);
void audio_musicStop(void);
void audio_musicPause(bool paused);

/* ------------------------------------------------------------------ input */
bool input_down(const char* button);
bool input_pressed(const char* button);
bool input_released(const char* button);
void input_stick(const char* which, float* x, float* y);
bool input_key(const char* name);
bool input_touch(void);
void input_motion(float out[9]);  /* ax ay az gx gy gz pitch roll yaw */

/* ------------------------------------------------------------------ timers */
int timer_after(double seconds, nxv_fn fn, void* user);
int timer_every(double seconds, nxv_fn fn, void* user);
void timer_cancel(int id);

/* ------------------------------------------------------------------ translations: lang/<code>.json of the bundle */
const char* TR(const char* key);
const char* TR1(const char* key, const char* a0);
const char* TR2(const char* key, const char* a0, const char* a1);
const char* TR3(const char* key, const char* a0, const char* a1, const char* a2);

/* ------------------------------------------------------------------ 3D (meshes are ids; 0 = none) */
int g3d_mesh(const char* kind, float a, float b, float c, float d);
int g3d_load(const char* path, float size);
int g3d_custom(const float* xyz, int vertices, const int* indices, int count, const char** colors, bool flat, const float* uvs);
void g3d_setColor(int mesh, const char* color);
void g3d_flat(int mesh, bool flat);
int g3d_triangles(int mesh);
bool g3d_setTexture(int mesh, const char* path);
const char* g3d_texture(int mesh);
void g3d_free(int mesh);
bool g3d_gpu(void);
void g3d_begin(float x, float y, float w, float h, float fov, float zNear, float zFar);
void g3d_camera(float ex, float ey, float ez, float tx, float ty, float tz);
void g3d_light(float dx, float dy, float dz, float ambient, const char* color);
void g3d_fog(const char* color, float start, float end);
void g3d_draw(int mesh, float x, float y, float z, float rx, float ry, float rz, float sx, float sy, float sz, const char* tint,
              const char* flags);
void g3d_line(float x1, float y1, float z1, float x2, float y2, float z2, const char* color, float width);
void g3d_point(float x, float y, float z, float size, const char* color);
bool g3d_project(float x, float y, float z, float* sx, float* sy, float* depth);
int g3d_finish(void);

#endif
