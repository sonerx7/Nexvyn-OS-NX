/* Nexvyn Native SDK library - system services (nxn_sys.h) in the stand-alone / exclusive build.
 * Notification, clipboard, rumble, dialogs, folder grants, save backups and permissions belong to Nexvyn OS's user
 * interface, so a program that runs on its own gets NXN_ERR_UNSUPPORTED (no NXN_CAP_* bit is set) and keeps working.
 * Windowed apps get the real implementation from Nexvyn OS (source/runtimes/nxwin_sys.cpp). */
#include "nxn_internal.h"

nxn_result nxn_perm_query(const char* name, nxn_perm_state* out) {
    (void)name;
    (void)out;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_perm_request(const char* name, nxn_perm_state* out) {
    (void)name;
    (void)out;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_notify(const char* title, const char* body) {
    (void)title;
    (void)body;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_clipboard_get(char* buf, size_t cap, size_t* len) {
    (void)buf;
    (void)cap;
    (void)len;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_clipboard_set(const char* text) {
    (void)text;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_rumble(float strength, uint32_t ms) {
    (void)strength;
    (void)ms;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_sfx_play(const char* name_or_path, float volume, int32_t loops) {
    (void)name_or_path;
    (void)volume;
    (void)loops;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_tone(float freq_hz, float seconds, float volume, uint32_t wave) {
    (void)freq_hz;
    (void)seconds;
    (void)volume;
    (void)wave;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_sfx_stop_all(void) { return NXN_ERR_UNSUPPORTED; }
nxn_result nxn_input_action_buttons(const char* action, uint64_t* mask) {
    (void)action;
    if (mask) *mask = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_pick(const nxn_pick_params* params, char* path, size_t cap) {
    (void)params;
    if (path && cap) path[0] = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_grant_get(uint32_t index, char* path, size_t cap) {
    (void)index;
    if (path && cap) path[0] = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_grant_check(const char* path, int* granted) {
    (void)path;
    if (granted) *granted = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_grant_revoke(const char* path) {
    (void)path;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_save_path(char* path, size_t cap) {
    if (path && cap) path[0] = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_save_backup(const char* slot) {
    (void)slot;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_save_restore(const char* slot) {
    (void)slot;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_save_backup_get(uint32_t index, char* slot, size_t cap) {
    (void)index;
    if (slot && cap) slot[0] = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_save_backup_delete(const char* slot) {
    (void)slot;
    return NXN_ERR_UNSUPPORTED;
}

/* NexGFX backend table (nexgfx_backend.h): a program on its own has no system renderer, so the kit's ngfx_* shell uses the
 * renderer compiled into it. */
#include "nexvyn/nexgfx_backend.h"
const nxn_ngfx_table* nxn_ngfx_backend(uint32_t gen) {
    (void)gen;
    return NULL;
}
