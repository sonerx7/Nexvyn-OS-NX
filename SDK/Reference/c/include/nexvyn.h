/* nexvyn.h - the Nexvyn OS app SDK (1.5) for C apps (sdk/SDK.md, section "C").
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
    /* SDK 1.9 (net_fetch; false / "" for net_get and the other older calls). There is no parsed "data" field as in
     * Lua, JavaScript and Python: body holds the JSON text, parse it yourself. */
    bool fromCache;        /* answered from the offline cache ("cache" option) */
    bool stale;            /* from the cache because the network failed: the data may be old */
    const char* path;      /* the file written with "saveTo", or "" */
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
void audio_stopAll(void);         /* every sound the app started (its music stream stays) */
bool audio_music(const char* path);
void audio_musicStop(void);
void audio_musicPause(bool paused);

/* ------------------------------------------------------------------ input */
bool input_down(const char* button);
bool input_pressed(const char* button);
bool input_released(const char* button);
void input_stick(const char* which, float* x, float* y);
bool input_key(const char* name);
bool input_action(const char* name);  /* a button the user mapped to this function ("back", "select"...) was pressed this frame */
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
/* 3D models (SDK 1.8): .glb .gltf .fbx .obj .stl with materials, textures and skeletal animation. Model ids work with
 * g3d_draw, g3d_triangles and g3d_free like mesh ids. size > 0 fits the model into size, centered, standing on y = 0.
 * Clips are named (or "#0", "#1"... by position). x .. s place the model like g3d_draw (s = uniform scale, 0 = 1). */
int g3d_model(const char* path, float size);                  /* 0 on failure (the reason is in the app log) */
/* The same without blocking the app: the file is parsed in the background and fn(model, NULL, user) or
 * fn(0, error, user) is called later on the main thread. */
typedef void (*nxv_model_fn)(int model, const char* error, void* user);
void g3d_loadModel(const char* path, float size, nxv_model_fn fn, void* user);
const char* g3d_modelInfo(int model);                           /* JSON {"triangles", "bones", "animations": [...]} */
bool g3d_modelPlay(int model, const char* clip, bool loop, float speed, float fade);  /* speed 0 = 1 */
void g3d_modelStop(int model, float fade);
void g3d_modelUpdate(int model, float dt);
float g3d_modelTime(int model);
void g3d_modelSetTime(int model, float t);
const char* g3d_modelClip(int model);                           /* NULL when no clip plays */
bool g3d_modelPlaying(int model);
bool g3d_modelNode(int model, const char* node, float x, float y, float z, float rx, float ry, float rz, float s,
                   float* ox, float* oy, float* oz);
bool g3d_modelNodeMatrix(int model, const char* node, float x, float y, float z, float rx, float ry, float rz, float s,
                         float out[16]);
void g3d_drawMatrix(int mesh, const float matrix[16], const char* tint, const char* flags);  /* mesh or model */
/* BEGIN GENERATED api:g3d_renderer:c-header (tools/api/gen.py; do not edit) */
/* SDK 1.9: the "pbr" renderer (PBR materials, real-time lights, shadows, HDR, bloom; SDK.md section 8b). Options are
 * JSON text with the keys of the Lua tables, e.g. g3d_addLight("{\"type\":\"point\",\"x\":1,\"y\":2,\"z\":0}"). */
const char* g3d_renderer(const char* name);                     /* "pbr" / "basic" (NULL = ask); the one frames use */
const char* g3d_caps(void);                                     /* JSON {"gpu", "pbr", "hdr", "shadows", "msaa", ...} */
const char* g3d_rendererInfo(void);                             /* JSON {"name": "NexGFX", "version", "backend", "renderer"} */
int g3d_addLight(const char* json);                             /* light id > 0 */
bool g3d_updateLight(int id, const char* json);                 /* false for an unknown id */
bool g3d_removeLight(int id);
void g3d_clearLights(void);
const char* g3d_lights(void);                                   /* JSON array of the lights */
void g3d_shadows(const char* json);                             /* "true", "false" or {"quality": "high", ...} */
void g3d_postfx(const char* json);                              /* {"exposure", "tonemap", "bloom", "threshold", "msaa", "hdr"} */
void g3d_environment(const char* json);                         /* {"sky", "ground", "intensity", "sun", "cubemap": [6 paths]} */
void g3d_material(int obj, const char* json, const char* name); /* mesh or model; json NULL = back to its own material;
                                                                 * keys as in Lua, e.g. {"transmission":0.9,"ior":1.5} */
/* the mesh or model drawn count times: 7 floats per instance (x, y, z, rx, ry, rz, scale) or a 16-float matrix */
void g3d_drawInstanced(int obj, const float* transforms, int count, const char* tint, const char* flags);
void g3d_drawInstancedMatrices(int obj, const float* matrices, int count, const char* tint, const char* flags);
/* END GENERATED api:g3d_renderer:c-header */

