/* Shared kinetic scrolling math. Header-only, C-compatible, no host imports. */
#ifndef NEXVYN_NXN_SCROLL_PHYSICS_H
#define NEXVYN_NXN_SCROLL_PHYSICS_H
#include <math.h>

#define NXN_SCROLL_REST 25.f
#define NXN_SCROLL_CATCH 90.f
#define NXN_SCROLL_MAX 8000.f

static inline float nxn_scroll_release(float velocity, double idle_seconds) {
    if (!isfinite(velocity) || idle_seconds > 0.08 || idle_seconds < 0) return 0;
    velocity = fmaxf(-NXN_SCROLL_MAX, fminf(NXN_SCROLL_MAX, velocity));
    return fabsf(velocity) < NXN_SCROLL_CATCH ? 0.f : velocity;
}

/* Integrate dv/dt = -6*v - 1000*sign(v) exactly. Motion is independent of
 * refresh rate, and a delayed frame never reverses the fling or overshoots its
 * stopping point. Position remains fractional until the caller rasterizes it. */
static inline int nxn_scroll_step(float* position, float* velocity, float dt) {
    if (!isfinite(*velocity) || !isfinite(*position)) { *velocity = 0; return 0; }
    if (!isfinite(dt) || dt <= 0) return *velocity != 0;
    float speed = fabsf(*velocity);
    if (speed < NXN_SCROLL_REST) { *velocity = 0; return 0; }
    const float friction_over_drag = 1000.f / 6.f;
    float stop = logf((speed + friction_over_drag) / (NXN_SCROLL_REST + friction_over_drag)) / 6.f;
    float t = fminf(dt, stop);
    float decay = expf(-6.f * t);
    float distance = (speed + friction_over_drag) * (1.f - decay) / 6.f - friction_over_drag * t;
    *position += copysignf(distance, *velocity);
    *velocity = dt >= stop ? 0.f : copysignf((speed + friction_over_drag) * decay - friction_over_drag, *velocity);
    return *velocity != 0;
}
#endif
