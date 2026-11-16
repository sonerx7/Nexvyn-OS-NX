/* Nexvyn Native SDK library - nxn_nav.h in a stand-alone .nro: the navigation core lives in Nexvyn OS, so every call
 * answers NXN_ERR_UNSUPPORTED here (nxn_caps_get has no NXN_CAP_NAV). Inside Nexvyn OS (windowed mode) the system
 * serves these calls (source/runtimes/nxwin_nav.cpp). */
#include "nxn_internal.h"

nxn_result nxn_nav_bake(nxn_phys_world* world, const nxn_nav_desc* desc, nxn_nav** out) {
    (void)world, (void)desc;
    if (out) *out = NULL;
    return NXN_ERR_UNSUPPORTED;
}
void nxn_nav_destroy(nxn_nav* nav) { (void)nav; }
nxn_result nxn_nav_state(nxn_nav* nav, nxn_nav_info* out) {
    (void)nav, (void)out;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_cancel(nxn_nav* nav) {
    (void)nav;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_path(nxn_nav* nav, float sx, float sy, float sz, float tx, float ty, float tz, uint32_t flags, float snap,
                        float* points, uint32_t capacity, nxn_nav_path_info* info) {
    (void)nav, (void)sx, (void)sy, (void)sz, (void)tx, (void)ty, (void)tz, (void)flags, (void)snap, (void)points, (void)capacity;
    (void)info;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_snap(nxn_nav* nav, float x, float y, float z, float max_dist, float* out_x, float* out_y, float* out_z) {
    (void)nav, (void)x, (void)y, (void)z, (void)max_dist, (void)out_x, (void)out_y, (void)out_z;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_block(nxn_nav* nav, float x, float y, float z, float radius, float height, int32_t* out_id) {
    (void)nav, (void)x, (void)y, (void)z, (void)radius, (void)height;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_cost(nxn_nav* nav, float x, float y, float z, float radius, float height, float mult, int32_t* out_id) {
    (void)nav, (void)x, (void)y, (void)z, (void)radius, (void)height, (void)mult;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_unblock(nxn_nav* nav, int32_t id) {
    (void)nav, (void)id;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_agent_add(nxn_nav* nav, float x, float y, float z, const nxn_nav_agent_desc* desc, int32_t* out_id) {
    (void)nav, (void)x, (void)y, (void)z, (void)desc;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_agent_goto(nxn_nav* nav, int32_t agent, float x, float y, float z) {
    (void)nav, (void)agent, (void)x, (void)y, (void)z;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_agent_stop(nxn_nav* nav, int32_t agent) {
    (void)nav, (void)agent;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_agent_remove(nxn_nav* nav, int32_t agent) {
    (void)nav, (void)agent;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_agent_state_get(nxn_nav* nav, int32_t agent, nxn_nav_agent_state* out) {
    (void)nav, (void)agent, (void)out;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_nav_update(nxn_nav* nav, float dt, nxn_nav_event* events, uint32_t capacity, uint32_t* count) {
    (void)nav, (void)dt, (void)events, (void)capacity;
    if (count) *count = 0;
    return NXN_ERR_UNSUPPORTED;
}
