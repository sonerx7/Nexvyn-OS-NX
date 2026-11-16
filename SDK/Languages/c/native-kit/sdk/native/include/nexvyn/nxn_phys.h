/* Nexvyn Native SDK - 3D collision: static meshes and boxes, ray / sphere / capsule queries, capsule character
 * controllers and trigger volumes (the same core as the script SDK's phys.*, SDK 1.15).
 *
 *   nxn_phys_world* w;
 *   if (nxn_phys_world_create(0, &w) == NXN_OK) {
 *       int32_t floor, hero;
 *       nxn_phys_add_box(w, 0, -0.5f, 0, 50, 0.5f, 50, 0, &floor);
 *       nxn_phys_controller(w, 0, 0, 0, NULL, &hero);
 *       nxn_phys_state st = NXN_STRUCT_INIT(nxn_phys_state);
 *       nxn_phys_move(w, hero, 3.0f, 0.0f, 1.0f / 60, &st);   // every frame: walk, slide, step, fall
 *       nxn_phys_hit hit = NXN_STRUCT_INIT(nxn_phys_hit);
 *       if (nxn_phys_raycast(w, 0, 5, 0, 0, -1, 0, 0, 0, &hit) == NXN_OK) { ... hit.dist, hit.nx ... }
 *       nxn_phys_world_destroy(w);
 *   }
 *
 * Available inside Nexvyn OS (windowed apps, NXN_CAP_PHYS); a stand-alone .nro answers NXN_ERR_UNSUPPORTED.
 * Units are the app's (metres for most games), y is up. Zero means "the default" for every number marked so:
 * max_dist 0 = 1000, mask 0 = every layer, layer 0 = the kind's default (bodies 1, controllers 2, triggers 4), dt 0 =
 * 1/60 s. Layers are bit masks: a query sees an object when (object layer & mask) != 0. Rays and sweeps never hit
 * triggers; nxn_phys_overlap sees them.
 * Threads: queries (raycast, sweep, overlap, pos, stats) may run on several app threads at once on one world while no
 * other call changes it; every other call needs the world to itself. Memory: a world holds at most budget_mb of
 * collision data; a world left alive is freed at the app's end. */
#ifndef NEXVYN_NXN_PHYS_H
#define NEXVYN_NXN_PHYS_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_phys_world nxn_phys_world; /* opaque */

enum {
    NXN_PHYS_BOX = 0,     /* trigger shape: half extents a, b, c */
    NXN_PHYS_SPHERE = 1,  /* radius a */
    NXN_PHYS_CAPSULE = 2  /* standing capsule: radius a, total height b (its bottom at the position) */
};

typedef struct nxn_phys_hit {
    uint32_t size;
    int32_t id;        /* body or controller */
    int32_t tri;       /* triangle number in the body's mesh as it was given; -1 for a controller */
    float dist;        /* along the direction (a unit vector is made of it) */
    float x, y, z;     /* contact point */
    float nx, ny, nz;  /* unit normal, facing the query */
} nxn_phys_hit;

typedef struct nxn_phys_controller_desc {
    uint32_t size;
    float radius;      /* 0 = 0.35 */
    float height;      /* total, caps included; 0 = 1.8 */
    float slope_deg;   /* steepest walkable ground; 0 = 45 */
    float step;        /* highest step walked up; 0 = 0.35 (a desc with step < 0 walks up nothing) */
    float gravity;     /* m/s^2; 0 = 20 */
    float jump_speed;  /* m/s; 0 = 6.5 */
    uint32_t layer;    /* 0 = 2 */
    uint32_t mask;     /* bodies it collides with; 0 = every layer but 2 and 4 */
} nxn_phys_controller_desc;

typedef struct nxn_phys_state {
    uint32_t size;
    float x, y, z;     /* feet */
    float vy;          /* vertical speed */
    uint32_t grounded; /* 1 on walkable ground */
    uint32_t wall;     /* 1: the last move touched a wall or a slope too steep */
    uint32_t ceiling;  /* 1: the last move hit something above */
    int32_t ground;    /* body under the feet (0: none); a body that moves carries the controller */
    float nx, ny, nz;  /* ground normal */
} nxn_phys_state;

typedef struct nxn_phys_event {
    uint32_t size;
    int32_t trigger;
    int32_t other;     /* controller */
    uint32_t enter;    /* 1 enter, 0 exit */
} nxn_phys_event;

typedef struct nxn_phys_counts {
    uint32_t size;
    uint32_t bodies, controllers, triggers;
    uint32_t triangles;
    uint32_t memory_kb, budget_kb;
} nxn_phys_counts;

/* A new world; budget_mb 0 = 64 (1..512). NXN_ERR_LIMIT: the app already has 16 worlds.
 * Thread: any app thread. Memory: *out is a system-owned handle until nxn_phys_world_destroy or the app's end. */
