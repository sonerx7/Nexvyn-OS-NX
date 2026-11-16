/* Nexvyn Native SDK - 3D navigation: a walkable grid baked from an nxn_phys world, A* paths, blockers and cost areas,
 * walking agents (the same core as the script SDK's nav.*, SDK 1.15).
 *
 *   nxn_nav* nav;
 *   nxn_nav_desc d = NXN_STRUCT_INIT(nxn_nav_desc);          // zeros = defaults, the world's bounds
 *   if (nxn_nav_bake(world, &d, &nav) == NXN_OK) {           // returns at once: the bake runs on a worker thread
 *       nxn_nav_info info = NXN_STRUCT_INIT(nxn_nav_info);
 *       do { nxn_nav_state(nav, &info); } while (info.state == NXN_NAV_BAKING);   // once per frame, not a busy loop
 *       float pts[3 * 64];
 *       nxn_nav_path_info pi = NXN_STRUCT_INIT(nxn_nav_path_info);
 *       if (nxn_nav_path(nav, -6, 0, 0, 6, 0, 0, 0, 0, pts, 64, &pi) == NXN_OK) { ... pi.count points, pi.length ... }
 *       int32_t guard;
 *       nxn_nav_agent_add(nav, -6, 0, 0, NULL, &guard);
 *       nxn_nav_agent_goto(nav, guard, 6, 0, 0);
 *       nxn_nav_event ev[8]; uint32_t n;                     // every frame:
 *       ev[0].size = sizeof ev[0];
 *       nxn_nav_update(nav, 1.0f / 60, ev, 8, &n);
 *       nxn_nav_agent_state st = NXN_STRUCT_INIT(nxn_nav_agent_state);
 *       nxn_nav_agent_state_get(nav, guard, &st);             // st.x, st.y, st.z, st.yaw
 *       nxn_nav_destroy(nav);
 *   }
 *
 * Available inside Nexvyn OS (windowed apps, NXN_CAP_NAV); a stand-alone .nro answers NXN_ERR_UNSUPPORTED. Units are the
 * app's (metres for most games), y is up. Zero means "the default" for every number marked so. The grid keeps its own copy
 * of the world's bodies from the moment of nxn_nav_bake, so the world may change while the bake runs. Floors are the
 * upward-facing (counter-clockwise from above) triangles of the world's bodies; a capsule of radius and height must fit.
 * Threads: queries (path, snap, state, agent_state_get) may run on several app threads on one grid while no other call changes
 * it; every other call needs the grid to itself. Memory: a grid has a byte budget (budget_mb), the app all grids together
 * 64 MB; a grid left alive (a running bake is cancelled) is freed at the app's end. */
#ifndef NEXVYN_NXN_NAV_H
#define NEXVYN_NXN_NAV_H

#include "nxn_base.h"
#include "nxn_phys.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_nav nxn_nav; /* opaque */

enum {
    NXN_NAV_BAKING = 0,
    NXN_NAV_READY = 1,
    NXN_NAV_FAILED = 2,
    NXN_NAV_CANCELLED = 3
};

enum {
    NXN_NAV_NO_SMOOTH = 1,  /* nxn_nav_path flag: keep every grid step, no string-pulling */
    NXN_NAV_PARTIAL = 2     /* nxn_nav_path flag: an unreachable goal gives the way to the closest reached spot */
};

enum {
    NXN_NAV_AGENT_IDLE = 0,
    NXN_NAV_AGENT_MOVING = 1,
    NXN_NAV_AGENT_ARRIVED = 2,
    NXN_NAV_AGENT_FAILED = 3
};

enum {
    NXN_NAV_EVENT_ARRIVED = 0,
    NXN_NAV_EVENT_FAILED = 1,
    NXN_NAV_EVENT_REPLAN = 2
};

typedef struct nxn_nav_desc {
    uint32_t size;
    float cell;        /* cell edge; 0 = 0.5 (0.05 .. 10) */
    float radius;      /* capsule radius of the walker; 0 = 0.35 */
    float height;      /* capsule height; 0 = 1.8 */
    float slope_deg;   /* steepest walkable floor; 0 = 45 */
    float step;        /* highest step between floors; 0 = 0.35 */
    float min_x, min_y, min_z, max_x, max_y, max_z;  /* the box to scan; all zero = the world's bodies' bounds */
    uint32_t mask;     /* layers that count as ground and obstacles; 0 = 1 (static bodies) */
    uint32_t budget_mb; /* memory budget of this grid; 0 = 16 (1..64) */
} nxn_nav_desc;

typedef struct nxn_nav_info {
    uint32_t size;
    uint32_t state;    /* NXN_NAV_* */
    float progress;    /* 0..1 */
    uint32_t nodes, columns, nx, nz;
    uint32_t memory_kb, budget_kb;
    float bake_ms;
    uint32_t blockers, cost_areas, agents, version;
} nxn_nav_info;

typedef struct nxn_nav_path_info {
    uint32_t size;
    uint32_t count;    /* points of the path (may be more than the capacity: nothing beyond it was written) */
    uint32_t partial;  /* 1: the goal itself was not reached */
    float length;      /* metres along the points */
    float cost;        /* A* cost of the grid steps (length with the cost areas) */
} nxn_nav_path_info;

