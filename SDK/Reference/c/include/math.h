/* Nexvyn OS C apps: <math.h> */
#ifndef _MATH_H
#define _MATH_H
extern const float __nxv_inf, __nxv_nan;
#define INFINITY __nxv_inf
#define NAN __nxv_nan
#define HUGE_VAL ((double)__nxv_inf)
#define M_PI 3.14159265358979323846
#define M_PI_2 1.57079632679489661923
#define M_E 2.7182818284590452354
#define M_SQRT2 1.41421356237309504880
#define isnan(x) ((x) != (x))
#define isinf(x) (!isnan(x) && isnan((x) - (x)))
#define isfinite(x) (!isnan((x) - (x)))
double sin(double x);
double cos(double x);
double tan(double x);
double asin(double x);
double acos(double x);
double atan(double x);
double atan2(double y, double x);
double sinh(double x);
double cosh(double x);
double tanh(double x);
double exp(double x);
double log(double x);
double log10(double x);
double log2(double x);
double pow(double x, double y);
double sqrt(double x);
double cbrt(double x);
double floor(double x);
double ceil(double x);
double round(double x);
double trunc(double x);
double fmod(double x, double y);
double fabs(double x);
double hypot(double x, double y);
double fmin(double a, double b);
double fmax(double a, double b);
float sinf(float x);
float cosf(float x);
float tanf(float x);
float asinf(float x);
float acosf(float x);
float atanf(float x);
float atan2f(float y, float x);
float expf(float x);
float logf(float x);
float powf(float x, float y);
float sqrtf(float x);
float floorf(float x);
float ceilf(float x);
float roundf(float x);
float truncf(float x);
float fmodf(float x, float y);
float fabsf(float x);
float hypotf(float x, float y);
float fminf(float a, float b);
float fmaxf(float a, float b);
#endif