/* SDK 1.11: folder picker, kept folders, save backups (sdk/SDK.md "SDK 1.11"). */
/* BEGIN GENERATED api:ui_folder:c-header (tools/api/gen.py; do not edit) */
/* the folder picker: callback(JSON path, NULL), JSON null when the user cancels, or (NULL, error). options: {"title": "...", "remember": true} */
void ui_chooseFolder(const char* options, nxv_json_fn fn, void* user);
const char* ui_tokens(void);
/* END GENERATED api:ui_folder:c-header */
/* BEGIN GENERATED api:fs_keep:c-header (tools/api/gen.py; do not edit) */
const char* fs_folderGrants(void);
bool fs_folderGranted(const char* path);
bool fs_revokeFolder(const char* path);
const char* fs_savePath(void);
void fs_saveBackup(const char* slot, nxv_json_fn fn, void* user);
void fs_saveRestore(const char* slot, nxv_json_fn fn, void* user);
const char* fs_saveBackups(void);
void fs_saveDeleteBackup(const char* slot, nxv_json_fn fn, void* user);
/* END GENERATED api:fs_keep:c-header */

/* ------------------------------------------------------------------ SDK 1.9: feeds, media, network
 * sdk/SDK.md section 8d. Options are JSON text ("{\"retry\": 2, \"cache\": 300}"), NULL for none. Returned
 * strings stay valid for the next 15 SDK calls, like every other returned string: copy them to keep them. */
/* HTTP with every SDK 1.9 option (method, headers, json, form, multipart, file, saveTo, timeout, retry, cache,
 * cookies, responseType...). fn gets the response; progress(now, total) runs while it moves. Returns the id. */
int net_fetch(const char* options, nxv_net_fn fn, nxv_progress_fn progress, void* user);
void net_cancel(int id);                            /* fn is not called for a cancelled request */
void net_clearCookies(void);
double net_clearCache(void);                        /* bytes freed (responses and pictures) */
/* WebSocket: events come from net_wsPoll as a JSON array:
 * [{"type":"open"}, {"type":"message","data":"...","binary":false}, {"type":"close","code":1000,"reason":""},
 *  {"type":"error","message":"..."}]; binary data is base64 text. */
int net_ws(const char* url, const char* options);   /* {"headers":{...}, "protocols":"chat", "cookies":true} */
bool net_wsSend(int ws, const char* data, bool binary);
const char* net_wsPoll(int ws);
void net_wsClose(int ws, int code, const char* reason);  /* code 0 = 1000 */
const char* net_wsState(int ws);                    /* "connecting" "open" "closing" "closed" */
/* Sign-in in the console's web browser: {"url": "https://...authorize?client_id=...", "redirect":
 * "http://localhost/cb", "pkce": true}; fn(resultJson, NULL, user) with {"code", "state", "verifier", "params", "url"}
 * or fn(NULL, error, user). */
void net_oauth(const char* options, nxv_json_fn fn, void* user);
/* Pictures from the web, cached on disk and in memory; maxSize > 0 downscales (thumbnails). Returns the image path for
 * gfx_draw once it is ready, NULL while it loads (gfx_imageState tells "loading", "ready" or "error: ..."). */
const char* gfx_imageUrl(const char* url, int maxSize, int* w, int* h);
const char* gfx_imageState(const char* url, int maxSize);
/* Video and audio players (files or http(s), HLS too): {"loop":true, "muted":true, "volume":0.8, "autoplay":true,
 * "audioOnly":false, "start":0}. At most 3 per app. */
int media_open(const char* source, const char* options);
void media_play(int id);
void media_pause(int id);
void media_seek(int id, double seconds);
void media_set(int id, const char* options);        /* loop, muted, volume, speed */
const char* media_info(int id);                     /* JSON {"state", "position", "duration", "buffering", "width"...} */
void media_draw(int id, float x, float y, float w, float h, const char* fit);  /* "contain" (NULL), "cover", "stretch" */
void media_close(int id);
/* Virtualized feed (list or grid) with pull-to-refresh and infinite scroll. Options: {"itemHeight":80,
 * "heights":[...], "columns":3, "gap":4, "aspect":1, "refreshing":false, "loadingMore":false, "ahead":3}.
 * Draw items first..last at ui_feedItem's rectangle (content coordinates), then ui_endFeed: bit 1 = pull-to-refresh
 * released, bit 2 = near the end (load more). Indexes are 0-based. */
typedef struct {
    int first, last;
    float scrollY, contentHeight, pull;
} nxv_feed;
nxv_feed ui_beginFeed(const char* id, float x, float y, float w, float h, int count, const char* options);
void ui_feedItem(int index, float* x, float* y, float* w, float* h);
int ui_endFeed(void);
/* Swipe pager (vertical unless {"horizontal":true}; {"page":n} jumps): returns the position in pages (fractional
 * while it moves: draw page i at y + (i - pos) * h); *page = the page it settles on. */
float ui_pager(const char* id, float x, float y, float w, float h, int count, const char* options, int* page);
/* **bold**, links, @mentions and #hashtags; returns the height. *clicked = "link:<url>", "mention:<name>",
 * "hashtag:<tag>" on the frame one was tapped, else NULL. Options: {"color", "linkColor", "maxLines", "lineSpacing"}. */
float ui_richText(const char* id, const char* text, float x, float y, float w, float size, const char* options, const char** clicked);
float ui_measureRichText(const char* text, float w, float size, const char* options);
const char* sys_relativeTime(double epoch);         /* "now", "5m", "3h", "2d", "1w" or a date (the system language) */

#endif