typedef struct nxn_nav_agent_desc {
    uint32_t size;
    float radius;      /* separation radius; 0 = 0.35 */
    float speed;       /* m/s; 0 = 3 */
    float turn;        /* rad/s; 0 = 8 */
    float stop;        /* arrived when this close to the goal; 0 = 0.2 */
} nxn_nav_agent_desc;

typedef struct nxn_nav_agent_state {
    uint32_t size;
    float x, y, z;     /* feet */
    float yaw;         /* radians, 0 looks along +z, positive turns towards +x */
    uint32_t state;    /* NXN_NAV_AGENT_* */
    float remaining;   /* metres left along the path */
    uint32_t replans;  /* since the goal was set */
    float gx, gy, gz;  /* goal */
} nxn_nav_agent_state;

typedef struct nxn_nav_event {
    uint32_t size;
    int32_t agent;
    uint32_t type;     /* NXN_NAV_EVENT_* */
} nxn_nav_event;

/* Starts baking the walkable grid of the world's bodies (a copy is taken now) on a worker thread and returns at once:
 * poll nxn_nav_state. NXN_ERR_INVALID: a bad number, empty bounds, or an area needing too many cell columns for the cell
 * (use a larger cell); NXN_ERR_LIMIT: the app already has 8 grids or the 64 MB of all grids are used. desc may be NULL.
 * Thread: any app thread. Memory: *out is a system-owned handle until nxn_nav_destroy or the app's end. */
NXN_API nxn_result nxn_nav_bake(nxn_phys_world* world, const nxn_nav_desc* desc, nxn_nav** out);
/* Frees the grid and its agents (a running bake is cancelled and waited for). NULL is ignored. Thread: any app thread, no
 * other call on it running. */
NXN_API void nxn_nav_destroy(nxn_nav* nav);
/* State, progress and the counts. */
NXN_API nxn_result nxn_nav_state(nxn_nav* nav, nxn_nav_info* out);
/* Stops a running bake (the state becomes NXN_NAV_CANCELLED). NXN_ERR_NOT_READY when no bake is running. */
NXN_API nxn_result nxn_nav_cancel(nxn_nav* nav);
/* A path from (sx, sy, sz) to (tx, ty, tz): NXN_OK and points[3 * i] = x, y, z of up to capacity points (the start first),
 * info->count their number; NXN_ERR_NOT_FOUND when there is none. flags: NXN_NAV_*; snap: how far the ends may be from the
 * walkable surface, 0 = 1.5. NXN_ERR_NOT_READY while the grid is not ready. */
NXN_API nxn_result nxn_nav_path(nxn_nav* nav, float sx, float sy, float sz, float tx, float ty, float tz, uint32_t flags,
                                float snap, float* points, uint32_t capacity, nxn_nav_path_info* info);
/* The walkable spot nearest to (x, y, z) within max_dist (0 = 1.5). Any out pointer may be NULL. NXN_ERR_NOT_FOUND. */
NXN_API nxn_result nxn_nav_snap(nxn_nav* nav, float x, float y, float z, float max_dist, float* out_x, float* out_y, float* out_z);
/* Closes the spots inside a cylinder (base x, y, z; height 0 = 2) until nxn_nav_unblock. NXN_ERR_INVALID: radius <= 0;
 * NXN_ERR_LIMIT: 4096 blockers and cost areas already. */
NXN_API nxn_result nxn_nav_block(nxn_nav* nav, float x, float y, float z, float radius, float height, int32_t* out_id);
/* Multiplies the cost of walking over the spots inside a cylinder (mult 1..32; height 0 = 2). */
NXN_API nxn_result nxn_nav_cost(nxn_nav* nav, float x, float y, float z, float radius, float height, float mult, int32_t* out_id);
/* Removes a blocker or a cost area. NXN_ERR_NOT_FOUND for an unknown id. */
NXN_API nxn_result nxn_nav_unblock(nxn_nav* nav, int32_t id);
/* An agent standing at (x, y, z) (more than 1.5 m from the walkable surface: NXN_ERR_INVALID); desc NULL = defaults. At most
 * 256 agents (NXN_ERR_LIMIT). */
NXN_API nxn_result nxn_nav_agent_add(nxn_nav* nav, float x, float y, float z, const nxn_nav_agent_desc* desc, int32_t* out_id);
/* Sends the agent to (x, y, z); NXN_ERR_NOT_FOUND when no path exists (its state becomes NXN_NAV_AGENT_FAILED). */
NXN_API nxn_result nxn_nav_agent_goto(nxn_nav* nav, int32_t agent, float x, float y, float z);
NXN_API nxn_result nxn_nav_agent_stop(nxn_nav* nav, int32_t agent);
NXN_API nxn_result nxn_nav_agent_remove(nxn_nav* nav, int32_t agent);
NXN_API nxn_result nxn_nav_agent_state_get(nxn_nav* nav, int32_t agent, nxn_nav_agent_state* out);
/* Moves every agent by dt seconds (0 = 1/60, at most 0.1). events: up to capacity records of events[0].size bytes (arrived,
 * failed, re-planned); the rest is dropped. */
NXN_API nxn_result nxn_nav_update(nxn_nav* nav, float dt, nxn_nav_event* events, uint32_t capacity, uint32_t* count);

NXN_EXTERN_C_END

#endif
