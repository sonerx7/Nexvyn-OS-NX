/* balls.c: bouncing balls (a second source file; every .c file of the bundle is compiled) */
#ifndef BALLS_H
#define BALLS_H
void balls_init(int n);
void balls_step(float dt);
void balls_draw(float w, float h);
void balls_push(float x, float y);
#endif
