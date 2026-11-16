/* Nexvyn Native SDK library - nxn_phys.h in a stand-alone .nro: the collision core lives in Nexvyn OS, so every call
 * answers NXN_ERR_UNSUPPORTED here (nxn_caps_get has no NXN_CAP_PHYS). Inside Nexvyn OS (windowed mode) the system
 * serves these calls (source/runtimes/nxwin_phys.cpp). */
#include "nxn_internal.h"

nxn_result nxn_phys_world_create(uint32_t budget_mb, nxn_phys_world** out) {
    (void)budget_mb;
    if (out) *out = NULL;
    return NXN_ERR_UNSUPPORTED;
}
void nxn_phys_world_destroy(nxn_phys_world* w) { (void)w; }
nxn_result nxn_phys_add_mesh(nxn_phys_world* w, const float* xyz, uint32_t vertex_count, const uint32_t* indices,
                             uint32_t index_count, float x, float y, float z, uint32_t layer, int32_t* out_id) {
    (void)w, (void)xyz, (void)vertex_count, (void)indices, (void)index_count, (void)x, (void)y, (void)z, (void)layer;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_add_box(nxn_phys_world* w, float x, float y, float z, float hx, float hy, float hz, uint32_t layer,
                            int32_t* out_id) {
    (void)w, (void)x, (void)y, (void)z, (void)hx, (void)hy, (void)hz, (void)layer;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_set_pos(nxn_phys_world* w, int32_t id, float x, float y, float z) {
    (void)w, (void)id, (void)x, (void)y, (void)z;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_pos(nxn_phys_world* w, int32_t id, float* x, float* y, float* z) {
    (void)w, (void)id, (void)x, (void)y, (void)z;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_set_layer(nxn_phys_world* w, int32_t id, uint32_t layer) {
    (void)w, (void)id, (void)layer;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_remove(nxn_phys_world* w, int32_t id) {
    (void)w, (void)id;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_raycast(nxn_phys_world* w, float x, float y, float z, float dx, float dy, float dz, float max_dist,
                            uint32_t mask, nxn_phys_hit* hit) {
    (void)w, (void)x, (void)y, (void)z, (void)dx, (void)dy, (void)dz, (void)max_dist, (void)mask, (void)hit;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_raycast_all(nxn_phys_world* w, float x, float y, float z, float dx, float dy, float dz, float max_dist,
                                uint32_t mask, nxn_phys_hit* hits, uint32_t capacity, uint32_t* count) {
    (void)w, (void)x, (void)y, (void)z, (void)dx, (void)dy, (void)dz, (void)max_dist, (void)mask, (void)hits, (void)capacity;
    if (count) *count = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_sweep_sphere(nxn_phys_world* w, float x, float y, float z, float radius, float dx, float dy, float dz,
                                 float max_dist, uint32_t mask, nxn_phys_hit* hit) {
    (void)w, (void)x, (void)y, (void)z, (void)radius, (void)dx, (void)dy, (void)dz, (void)max_dist, (void)mask, (void)hit;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_sweep_capsule(nxn_phys_world* w, float x, float y, float z, float radius, float height, float dx,
                                  float dy, float dz, float max_dist, uint32_t mask, nxn_phys_hit* hit) {
    (void)w, (void)x, (void)y, (void)z, (void)radius, (void)height, (void)dx, (void)dy, (void)dz, (void)max_dist, (void)mask;
    (void)hit;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_overlap(nxn_phys_world* w, float x, float y, float z, float radius, uint32_t mask, int32_t* ids,
                            uint32_t capacity, uint32_t* count) {
    (void)w, (void)x, (void)y, (void)z, (void)radius, (void)mask, (void)ids, (void)capacity;
    if (count) *count = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_controller(nxn_phys_world* w, float x, float y, float z, const nxn_phys_controller_desc* desc,
                               int32_t* out_id) {
    (void)w, (void)x, (void)y, (void)z, (void)desc;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_move(nxn_phys_world* w, int32_t id, float vx, float vz, float dt, nxn_phys_state* out) {
    (void)w, (void)id, (void)vx, (void)vz, (void)dt, (void)out;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_jump(nxn_phys_world* w, int32_t id) {
    (void)w, (void)id;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_trigger(nxn_phys_world* w, uint32_t shape, float x, float y, float z, float a, float b, float c,
                            uint32_t layer, int32_t* out_id) {
    (void)w, (void)shape, (void)x, (void)y, (void)z, (void)a, (void)b, (void)c, (void)layer;
    if (out_id) *out_id = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_events(nxn_phys_world* w, nxn_phys_event* events, uint32_t capacity, uint32_t* count) {
    (void)w, (void)events, (void)capacity;
    if (count) *count = 0;
    return NXN_ERR_UNSUPPORTED;
}
nxn_result nxn_phys_stats(nxn_phys_world* w, nxn_phys_counts* out) {
    (void)w, (void)out;
    return NXN_ERR_UNSUPPORTED;
}