NXN_API nxn_result nxn_phys_world_create(uint32_t budget_mb, nxn_phys_world** out);
/* Frees the world and everything in it. NULL is ignored. Thread: any app thread, no other call on it running. */
NXN_API void nxn_phys_world_destroy(nxn_phys_world* w);
/* A static triangle mesh at (x, y, z): xyz holds 3 floats per vertex, indices 3 per triangle (index_count 0: every 3
 * vertices are one). NXN_ERR_INVALID: a bad index or a coordinate that is not finite; NXN_ERR_LIMIT: over the budget.
 * The data is copied. Thread: any app thread. Memory: the caller keeps xyz and indices. */
NXN_API nxn_result nxn_phys_add_mesh(nxn_phys_world* w, const float* xyz, uint32_t vertex_count, const uint32_t* indices,
                                     uint32_t index_count, float x, float y, float z, uint32_t layer, int32_t* out_id);
/* A solid box: centre and half extents (> 0). */
NXN_API nxn_result nxn_phys_add_box(nxn_phys_world* w, float x, float y, float z, float hx, float hy, float hz, uint32_t layer,
                                    int32_t* out_id);
/* Moves a body (a moving platform carries the controllers standing on it) or a trigger; teleports a controller.
 * NXN_ERR_NOT_FOUND for an unknown id. */
NXN_API nxn_result nxn_phys_set_pos(nxn_phys_world* w, int32_t id, float x, float y, float z);
/* Position of an object (a controller: its feet). Any pointer may be NULL. */
NXN_API nxn_result nxn_phys_pos(nxn_phys_world* w, int32_t id, float* x, float* y, float* z);
NXN_API nxn_result nxn_phys_set_layer(nxn_phys_world* w, int32_t id, uint32_t layer);
NXN_API nxn_result nxn_phys_remove(nxn_phys_world* w, int32_t id);
/* The nearest hit along (dx, dy, dz) within max_dist: NXN_OK and *hit (hit->size set by the caller), or
 * NXN_ERR_NOT_FOUND. Hits bodies and controllers (projectiles). */
NXN_API nxn_result nxn_phys_raycast(nxn_phys_world* w, float x, float y, float z, float dx, float dy, float dz, float max_dist,
                                    uint32_t mask, nxn_phys_hit* hit);
/* Every hit, nearest first: up to capacity records of hits[0].size bytes each; *count gets how many were written. */
NXN_API nxn_result nxn_phys_raycast_all(nxn_phys_world* w, float x, float y, float z, float dx, float dy, float dz,
                                        float max_dist, uint32_t mask, nxn_phys_hit* hits, uint32_t capacity, uint32_t* count);
/* A sphere moved from (x, y, z): its first contact (fast projectiles do not pass thin walls). */
NXN_API nxn_result nxn_phys_sweep_sphere(nxn_phys_world* w, float x, float y, float z, float radius, float dx, float dy,
                                         float dz, float max_dist, uint32_t mask, nxn_phys_hit* hit);
/* A standing capsule (bottom at x, y, z, total height) moved: its first contact. */
NXN_API nxn_result nxn_phys_sweep_capsule(nxn_phys_world* w, float x, float y, float z, float radius, float height, float dx,
                                          float dy, float dz, float max_dist, uint32_t mask, nxn_phys_hit* hit);
/* Ids of everything a sphere touches (bodies, controllers, triggers), in id order. */
NXN_API nxn_result nxn_phys_overlap(nxn_phys_world* w, float x, float y, float z, float radius, uint32_t mask, int32_t* ids,
                                    uint32_t capacity, uint32_t* count);
/* A capsule character with its feet at (x, y, z); desc NULL = the defaults. */
NXN_API nxn_result nxn_phys_controller(nxn_phys_world* w, float x, float y, float z, const nxn_phys_controller_desc* desc,
                                       int32_t* out_id);
/* One step of a controller: horizontal speed (vx, vz) for dt seconds (0 = 1/60, at most 0.1), gravity, slopes, steps,
 * sliding along walls, staying on the ground. out may be NULL. */
NXN_API nxn_result nxn_phys_move(nxn_phys_world* w, int32_t id, float vx, float vz, float dt, nxn_phys_state* out);
/* Jumps on the next move. NXN_ERR_NOT_READY when the controller is not on the ground. */
NXN_API nxn_result nxn_phys_jump(nxn_phys_world* w, int32_t id);
/* A trigger volume (NXN_PHYS_BOX / SPHERE / CAPSULE; sizes as listed there, 0 = a for b and c). */
NXN_API nxn_result nxn_phys_trigger(nxn_phys_world* w, uint32_t shape, float x, float y, float z, float a, float b, float c,
                                    uint32_t layer, int32_t* out_id);
/* Controllers entering and leaving triggers since the last call, ordered by trigger, then controller: up to capacity
 * records of events[0].size bytes; the rest stay for the next call. */
NXN_API nxn_result nxn_phys_events(nxn_phys_world* w, nxn_phys_event* events, uint32_t capacity, uint32_t* count);
NXN_API nxn_result nxn_phys_stats(nxn_phys_world* w, nxn_phys_counts* out);

NXN_EXTERN_C_END

#endif
