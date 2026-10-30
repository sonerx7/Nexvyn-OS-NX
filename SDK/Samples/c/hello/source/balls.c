#include <nexvyn.h>
#include <stdlib.h>
#include <math.h>
#include "balls.h"

typedef struct {
    float x, y, vx, vy, r;
    const char* color;
} Ball;

static Ball* balls;  /* malloc'd: counted against the app's memory and freed when the window closes */
static int count;
static float width = 640, height = 520;

void balls_init(int n) {
    static const char* colors[] = {"red", "orange", "yellow", "green", "blue", "purple", "pink", "accent"};
    free(balls);
    balls = (Ball*)calloc((size_t)n, sizeof(Ball));
    count = balls ? n : 0;
    for (int i = 0; i < count; i++) {
        balls[i].r = 14 + rand() % 18;
        balls[i].x = 60 + rand() % 400;
        balls[i].y = 80 + rand() % 300;
        balls[i].vx = (float)(rand() % 400 - 200);
        balls[i].vy = (float)(rand() % 400 - 200);
        balls[i].color = colors[i % 8];
    }
}

void balls_step(float dt) {
    for (int i = 0; i < count; i++) {
        Ball* b = &balls[i];
        b->vy += 600 * dt;  /* gravity */
        b->x += b->vx * dt;
        b->y += b->vy * dt;
        if (b->x < b->r) { b->x = b->r; b->vx = fabsf(b->vx); }
        if (b->x > width - b->r) { b->x = width - b->r; b->vx = -fabsf(b->vx); }
        if (b->y < 56 + b->r) { b->y = 56 + b->r; b->vy = fabsf(b->vy); }
        if (b->y > height - b->r) { b->y = height - b->r; b->vy = -fabsf(b->vy) * 0.92f; }
    }
}

void balls_push(float x, float y) {
    for (int i = 0; i < count; i++) {
        float dx = balls[i].x - x, dy = balls[i].y - y, d = sqrtf(dx * dx + dy * dy) + 1;
        balls[i].vx += dx / d * 500;
        balls[i].vy += dy / d * 500 - 200;
    }
    sys_vibrate(0.3f, 40);
}

void balls_draw(float w, float h) {
    width = w;
    height = h;
    for (int i = 0; i < count; i++) {
        Ball* b = &balls[i];
        gfx_shadow(b->x - b->r, b->y - b->r, b->r * 2, b->r * 2, b->r, 10, 4);
        gfx_circle(b->x, b->y, b->r, theme_color(b->color));
    }
    gfx_color(theme_color("text3"));
    gfx_text(TR("balls_hint"), 0, h - 28, 13, NULL, "center", w);
}
