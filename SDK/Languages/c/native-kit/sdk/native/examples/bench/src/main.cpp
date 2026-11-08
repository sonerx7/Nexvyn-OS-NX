/* Nexvyn Bench: a repeatable stress benchmark for the Native SDK (see README.md).
 *
 * Eight stages, each with a fixed camera path and a fixed duration (kStages: every count lives in that one table):
 *   1 City x1                          NexGFX, the baseline
 *   2 City x5 naive                    NexGFX, five ngfx_render calls per frame (one full draw of the city each)
 *   3 City x5 fastest SDK flags        NexGFX, same five calls with shadows and FXAA off (NexGFX has no instancing or batching)
 *   4 Dynamic lights                   own GL: 128 moving point lights over a field of boxes (forward shading, one pass)
 *   5 Particles and fill rate          own GL: 1500 large transparent sprites (heavy overdraw)
 *   6 CPU                              own GL: 20000 moving objects, per-frame transform + frustum culling + instanced draw
 *   7 Lights, tiled forward            stage 4 with a depth prepass and per-tile light bits (not in the score)
 *   8 Particles, half-res buffer       stage 5 into a half-resolution buffer (not in the score)
 * Swap interval 0 (NXN_DISPLAY_NO_VSYNC): no frame cap. Per stage: avg fps, 1% low fps, avg / max frame ms, CPU ms (frame start to
 * swap), GPU ms (GL timer query when the driver has it), draws, triangles, memory. Score = sum of the fps of stages 1-6.
 *
 * Start: <data>/autorun exists or the launch argument is "autorun" -> runs by itself, writes the results, shows the score for a
 * few seconds and returns code 7. The text of the autorun file may hold "secs=N" (stage length, default 8) and "stages=NNN"
 * (digits of the stages to run, default 12345678; the score sums stages 1-6). Without it the app waits for A / a touch.
 * Output (app data folder): bench_results.json and bench_report.txt (rewritten after every stage). */
#include <glad/glad.h>
#include <malloc.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <algorithm>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nexgfx_native.h>
#include "nexgfx_math.h"

/* ------------------------------------------------------------------ the stage table (tune here) */
enum Kind { K_CITY, K_LIGHTS, K_PARTICLES, K_CPU, K_LIGHTS_TILED, K_PARTICLES_HALF };
struct Stage {
    const char* id; const char* name; Kind kind;
    int copies;        /* K_CITY: ngfx_render calls per frame */
    bool shadows, fxaa;/* K_CITY */
    int lights;        /* K_LIGHTS: point lights (max 64) */
    int grid;          /* K_LIGHTS: boxes = grid x grid */
    int sprites;       /* K_PARTICLES: transparent quads */
    float spriteSize;  /* K_PARTICLES: half size in NDC height units (1 = the screen height) */
    int objects;       /* K_CPU: moving objects */
};
static const Stage kStages[] = {
    {"city_x1",    "City x1 (baseline)",              K_CITY,      1, true,  true,  0,  0,   0,   0,    0},
    {"city_x5",    "City x5 naive (5 draws of it)",   K_CITY,      5, true,  true,  0,  0,   0,   0,    0},
    {"city_x5_fast","City x5 fastest SDK flags",      K_CITY,      5, false, false, 0,  0,   0,   0,    0},
    {"lights",     "128 dynamic point lights",        K_LIGHTS,    0, false, false, 128, 50,  0,   0,    0},
    {"particles",  "Particles and fill rate",         K_PARTICLES, 0, false, false, 0,  0,   1500, 0.5f, 0},
    {"cpu",        "CPU: 20000 moving objects",       K_CPU,       0, false, false, 0,  0,   0,   0,    20000},
    /* the same scenes as stages 4 and 5 drawn the cheaper way (not part of the score, which stays the sum of stages 1-6):
     * 7 depth prepass + per-tile light lists (compute shader, 16x16 tiles with their depth range) + one shading pass that
     * walks only the lights reaching its tile; 8 the sprites into a half-resolution RGBA16F buffer, added to the frame
     * with one full-screen pass */
    {"lights_tiled",   "128 lights, tiled forward",   K_LIGHTS_TILED,   0, false, false, 128, 50, 0,  0,    0},
    {"particles_half", "Particles, half-res buffer",  K_PARTICLES_HALF, 0, false, false, 0,  0,   1500, 0.5f, 0},
};
static const int kNumStages = (int)(sizeof kStages / sizeof kStages[0]);
static const int kScoreStages = 6; /* the score sums stages 1-6 (comparable with the first reports) */
static const float kWarmup = 0.5f;  /* seconds at the start of a stage that are not measured (first use of shaders and buffers) */

/* ------------------------------------------------------------------ globals */
static nxn_display* g_disp;
static uint32_t g_w = 1280, g_h = 720;
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static ngfx_device* g_dev;
static ngfx_frame_stats g_st = {sizeof(ngfx_frame_stats)};
static bool g_ready;
static uint32_t g_prepDone, g_prepTotal = 5;
static std::string g_report;

static void logf_(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void logf_(const char* fmt, ...) {
    char b[512]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap);
    nxn_log(NXN_LOG_INFO, "%s", b);
    g_report += b; g_report += "\n";
}
static size_t heap_bytes() { struct mallinfo mi = mallinfo(); return (size_t)mi.uordblks + (size_t)mi.hblkhd; }
static uint64_t gpu_bytes() { ngfx_device_caps c = {sizeof c}; ngfx_device_caps_get(g_dev, &c); return c.gpu_bytes; }

/* ------------------------------------------------------------------ the city (the Scenes demo's loader, one scene) */
struct City { ngfx_scene h = 0; ngfx_scene_status st; ngfx_scene_info info; bool geom = false, done = false, failed = false; uint64_t tStart = 0, tDone = 0; } C;
static void city_load() {
    C.st.size = sizeof C.st; C.info.size = sizeof C.info; C.tStart = nxn_time_ns();
    char sc[512], tx[512];
    nxn_fs_path(NXN_DIR_BUNDLE, "data/level1.nxsc", sc, sizeof sc); nxn_fs_path(NXN_DIR_BUNDLE, "data/level1.nxtx", tx, sizeof tx);
    ngfx_scene_desc d = {sizeof d, sc, tx, 0, 0};
    if (ngfx_scene_load(g_dev, &d, &C.h) != NGFX_OK) { C.failed = true; snprintf(C.st.error, sizeof C.st.error, "%s", ngfx_native_error()); }
}
static void city_step() {
    if (!C.h || C.done || C.failed) return;
    ngfx_scene_step(g_dev, C.h, 24000000ull, &C.st);
    if (C.st.failed) { C.failed = true; return; }
    if (C.st.geometry_ready && !C.geom) { C.geom = true; ngfx_scene_info_get(g_dev, C.h, &C.info); }
    if (C.st.ready && !C.done) { C.done = true; C.tDone = nxn_time_ns(); }
}

/* fixed camera path through the city: Catmull-Rom through waypoints on large flat chunks (floors, ground), as the Scenes tour;
 * the position depends only on the stage time, never on the frame time */
struct Cam { V3 pos{0, 2, 0}; float yaw = 0, pitch = 0, fov = 65.f; } g_cam;
static std::vector<V3> g_wp;
static V3 wp_eval(float s) {
    int n = (int)g_wp.size(); if (n < 2) return g_wp.empty() ? V3{0, 0, 0} : g_wp[0];
    s = std::max(0.f, std::min(s, (float)(n - 1) - 0.001f)); int i = (int)s; float u = s - (float)i;
    V3 p0 = g_wp[i > 0 ? i - 1 : 0], p1 = g_wp[i], p2 = g_wp[i + 1], p3 = g_wp[i + 2 < n ? i + 2 : n - 1];
    float u2 = u * u, u3 = u2 * u;
    return (p1 * 2.f + (p2 - p0) * u + (p0 * 2.f - p1 * 5.f + p2 * 4.f - p3) * u2 + (p1 * 3.f - p0 - p2 * 3.f + p3) * u3) * 0.5f;
}
static void city_path_build() {
    const ngfx_scene_info& h = C.info;
    if (h.has_camera) { g_cam.pos = {h.camera[0], h.camera[1], h.camera[2]}; g_cam.yaw = h.camera[3]; g_cam.pitch = h.camera[4]; if (h.fov_deg > 5) g_cam.fov = h.fov_deg; }
    else { g_cam.pos = {(h.bmin[0] + h.bmax[0]) * 0.5f, (h.bmin[1] < 0.f && h.bmax[1] > 0.f ? 0.f : h.bmin[1]) + 1.7f, (h.bmin[2] + h.bmax[2]) * 0.5f}; }
    float floorY = g_cam.pos.y - 1.7f;
    std::vector<V3> cand;
    for (uint32_t ci = 0; ci < C.info.chunks; ci++) {
        float bmin[3], bmax[3];
        if (ngfx_scene_chunk_bounds(g_dev, C.h, ci, bmin, bmax) != NGFX_OK) continue;
        float dx = bmax[0] - bmin[0], dz = bmax[2] - bmin[2];
        if (bmax[1] - bmin[1] < 0.8f && dx * dz > 30.f && fabsf(bmax[1] - floorY) < 3.f) cand.push_back({(bmin[0] + bmax[0]) * 0.5f, bmax[1] + 1.7f, (bmin[2] + bmax[2]) * 0.5f});
    }
    g_wp.clear(); g_wp.push_back(g_cam.pos);
    std::vector<float> dmin(cand.size(), 1e30f);
    for (int k = 0; k < 10 && !cand.empty(); k++) {
        int best = -1; float bd = -1;
        for (size_t i = 0; i < cand.size(); i++) { V3 d = cand[i] - g_wp.back(); dmin[i] = std::min(dmin[i], d.x * d.x + d.z * d.z); if (dmin[i] > bd) { bd = dmin[i]; best = (int)i; } }
        if (best < 0 || bd < 25.f) break;
        g_wp.push_back(cand[best]); dmin[best] = -1;
    }
    if (g_wp.size() < 3) { g_wp.clear(); V3 p = g_cam.pos; for (int k = 0; k < 9; k++) { float a = (float)k * 0.785398f; g_wp.push_back({p.x + cosf(a) * 8.f - 8.f, p.y, p.z + sinf(a) * 8.f}); } }
    logf_("city path: %d waypoints, scene %u chunks, %u triangles", (int)g_wp.size(), C.info.chunks, C.info.triangles);
}
static void city_cam_at(float u /* 0..1 of the stage */) {
    float len = std::min((float)(g_wp.size() - 1), 3.5f), s = u * len;
    g_cam.pos = wp_eval(s);
    V3 look = wp_eval(s + 0.35f) - g_cam.pos;
    if (look.x * look.x + look.z * look.z > 1e-4f) g_cam.yaw = atan2f(look.x, -look.z);
    g_cam.pitch = -0.05f;
}

/* ------------------------------------------------------------------ own GL (stages 4, 5, 6) */
static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type); glShaderSource(s, 1, &src, NULL); glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char b[512]; glGetShaderInfoLog(s, sizeof b, NULL, b); logf_("shader error: %.300s", b); }
    return s;
}
static GLuint program(const char* vs, const char* fs) {
    GLuint p = glCreateProgram(), a = compile(GL_VERTEX_SHADER, vs), b = compile(GL_FRAGMENT_SHADER, fs);
    glAttachShader(p, a); glAttachShader(p, b); glLinkProgram(p); glDeleteShader(a); glDeleteShader(b);
    GLint ok = 0; glGetProgramiv(p, GL_LINK_STATUS, &ok); if (!ok) { logf_("program link failed"); glDeleteProgram(p); return 0; }
    return p;
}
static const char* kLitVS = R"(#version 430 core
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aN;
layout(location=2) in vec4 iM0; layout(location=3) in vec4 iM1; layout(location=4) in vec4 iM2; layout(location=5) in vec4 iM3;
uniform mat4 uVP; out vec3 vW; out vec3 vN; flat out int vId;
void main(){ mat4 M = mat4(iM0,iM1,iM2,iM3); vec4 w = M*vec4(aPos,1.0); vW = w.xyz; vN = mat3(M)*aN; vId = gl_InstanceID; gl_Position = uVP*w; })";
static const char* kLitFS = R"(#version 430 core
in vec3 vW; in vec3 vN; flat in int vId;
uniform vec3 uEye; uniform int uNL; uniform vec4 uLP[128]; uniform vec4 uLC[128]; uniform vec3 uBase; uniform int uTint;
out vec4 o;
void main(){
  vec3 N = normalize(vN), V = normalize(uEye - vW);
  float h = fract(sin(float(vId)*12.9898)*43758.5453);
  vec3 alb = uTint == 1 ? vec3(.35+.5*h, .4+.4*fract(h*7.), .5+.4*fract(h*13.)) : uBase;
  vec3 c = alb*0.06;
  for (int i = 0; i < uNL; i++) {
    vec3 d = uLP[i].xyz - vW; float r = uLP[i].w, dist = length(d);
    if (dist < r) { vec3 L = d/dist; float a = 1.0 - dist/r; a *= a; float nl = max(dot(N,L),0.0); vec3 H = normalize(L+V);
      c += (alb*nl + pow(max(dot(N,H),0.0),32.0)*0.5)*uLC[i].rgb*a; }
  }
  c = c/(1.0+c); o = vec4(pow(c, vec3(1.0/2.2)), 1.0); })";
static const char* kPartVS = R"(#version 430 core
uniform float uT; uniform float uSize; uniform float uAsp; out vec2 vUV; out vec3 vCol;
float hs(int n){ return fract(sin(float(n)*12.9898)*43758.5453); }
void main(){
  int id = gl_InstanceID; float a = hs(id), b = hs(id+7919), c = hs(id+104729);
  vec2 corner = vec2(float(gl_VertexID & 1), float(gl_VertexID >> 1))*2.0 - 1.0;
  vec2 ctr = vec2(sin(uT*(0.3+a)+b*6.28), cos(uT*(0.25+b)+c*6.28))*0.8;
  float s = uSize*(0.5+c);
  gl_Position = vec4(ctr + corner*s*vec2(uAsp,1.0), 0.0, 1.0); vUV = corner; vCol = vec3(.4+.6*a, .3+.7*b, .5+.5*c); })";
static const char* kPartFS = R"(#version 430 core
in vec2 vUV; in vec3 vCol; out vec4 o;
void main(){ float d = dot(vUV,vUV); if (d > 1.0) discard; o = vec4(vCol, exp(-d*3.0)*0.012); })";

/* stage 7: the stage 4 scene with per-tile light lists and a depth prepass, all in the window's framebuffer:
 *   1. depth prepass (color writes off), 2. the CPU marks, per 32x32-pixel tile, the lights whose sphere reaches the part
 *   of the tile's view frustum inside the scene's height range (the ground top to the tallest box: every surface of this
 *   scene is in it) and uploads the bits (one RGBA32UI texel per tile; tiles_cull), 3. one shading pass with GL_LEQUAL and no depth writes (each visible pixel is shaded once) that
 *   walks only its tile's lights. The light loop is the one of kLitFS, in index order, so a light the tile skips is
 *   exactly one kLitFS adds nothing for (dist >= r): the picture is the one of stage 4. Both passes use one instanced
 *   draw (ground = instance 0) with the same vertex shader. */
static const char* kTileVS = R"(#version 430 core
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aN;
layout(location=2) in vec4 iM0; layout(location=3) in vec4 iM1; layout(location=4) in vec4 iM2; layout(location=5) in vec4 iM3;
uniform mat4 uVP; out vec3 vW; out vec3 vN; flat out int vId;
void main(){ mat4 M = mat4(iM0,iM1,iM2,iM3); vec4 w = M*vec4(aPos,1.0); vW = w.xyz; vN = mat3(M)*aN; vId = gl_InstanceID - 1; gl_Position = uVP*w; })";
static const char* kDepthFS = R"(#version 430 core
void main(){})";
static const char* kTileFS = R"(#version 430 core
in vec3 vW; in vec3 vN; flat in int vId;
uniform vec3 uEye; uniform vec4 uLP[128]; uniform vec4 uLC[128]; uniform vec3 uBase;
layout(binding=1) uniform usampler2D tMask;
out vec4 o;
void main(){
  vec3 N = normalize(vN), V = normalize(uEye - vW);
  float h = fract(sin(float(vId)*12.9898)*43758.5453);
  vec3 alb = vId >= 0 ? vec3(.35+.5*h, .4+.4*fract(h*7.), .5+.4*fract(h*13.)) : uBase;
  vec3 c = alb*0.06;
  uvec4 m = texelFetch(tMask, ivec2(gl_FragCoord.xy) >> 5, 0);
  for (int w = 0; w < 4; w++) {
    uint bits = m[w];
    while (bits != 0u) {
      int i = w*32 + findLSB(bits); bits &= bits - 1u;
      vec3 d = uLP[i].xyz - vW; float r = uLP[i].w, dist = length(d);
      if (dist < r) { vec3 L = d/dist; float a = 1.0 - dist/r; a *= a; float nl = max(dot(N,L),0.0); vec3 H = normalize(L+V);
        c += (alb*nl + pow(max(dot(N,H),0.0),32.0)*0.5)*uLC[i].rgb*a; }
    }
  }
  c = c/(1.0+c); o = vec4(pow(c, vec3(1.0/2.2)), 1.0); })";
/* stage 8: the half-resolution particle buffer added to the frame (bilinear) */
static const char* kAddVS = R"(#version 430 core
out vec2 vUV; void main(){ vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2); vUV = p; gl_Position = vec4(p*2.0-1.0, 0.0, 1.0); })";
static const char* kAddFS = R"(#version 430 core
in vec2 vUV; layout(binding=0) uniform sampler2D tSrc; out vec4 o; void main(){ o = vec4(texture(tSrc, vUV).rgb, 1.0); })";

struct Gl {
    GLuint lit = 0, part = 0, cubeVao = 0, cubeVbo = 0, cubeIbo = 0, instVbo = 0, partVao = 0;
    GLint uVP = -1, uEye = -1, uNL = -1, uLP = -1, uLC = -1, uBase = -1, uTint = -1, pT = -1, pSize = -1, pAsp = -1;
    size_t instCap = 0; bool ok = false;
    /* stages 7 and 8 (built on first use; false = that stage fails with a note, the others run) */
    bool tiledTried = false, tiledOk = false, halfTried = false, halfOk = false;
    GLuint tDepthP = 0, tShade = 0, tMask = 0, hFbo = 0, hTex = 0, add = 0;
    GLint dVP = -1, sVP = -1, sEye = -1, sLP = -1, sLC = -1, sBase = -1;
    int tW = 0, tH = 0, hW = 0, hH = 0;
} G;
/* the tile mask texture of stage 7 (one RGBA32UI texel per 32x32 tile) */
static bool tiled_targets(int w, int h) {
    if (G.tMask && G.tW == w && G.tH == h) return true;
    if (G.tMask) glDeleteTextures(1, &G.tMask);
    glGenTextures(1, &G.tMask); glBindTexture(GL_TEXTURE_2D, G.tMask); glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA32UI, (w + 31) / 32, (h + 31) / 32);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    G.tW = w; G.tH = h;
    return true;
}
static bool tiled_init() {
    if (G.tiledTried) return G.tiledOk;
    G.tiledTried = true;
    G.tDepthP = program(kTileVS, kDepthFS); G.tShade = program(kTileVS, kTileFS);
    if (!G.tDepthP || !G.tShade) return false;
    G.dVP = glGetUniformLocation(G.tDepthP, "uVP");
    G.sVP = glGetUniformLocation(G.tShade, "uVP"); G.sEye = glGetUniformLocation(G.tShade, "uEye"); G.sLP = glGetUniformLocation(G.tShade, "uLP");
    G.sLC = glGetUniformLocation(G.tShade, "uLC"); G.sBase = glGetUniformLocation(G.tShade, "uBase");
    G.tiledOk = true;
    return true;
}
static bool half_init() {
    if (G.halfTried) return G.halfOk;
    G.halfTried = true;
    G.add = program(kAddVS, kAddFS);
    G.halfOk = G.add != 0;
    return G.halfOk;
}
static bool half_target(int w, int h) {
    if (G.hFbo && G.hW == w && G.hH == h) return true;
    if (G.hFbo) { glDeleteFramebuffers(1, &G.hFbo); glDeleteTextures(1, &G.hTex); G.hFbo = 0; }
    glGenTextures(1, &G.hTex); glBindTexture(GL_TEXTURE_2D, G.hTex); glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA16F, w, h);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glGenFramebuffers(1, &G.hFbo); glBindFramebuffer(GL_FRAMEBUFFER, G.hFbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, G.hTex, 0);
    bool ok = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    G.hW = w; G.hH = h;
    if (!ok) logf_("stage 8: render target incomplete");
    return ok;
}
static void gl_init() {
    G.lit = program(kLitVS, kLitFS); G.part = program(kPartVS, kPartFS);
    if (!G.lit || !G.part) return;
    G.uVP = glGetUniformLocation(G.lit, "uVP"); G.uEye = glGetUniformLocation(G.lit, "uEye"); G.uNL = glGetUniformLocation(G.lit, "uNL");
    G.uLP = glGetUniformLocation(G.lit, "uLP"); G.uLC = glGetUniformLocation(G.lit, "uLC"); G.uBase = glGetUniformLocation(G.lit, "uBase"); G.uTint = glGetUniformLocation(G.lit, "uTint");
    G.pT = glGetUniformLocation(G.part, "uT"); G.pSize = glGetUniformLocation(G.part, "uSize"); G.pAsp = glGetUniformLocation(G.part, "uAsp");
    /* unit cube, 24 vertices (position, normal) */
    std::vector<float> v; std::vector<uint16_t> ix;
    const float N[6][3] = {{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}};
    for (int f = 0; f < 6; f++) {
        V3 n = {N[f][0], N[f][1], N[f][2]}; V3 t = fabsf(n.y) > 0.5f ? V3{1, 0, 0} : V3{0, 1, 0}; V3 b = cross(n, t); t = cross(b, n);
        for (int k = 0; k < 4; k++) {
            float su = (k & 1) ? 1.f : -1.f, sv = (k & 2) ? 1.f : -1.f;
            V3 p = n * 0.5f + t * (su * 0.5f) + b * (sv * 0.5f);
            v.push_back(p.x); v.push_back(p.y); v.push_back(p.z); v.push_back(n.x); v.push_back(n.y); v.push_back(n.z);
        }
        uint16_t o = (uint16_t)(f * 4);
        const uint16_t q[6] = {0, 1, 2, 1, 3, 2};
        for (int k = 0; k < 6; k++) ix.push_back((uint16_t)(o + q[k]));
    }
    glGenVertexArrays(1, &G.cubeVao); glBindVertexArray(G.cubeVao);
    glGenBuffers(1, &G.cubeVbo); glBindBuffer(GL_ARRAY_BUFFER, G.cubeVbo); glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)(v.size() * 4), v.data(), GL_STATIC_DRAW);
    glEnableVertexAttribArray(0); glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 24, (void*)0);
    glEnableVertexAttribArray(1); glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 24, (void*)12);
    glGenBuffers(1, &G.cubeIbo); glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, G.cubeIbo); glBufferData(GL_ELEMENT_ARRAY_BUFFER, (GLsizeiptr)(ix.size() * 2), ix.data(), GL_STATIC_DRAW);
    glGenBuffers(1, &G.instVbo); glBindBuffer(GL_ARRAY_BUFFER, G.instVbo);
    for (int i = 0; i < 4; i++) { glEnableVertexAttribArray(2 + i); glVertexAttribPointer(2 + i, 4, GL_FLOAT, GL_FALSE, 64, (void*)(size_t)(16 * i)); glVertexAttribDivisor(2 + i, 1); }
    glGenVertexArrays(1, &G.partVao);
    glBindVertexArray(0);
    G.ok = true;
}
static void inst_upload(const float* m, size_t count) {  /* count x mat4, orphaned each call */
    glBindBuffer(GL_ARRAY_BUFFER, G.instVbo);
    size_t bytes = count * 64;
    if (bytes > G.instCap) G.instCap = bytes;
    glBufferData(GL_ARRAY_BUFFER, (GLsizeiptr)G.instCap, NULL, GL_STREAM_DRAW);
    if (bytes) glBufferSubData(GL_ARRAY_BUFFER, 0, (GLsizeiptr)bytes, m);
}
static void mat_trs(float* m, V3 p, float sx, float sy, float sz, float ry, float rx) {  /* column major: T * Ry * Rx * S */
    float cy = cosf(ry), sy_ = sinf(ry), cx = cosf(rx), sx_ = sinf(rx);
    /* Ry*Rx columns */
    float c0[3] = {cy, 0, -sy_}, c1[3] = {sy_ * sx_, cx, cy * sx_}, c2[3] = {sy_ * cx, -sx_, cy * cx};
    for (int i = 0; i < 3; i++) { m[i] = c0[i] * sx; m[4 + i] = c1[i] * sy; m[8 + i] = c2[i] * sz; }
    m[3] = m[7] = m[11] = 0; m[12] = p.x; m[13] = p.y; m[14] = p.z; m[15] = 1;
}

/* ------------------------------------------------------------------ stage 4: lights, 6: CPU objects */
struct Box { float x, z, s, h; };
static std::vector<Box> g_boxes;
static std::vector<float> g_mats;
struct Obj { float cx, cy, cz, r, sp, ph, spin, sc; };
static std::vector<Obj> g_objs;
static uint32_t g_rng;
static float rnd() { g_rng = g_rng * 1664525u + 1013904223u; return (float)(g_rng >> 8) / 16777216.f; }

static void stage_prepare(const Stage& s) {
    g_rng = 12345u;  /* every run builds the same world */
    if (s.kind == K_LIGHTS || s.kind == K_LIGHTS_TILED) {
        g_boxes.clear(); g_mats.clear();
        for (int i = 0; i < s.grid; i++) for (int j = 0; j < s.grid; j++) { Box b = {(i - s.grid * 0.5f) * 4.f, (j - s.grid * 0.5f) * 4.f, 1.2f + 1.6f * rnd(), 1.f + 5.f * rnd()}; g_boxes.push_back(b); }
        g_mats.resize((g_boxes.size() + 1) * 16);
        mat_trs(&g_mats[0], {0, -0.25f, 0}, 400.f, 0.5f, 400.f, 0, 0);  /* ground = instance 0 */
        for (size_t k = 0; k < g_boxes.size(); k++) mat_trs(&g_mats[(k + 1) * 16], {g_boxes[k].x, g_boxes[k].h * 0.5f, g_boxes[k].z}, g_boxes[k].s, g_boxes[k].h, g_boxes[k].s, rnd() * 3.f, 0);
    } else if (s.kind == K_CPU) {
        g_objs.resize((size_t)s.objects); g_mats.resize((size_t)s.objects * 16);
        for (auto& o : g_objs) {
            float a = rnd() * 6.2832f, b = acosf(1.f - 2.f * rnd()), rr = 40.f + 80.f * cbrtf(rnd());
            o.cx = rr * sinf(b) * cosf(a); o.cy = rr * cosf(b) * 0.6f; o.cz = rr * sinf(b) * sinf(a);
            o.r = 1.f + 5.f * rnd(); o.sp = 0.3f + rnd(); o.ph = rnd() * 6.2832f; o.spin = 0.5f + 2.f * rnd(); o.sc = 0.5f + 1.2f * rnd();
        }
    }
}
static int g_visibleObjs;  /* the CPU stage: how many passed the cull */

/* general 4x4 inverse (cofactors), column-major like M4; the identity for a singular matrix */
static M4 m4_inverse(const M4& M) {
    const float* m = M.m; float o[16];
    o[0] = m[5]*m[10]*m[15] - m[5]*m[11]*m[14] - m[9]*m[6]*m[15] + m[9]*m[7]*m[14] + m[13]*m[6]*m[11] - m[13]*m[7]*m[10];
    o[4] = -m[4]*m[10]*m[15] + m[4]*m[11]*m[14] + m[8]*m[6]*m[15] - m[8]*m[7]*m[14] - m[12]*m[6]*m[11] + m[12]*m[7]*m[10];
    o[8] = m[4]*m[9]*m[15] - m[4]*m[11]*m[13] - m[8]*m[5]*m[15] + m[8]*m[7]*m[13] + m[12]*m[5]*m[11] - m[12]*m[7]*m[9];
    o[12] = -m[4]*m[9]*m[14] + m[4]*m[10]*m[13] + m[8]*m[5]*m[14] - m[8]*m[6]*m[13] - m[12]*m[5]*m[10] + m[12]*m[6]*m[9];
    o[1] = -m[1]*m[10]*m[15] + m[1]*m[11]*m[14] + m[9]*m[2]*m[15] - m[9]*m[3]*m[14] - m[13]*m[2]*m[11] + m[13]*m[3]*m[10];
    o[5] = m[0]*m[10]*m[15] - m[0]*m[11]*m[14] - m[8]*m[2]*m[15] + m[8]*m[3]*m[14] + m[12]*m[2]*m[11] - m[12]*m[3]*m[10];
    o[9] = -m[0]*m[9]*m[15] + m[0]*m[11]*m[13] + m[8]*m[1]*m[15] - m[8]*m[3]*m[13] - m[12]*m[1]*m[11] + m[12]*m[3]*m[9];
    o[13] = m[0]*m[9]*m[14] - m[0]*m[10]*m[13] - m[8]*m[1]*m[14] + m[8]*m[2]*m[13] + m[12]*m[1]*m[10] - m[12]*m[2]*m[9];
    o[2] = m[1]*m[6]*m[15] - m[1]*m[7]*m[14] - m[5]*m[2]*m[15] + m[5]*m[3]*m[14] + m[13]*m[2]*m[7] - m[13]*m[3]*m[6];
    o[6] = -m[0]*m[6]*m[15] + m[0]*m[7]*m[14] + m[4]*m[2]*m[15] - m[4]*m[3]*m[14] - m[12]*m[2]*m[7] + m[12]*m[3]*m[6];
    o[10] = m[0]*m[5]*m[15] - m[0]*m[7]*m[13] - m[4]*m[1]*m[15] + m[4]*m[3]*m[13] + m[12]*m[1]*m[7] - m[12]*m[3]*m[5];
    o[14] = -m[0]*m[5]*m[14] + m[0]*m[6]*m[13] + m[4]*m[1]*m[14] - m[4]*m[2]*m[13] - m[12]*m[1]*m[6] + m[12]*m[2]*m[5];
    o[3] = -m[1]*m[6]*m[11] + m[1]*m[7]*m[10] + m[5]*m[2]*m[11] - m[5]*m[3]*m[10] - m[9]*m[2]*m[7] + m[9]*m[3]*m[6];
    o[7] = m[0]*m[6]*m[11] - m[0]*m[7]*m[10] - m[4]*m[2]*m[11] + m[4]*m[3]*m[10] + m[8]*m[2]*m[7] - m[8]*m[3]*m[6];
    o[11] = -m[0]*m[5]*m[11] + m[0]*m[7]*m[9] + m[4]*m[1]*m[11] - m[4]*m[3]*m[9] - m[8]*m[1]*m[7] + m[8]*m[3]*m[5];
    o[15] = m[0]*m[5]*m[10] - m[0]*m[6]*m[9] - m[4]*m[1]*m[10] + m[4]*m[2]*m[9] + m[8]*m[1]*m[6] - m[8]*m[2]*m[5];
    float det = m[0]*o[0] + m[1]*o[4] + m[2]*o[8] + m[3]*o[12];
    M4 r = m4_identity();
    if (fabsf(det) < 1e-20f) return r;
    for (int i = 0; i < 16; i++) r.m[i] = o[i] / det;
    return r;
}

/* stage 7's light bits: per 32x32 tile, the tile's frustum (4 corner rays, near and far edges) clipped to the height range
 * y0..y1 gives a world-space box; a light whose sphere (radius + 1 %: conservative) reaches the box gets its bit */
static std::vector<uint32_t> g_tileBits;
static void tiles_cull(const M4& inv, int tx, int ty, float y0, float y1, const float* lw, int nl) {
    g_tileBits.assign((size_t)tx * ty * 4, 0u);
    long covered = 0, marked = 0;
    auto unproj = [&](float x, float y, float z) {
        const float* m = inv.m;
        float X = m[0] * x + m[4] * y + m[8] * z + m[12], Y = m[1] * x + m[5] * y + m[9] * z + m[13];
        float Z = m[2] * x + m[6] * y + m[10] * z + m[14], W = m[3] * x + m[7] * y + m[11] * z + m[15];
        return V3{X / W, Y / W, Z / W};
    };
    for (int j = 0; j < ty; j++)
        for (int i = 0; i < tx; i++) {
            float ax = (float)(i * 32) / (float)g_w * 2.f - 1.f, ay = (float)(j * 32) / (float)g_h * 2.f - 1.f;
            float bx = std::min(1.f, (float)((i + 1) * 32) / (float)g_w) * 2.f - 1.f, by = std::min(1.f, (float)((j + 1) * 32) / (float)g_h) * 2.f - 1.f;
            const float cx[4] = {ax, bx, bx, ax}, cy[4] = {ay, ay, by, by};
            V3 n[4], f[4];
            for (int k = 0; k < 4; k++) { n[k] = unproj(cx[k], cy[k], -1.f); f[k] = unproj(cx[k], cy[k], 1.f); }
            V3 lo{1e30f, 1e30f, 1e30f}, hi{-1e30f, -1e30f, -1e30f};
            auto seg = [&](V3 a, V3 b) {
                float t0 = 0.f, t1 = 1.f, dy = b.y - a.y;
                if (fabsf(dy) < 1e-6f) { if (a.y < y0 || a.y > y1) return; }
                else { float ta = (y0 - a.y) / dy, tb = (y1 - a.y) / dy; t0 = std::max(t0, std::min(ta, tb)); t1 = std::min(t1, std::max(ta, tb)); if (t0 > t1) return; }
                V3 p = a + (b - a) * t0, q = a + (b - a) * t1;
                lo = {std::min(lo.x, std::min(p.x, q.x)), std::min(lo.y, std::min(p.y, q.y)), std::min(lo.z, std::min(p.z, q.z))};
                hi = {std::max(hi.x, std::max(p.x, q.x)), std::max(hi.y, std::max(p.y, q.y)), std::max(hi.z, std::max(p.z, q.z))};
            };
            for (int k = 0; k < 4; k++) { seg(n[k], f[k]); seg(n[k], n[(k + 1) & 3]); seg(f[k], f[(k + 1) & 3]); }
            if (lo.x > hi.x) continue;
            covered++;
            uint32_t* bits = &g_tileBits[((size_t)j * tx + i) * 4];
            for (int l = 0; l < nl; l++) {
                const float* L = &lw[l * 4];
                float dx = std::max(lo.x - L[0], std::max(0.f, L[0] - hi.x)), dy = std::max(lo.y - L[1], std::max(0.f, L[1] - hi.y));
                float dz = std::max(lo.z - L[2], std::max(0.f, L[2] - hi.z)), r = L[3] * 1.01f;
                if (dx * dx + dy * dy + dz * dz < r * r) { bits[l >> 5] |= 1u << (l & 31); marked++; }
            }
        }
    g_visibleObjs = covered ? (int)((marked + covered / 2) / covered) : 0; /* the "visible" column: lights per tile */
}

/* draws one frame of an own-GL stage; returns the number of draw calls, adds triangles */
static int draw_own(const Stage& s, float t, long& tris) {
    glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
    float asp = (float)g_w / (float)g_h;
    int draws = 0;
    if (s.kind == K_PARTICLES || s.kind == K_PARTICLES_HALF) {
        const bool half = s.kind == K_PARTICLES_HALF;
        int hw = std::max(1, (int)g_w / 2), hh = std::max(1, (int)g_h / 2);
        if (half && (!half_init() || !half_target(hw, hh))) return -1;
        glDisable(GL_DEPTH_TEST);
        if (half) { glBindFramebuffer(GL_FRAMEBUFFER, G.hFbo); glViewport(0, 0, hw, hh); glClearColor(0, 0, 0, 0); glClear(GL_COLOR_BUFFER_BIT); }
        else { glClearColor(0.02f + 0.02f * sinf(t), 0.03f, 0.06f, 1.f); glClear(GL_COLOR_BUFFER_BIT); }
        glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA, GL_ONE);
        glUseProgram(G.part); glUniform1f(G.pT, t); glUniform1f(G.pSize, s.spriteSize); glUniform1f(G.pAsp, 1.f / asp);
        glBindVertexArray(G.partVao); glDrawArraysInstanced(GL_TRIANGLE_STRIP, 0, 4, s.sprites); draws = 1; tris += 2L * s.sprites;
        if (half) {  /* background, then the buffer added on top (bilinear upscale): one more full-screen pass */
            glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
            glClearColor(0.02f + 0.02f * sinf(t), 0.03f, 0.06f, 1.f); glClear(GL_COLOR_BUFFER_BIT);
            glBlendFunc(GL_ONE, GL_ONE); glUseProgram(G.add); glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, G.hTex);
            glDrawArrays(GL_TRIANGLES, 0, 3); draws++;
        }
        glDisable(GL_BLEND);
        return draws;
    }
    const bool tiled = s.kind == K_LIGHTS_TILED;
    if (tiled && (!tiled_init() || !tiled_targets((int)g_w, (int)g_h))) return -1;
    glEnable(GL_DEPTH_TEST); glDepthMask(GL_TRUE); glDisable(GL_BLEND); glEnable(GL_CULL_FACE);
    glClearColor(0.03f, 0.04f, 0.07f, 1.f); glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    V3 eye, tgt = {0, 2, 0};
    float lp[128 * 4], lc[128 * 4]; int nl = 0;
    if (s.kind == K_LIGHTS || tiled) {
        float a = t * 0.25f; eye = {cosf(a) * 38.f, 16.f, sinf(a) * 38.f};
        nl = std::min(s.lights, 128);
        for (int i = 0; i < nl; i++) {
            float ph = (float)i * 0.61803f * 6.2832f, rad = 6.f + 36.f * fmodf((float)i * 0.37f, 1.f), ang = t * (0.35f + 0.05f * (float)(i % 7)) + ph;
            lp[i * 4] = cosf(ang) * rad; lp[i * 4 + 1] = 1.5f + 3.f * (0.5f + 0.5f * sinf(t * 0.7f + ph)); lp[i * 4 + 2] = sinf(ang) * rad; lp[i * 4 + 3] = 30.f;
            lc[i * 4] = 0.5f + 0.5f * sinf(ph); lc[i * 4 + 1] = 0.5f + 0.5f * sinf(ph + 2.1f); lc[i * 4 + 2] = 0.5f + 0.5f * sinf(ph + 4.2f); lc[i * 4 + 3] = 1.5f;
        }
        inst_upload(g_mats.data(), g_boxes.size() + 1);
    } else {  /* K_CPU */
        float a = t * 0.3f; eye = {cosf(a) * 175.f, 40.f, sinf(a) * 175.f}; tgt = {0, 0, 0};
        M4 vpC = m4_mul(m4_perspective(65.f * 3.14159265f / 180.f, asp, 0.5f, 600.f), m4_lookat(eye, tgt - eye, V3{0, 1, 0}));
        Frustum fr; fr.set(vpC);
        float inv[6]; for (int i = 0; i < 6; i++) inv[i] = 1.f / sqrtf(fr.p[i][0] * fr.p[i][0] + fr.p[i][1] * fr.p[i][1] + fr.p[i][2] * fr.p[i][2]);
        size_t vis = 0;
        for (const Obj& o : g_objs) {  /* transform + sphere cull, the per-frame CPU work of a typical game */
            float ph = t * o.sp + o.ph;
            V3 p = {o.cx + cosf(ph) * o.r, o.cy + sinf(ph * 1.3f) * o.r * 0.5f, o.cz + sinf(ph) * o.r};
            float rad = o.sc * 0.87f; bool in = true;
            for (int i = 0; i < 6 && in; i++) if ((fr.p[i][0] * p.x + fr.p[i][1] * p.y + fr.p[i][2] * p.z + fr.p[i][3]) * inv[i] < -rad) in = false;
            if (!in) continue;
            mat_trs(&g_mats[vis * 16], p, o.sc, o.sc, o.sc, t * o.spin, ph); vis++;
        }
        g_visibleObjs = (int)vis;
        inst_upload(g_mats.data(), vis);
        nl = 1; lp[0] = eye.x * 0.5f; lp[1] = 60.f; lp[2] = eye.z * 0.5f; lp[3] = 400.f; lc[0] = lc[1] = lc[2] = 1.4f; lc[3] = 1.f;
    }
    M4 vp = m4_mul(m4_perspective(65.f * 3.14159265f / 180.f, asp, 0.5f, 600.f), m4_lookat(eye, tgt - eye, V3{0, 1, 0}));
    if (tiled) {
        GLsizei nb = (GLsizei)g_boxes.size();
        float ymax = 0.f; for (const Box& b : g_boxes) ymax = std::max(ymax, b.h);
        glBindVertexArray(G.cubeVao); glBindBuffer(GL_ARRAY_BUFFER, G.instVbo);
        /* 1. depth prepass */
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glUseProgram(G.tDepthP); glUniformMatrix4fv(G.dVP, 1, GL_FALSE, vp.m);
        glDrawElementsInstanced(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0, nb + 1); draws++;
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        /* 2. light bits per 32x32 tile */
        int tx = ((int)g_w + 31) / 32, ty = ((int)g_h + 31) / 32;
        tiles_cull(m4_inverse(vp), tx, ty, -0.25f, ymax + 0.05f, lp, nl);
        glActiveTexture(GL_TEXTURE1); glBindTexture(GL_TEXTURE_2D, G.tMask);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, tx, ty, GL_RGBA_INTEGER, GL_UNSIGNED_INT, g_tileBits.data());
        glActiveTexture(GL_TEXTURE0);
        /* 3. shading: only the visible surface (no depth writes), only the tile's lights */
        glDepthFunc(GL_LEQUAL); glDepthMask(GL_FALSE);
        glUseProgram(G.tShade); glUniformMatrix4fv(G.sVP, 1, GL_FALSE, vp.m); glUniform3f(G.sEye, eye.x, eye.y, eye.z);
        glUniform4fv(G.sLP, 128, lp); glUniform4fv(G.sLC, 128, lc); glUniform3f(G.sBase, 0.6f, 0.6f, 0.62f);
        glDrawElementsInstanced(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0, nb + 1); draws++;
        tris += 12L * (long)(nb + 1) * 2;
        glDepthFunc(GL_LESS); glDepthMask(GL_TRUE);
        glBindVertexArray(0); glDisable(GL_CULL_FACE); glDisable(GL_DEPTH_TEST);
        return draws;
    }
    glUseProgram(G.lit); glUniformMatrix4fv(G.uVP, 1, GL_FALSE, vp.m); glUniform3f(G.uEye, eye.x, eye.y, eye.z);
    glUniform1i(G.uNL, nl); glUniform4fv(G.uLP, 128, lp); glUniform4fv(G.uLC, 128, lc);
    glBindVertexArray(G.cubeVao);
    glBindBuffer(GL_ARRAY_BUFFER, G.instVbo);
    if (s.kind == K_LIGHTS) {
        glUniform1i(G.uTint, 0); glUniform3f(G.uBase, 0.6f, 0.6f, 0.62f);
        glDrawElementsInstancedBaseInstance(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0, 1, 0); draws++;  /* the ground */
        glUniform1i(G.uTint, 1);
        glDrawElementsInstancedBaseInstance(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0, (GLsizei)g_boxes.size(), 1); draws++;
        tris += 12L * (long)(g_boxes.size() + 1);
    } else {
        glUniform1i(G.uTint, 1);
        glDrawElementsInstanced(GL_TRIANGLES, 36, GL_UNSIGNED_SHORT, 0, (GLsizei)g_visibleObjs); draws++;
        tris += 12L * g_visibleObjs;
    }
    glBindVertexArray(0); glDisable(GL_CULL_FACE); glDisable(GL_DEPTH_TEST);
    return draws;
}

/* ------------------------------------------------------------------ results */
struct Result {
    bool run = false, failed = false; char note[96] = "";
    int frames = 0; double avgFps = 0, low1Fps = 0, avgMs = 0, maxMs = 0, cpuMs = 0, gpuMs = -1;
    long draws = 0, tris = 0; double heapMb = 0, gpuMb = 0; int extra = 0;
} R[kNumStages];
static double g_score; static bool g_complete;

static void results_write(const char* hw) {
    char b[1024]; std::string j = "{\n  \"app\": \"Nexvyn Bench\",\n";
    snprintf(b, sizeof b, "  \"complete\": %s,\n  \"score\": %.1f,\n  \"resolution\": \"%ux%u\",\n  \"vsync\": false,\n  \"gpu\": \"%s\",\n  \"stages\": [\n", g_complete ? "true" : "false", g_score, g_w, g_h, hw);
    j += b;
    bool first = true;
    for (int i = 0; i < kNumStages; i++) {
        if (!R[i].run) continue;
        const Result& r = R[i];
        snprintf(b, sizeof b, "%s    {\"id\": \"%s\", \"name\": \"%s\", \"ok\": %s, \"frames\": %d, \"avg_fps\": %.1f, \"low1_fps\": %.1f, \"avg_ms\": %.3f, \"max_ms\": %.2f, "
                 "\"cpu_ms\": %.3f, \"gpu_ms\": %.3f, \"draws\": %ld, \"triangles\": %ld, \"heap_mb\": %.1f, \"gpu_mb\": %.1f, \"visible\": %d, \"note\": \"%s\"}",
                 first ? "" : ",\n", kStages[i].id, kStages[i].name, r.failed ? "false" : "true", r.frames, r.avgFps, r.low1Fps, r.avgMs, r.maxMs, r.cpuMs, r.gpuMs, r.draws, r.tris, r.heapMb, r.gpuMb, r.extra, r.note);
        j += b; first = false;
    }
    j += "\n  ]\n}\n";
    nxn_fs_write(NXN_DIR_DATA, "bench_results.json", j.data(), j.size());
    std::string t = "Nexvyn Bench\n";
    snprintf(b, sizeof b, "%ux%u, no frame cap, gpu: %s\n\n", g_w, g_h, hw); t += b;
    t += "stage                              fps   1%low   avg ms  max ms  cpu ms  gpu ms   draws     tris\n";
    int fails = 0;
    for (int i = 0; i < kNumStages; i++) {
        if (!R[i].run) continue;
        const Result& r = R[i];
        if (r.failed) fails++;
        char gp[16]; if (r.gpuMs >= 0) snprintf(gp, sizeof gp, "%6.2f", r.gpuMs); else snprintf(gp, sizeof gp, "   n/a");
        snprintf(b, sizeof b, "%-30s %7.1f %7.1f %8.2f %7.1f %7.2f  %s %7ld %8ld  heap %.0f MB gpu %.0f MB %s\n", kStages[i].name, r.avgFps, r.low1Fps, r.avgMs, r.maxMs, r.cpuMs, gp, r.draws, r.tris, r.heapMb, r.gpuMb, r.note);
        t += b;
    }
    snprintf(b, sizeof b, "\nRESULT score=%.1f stages=%d fail=%d%s\n", g_score, kScoreStages, fails, g_complete ? "" : " (partial)"); t += b;
    t += "\n--- log ---\n" + g_report;
    nxn_fs_write(NXN_DIR_DATA, "bench_report.txt", t.data(), t.size());
}

/* ------------------------------------------------------------------ UI */
static void feed_imgui(float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)g_w, (float)g_h); io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
}
/* "shots=1" in the autorun text: one 24-bit BMP of the visible frame per stage (bench_shot_<id>.bmp); that frame is not measured */
static void screenshot(const char* name) {
    size_t rowb = ((size_t)g_w * 3 + 3) & ~(size_t)3, sz = rowb * g_h;
    std::vector<uint8_t> buf(54 + sz, 0);
    uint8_t* h = buf.data(); h[0] = 'B'; h[1] = 'M';
    uint32_t fs = (uint32_t)buf.size(), off = 54, ihs = 40, w = g_w, hh = g_h; uint16_t pl = 1, bpp = 24;
    memcpy(h + 2, &fs, 4); memcpy(h + 10, &off, 4); memcpy(h + 14, &ihs, 4); memcpy(h + 18, &w, 4); memcpy(h + 22, &hh, 4); memcpy(h + 26, &pl, 2); memcpy(h + 28, &bpp, 2);
    glBindFramebuffer(GL_FRAMEBUFFER, 0); glPixelStorei(GL_PACK_ALIGNMENT, 4); glReadBuffer(GL_BACK);
    glReadPixels(0, 0, (GLsizei)g_w, (GLsizei)g_h, 0x80E0 /* GL_BGR */, GL_UNSIGNED_BYTE, h + 54);
    nxn_fs_write(NXN_DIR_DATA, name, buf.data(), buf.size());
}
static void text_box(ImDrawList* dl, float x, float y, const char* t) {
    ImVec2 ts = ImGui::CalcTextSize(t);
    dl->AddRectFilled(ImVec2(x - 6, y - 4), ImVec2(x + ts.x + 6, y + ts.y + 4), IM_COL32(0, 0, 0, 170), 6.f);
    dl->AddText(ImVec2(x, y), IM_COL32(255, 255, 255, 240), t);
}

/* ------------------------------------------------------------------ main loop */
enum Phase { P_INTRO, P_LOAD, P_RUN, P_DONE };
static int app_main(int argc, char** argv) {
    char probe[96] = ""; size_t got = 0;
    bool autorun = nxn_fs_read(NXN_DIR_DATA, "autorun", probe, sizeof probe - 1, &got) == NXN_OK;
    if (autorun) probe[got] = 0;
    for (int i = 1; i < argc; i++) if (argv[i] && strstr(argv[i], "autorun")) autorun = true;
    float secs = 8.f; bool use[kNumStages]; for (int i = 0; i < kNumStages; i++) use[i] = true;
    bool shots = autorun && strstr(probe, "shots=1"), shotDone[kNumStages] = {false};
    if (autorun) {
        const char* p = strstr(probe, "secs="); if (p) { float v = (float)atof(p + 5); if (v >= 2.f && v <= 60.f) secs = v; }
        p = strstr(probe, "stages=");
        if (p) { p += 7; for (int i = 0; i < kNumStages; i++) use[i] = false; for (; *p >= '1' && *p <= '9'; p++) if (*p - '1' < kNumStages) use[*p - '1'] = true; }
    }
    nxn_display_params dp = NXN_STRUCT_INIT(nxn_display_params); dp.flags = NXN_DISPLAY_NO_VSYNC;
    if (nxn_display_open(&dp, &g_disp) != NXN_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available"); return 1; }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h); if (!g_w || !g_h) { g_w = 1280; g_h = 720; }
    char glr[96]; snprintf(glr, sizeof glr, "%s", (const char*)glGetString(GL_RENDERER));
    for (char* c = glr; *c; c++) if (*c == '"' || *c == '\\') *c = ' ';
    if (ngfx_device_create(NULL, &g_dev) != NGFX_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); return 1; }
    gl_init();
    bool queries = glGenQueries && glBeginQuery && glGetQueryObjectui64v;
    GLuint qid[4] = {0, 0, 0, 0}; bool qpend[4] = {false, false, false, false};
    if (queries) glGenQueries(4, qid);
    logf_("gl %s | %s | autorun %d | stage %.0f s | gpu timer %s | own gl %s", (const char*)glGetString(GL_VERSION), glr, autorun ? 1 : 0, secs, queries ? "present" : "missing", G.ok ? "ok" : "FAILED");

    IMGUI_CHECKVERSION(); ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); io.IniFilename = nullptr; io.LogFilename = nullptr;
    ImFontConfig fc; fc.SizePixels = 18.f; io.Fonts->AddFontDefault(&fc);
    ImGui::StyleColorsDark();
    ImGui_ImplOpenGL3_Init("#version 330 core");

    bool needCity = false; for (int i = 0; i < kNumStages; i++) if (use[i] && kStages[i].kind == K_CITY) needCity = true;
    Phase phase = autorun ? P_LOAD : P_INTRO;
    int stage = -1; uint64_t stageT0 = 0, doneT = 0, last = nxn_time_ns(); bool cityStarted = false, pathBuilt = false;
    std::vector<float> frames, cpuv; double gpuSum = 0; int gpuN = 0; long drawSum = 0, triSum = 0; int qi = 0;
    float visSum = 0;

    while (!nxn_should_quit()) {
        uint64_t now = nxn_time_ns(); float dt = (float)(now - last) / 1e9f; last = now;
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && ev.width && ev.height) { nxn_display_resize(g_disp, ev.width, ev.height); nxn_display_size(g_disp, &g_w, &g_h); }
            ev.size = sizeof ev;
        }
        nxn_input_poll(&g_in);
        if (!g_ready) {
            int pr = ngfx_device_prepare(g_dev, &g_prepDone, &g_prepTotal);
            if (pr < 0) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); break; }
            g_ready = pr == 1;
        }
        if (g_ready && needCity && !cityStarted && phase != P_INTRO) { city_load(); cityStarted = true; }
        if (cityStarted) city_step();
        if (cityStarted && C.geom && !pathBuilt) { city_path_build(); pathBuilt = true; }
        if (phase == P_INTRO && ((g_in.pressed & NXN_BTN_A) || g_in.touch_count > 0)) { phase = P_LOAD; if (g_ready && needCity) { city_load(); cityStarted = true; } }

        /* what the frame shows: the stage, or the load / intro / score screen */
        bool measuring = false; float u = 0, st = 0;
        if (phase == P_LOAD && g_ready && (!needCity || C.done || C.failed)) {
            stage = -1; phase = P_RUN;
        }
        if (phase == P_RUN) {
            if (stage < 0 || (now - stageT0) / 1e9f >= secs) {
                if (stage >= 0) {  /* close the finished stage */
                    Result& r = R[stage]; r.run = true;
                    double sum = 0, mx = 0, cs = 0; for (size_t k = 0; k < frames.size(); k++) { sum += frames[k]; mx = std::max(mx, (double)frames[k]); cs += cpuv[k]; }
                    r.frames = (int)frames.size();
                    if (r.frames > 0 && !r.failed) {
                        std::vector<float> s = frames; std::sort(s.begin(), s.end(), std::greater<float>());
                        size_t n1 = std::max<size_t>(1, s.size() / 100); double w = 0; for (size_t k = 0; k < n1; k++) w += s[k];
                        r.avgMs = sum / r.frames; r.avgFps = 1000.0 / r.avgMs; r.low1Fps = 1000.0 / (w / (double)n1); r.maxMs = mx; r.cpuMs = cs / r.frames;
                        r.gpuMs = gpuN > 0 && gpuSum / gpuN >= 0.05 ? gpuSum / gpuN : -1; r.draws = drawSum / r.frames; r.tris = triSum / r.frames;
                        r.heapMb = heap_bytes() / 1048576.0; r.gpuMb = gpu_bytes() / 1048576.0; r.extra = (int)(visSum / r.frames);
                    }
                    g_score = 0; for (int i = 0; i < kScoreStages && i < kNumStages; i++) g_score += R[i].run ? R[i].avgFps : 0;
                    logf_("stage %d %s: %.1f fps (1%% low %.1f), avg %.2f ms, max %.1f ms, cpu %.2f ms, gpu %.2f ms, draws %ld, tris %ld, visible %d", stage + 1, kStages[stage].name,
                          r.avgFps, r.low1Fps, r.avgMs, r.maxMs, r.cpuMs, r.gpuMs, r.draws, r.tris, r.extra);
                    results_write(glr);
                }
                do { stage++; } while (stage < kNumStages && !use[stage]);
                frames.clear(); cpuv.clear(); gpuSum = 0; gpuN = 0; drawSum = triSum = 0; visSum = 0; stageT0 = now;
                if (stage >= kNumStages) { phase = P_DONE; doneT = now; g_complete = true; stage = kNumStages; results_write(glr); logf_("score %.1f", g_score); }
                else {
                    stage_prepare(kStages[stage]);
                    if (kStages[stage].kind == K_CITY && (C.failed || !pathBuilt)) { R[stage].failed = true; snprintf(R[stage].note, sizeof R[stage].note, "city not loaded"); }
                    if (kStages[stage].kind != K_CITY && !G.ok) { R[stage].failed = true; snprintf(R[stage].note, sizeof R[stage].note, "own GL failed"); }
                }
            }
            if (phase == P_RUN && stage < kNumStages) { st = (float)(now - stageT0) / 1e9f; u = std::min(1.f, st / secs); measuring = st >= kWarmup && !R[stage].failed; }
        }

        /* ---- draw */
        /* the shot frame shows a fixed moment of the stage (70 %), so two runs give the same picture (pixel comparisons) */
        const bool shotNow = shots && measuring && phase == P_RUN && stage < kNumStages && !shotDone[stage] && st >= secs * 0.7f;
        if (shotNow) { st = secs * 0.7f; u = 0.7f; }
        uint64_t tCpu0 = nxn_time_ns();
        feed_imgui(dt);
        long tris = 0; int draws = 0; bool gpuQ = false;
        ImGui_ImplOpenGL3_NewFrame(); ImGui::NewFrame();
        ImDrawList* dl = ImGui::GetBackgroundDrawList();
        char t[256];
        if (phase == P_RUN && stage < kNumStages && !R[stage].failed) {
            const Stage& s = kStages[stage];
            if (queries) { glBeginQuery(GL_TIME_ELAPSED, qid[qi]); gpuQ = true; }
            if (s.kind == K_CITY) {
                city_cam_at(u);
                for (int c = 0; c < s.copies; c++) {
                    ngfx_view view = {sizeof view, {g_cam.pos.x + 0.37f * (float)c, g_cam.pos.y, g_cam.pos.z}, g_cam.yaw, g_cam.pitch, g_cam.fov, g_w, g_h, 1.0f,
                                      (s.shadows ? (uint32_t)NGFX_VIEW_SHADOWS : 0u) | (s.fxaa ? (uint32_t)NGFX_VIEW_FXAA : 0u), 1.0f, 0};
                    ngfx_render(g_dev, C.h, &view, &g_st);
                    draws += (int)(g_st.draws + g_st.shadow_draws); tris += (long)g_st.triangles;
                }
                glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glDisable(GL_DEPTH_TEST);
            } else {
                draws = draw_own(s, st, tris);
                if (draws < 0) { R[stage].failed = true; snprintf(R[stage].note, sizeof R[stage].note, "not supported by this GPU (see log)"); draws = 0; }
            }
            snprintf(t, sizeof t, "Stage %d/%d  %s\n%.0f / %.0f s%s", stage + 1, kNumStages, s.name, st, secs, measuring ? "" : "  (warm-up)");
            text_box(dl, 12, 10, t);
        } else if (phase == P_RUN && stage < kNumStages) {  /* a failed stage: show it for a moment */
            glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glClearColor(0.1f, 0.03f, 0.03f, 1); glClear(GL_COLOR_BUFFER_BIT);
            snprintf(t, sizeof t, "Stage %d %s: %s", stage + 1, kStages[stage].name, R[stage].note); text_box(dl, 12, 10, t);
            if (st > 1.0f) stageT0 = now - (uint64_t)(secs * 1e9f);  /* next stage */
        } else {
            glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glClearColor(0.04f, 0.05f, 0.08f, 1); glClear(GL_COLOR_BUFFER_BIT);
            if (phase == P_INTRO) { text_box(dl, (float)g_w * 0.5f - 200, (float)g_h * 0.5f - 30, "Nexvyn Bench\nPress A or touch to start"); }
            else if (phase == P_LOAD) {
                float frac = !g_ready ? (float)g_prepDone / (float)g_prepTotal : C.st.progress;
                snprintf(t, sizeof t, "%s", !g_ready ? "Preparing shaders" : C.failed ? C.st.error : "Loading the city");
                float w = std::min(520.f, (float)g_w - 40.f), x = ((float)g_w - w) * 0.5f, y = (float)g_h * 0.5f;
                dl->AddText(ImVec2(x, y - 32), IM_COL32(255, 255, 255, 240), t);
                dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + 14), IM_COL32(70, 76, 90, 255), 5.f);
                dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w * frac, y + 14), IM_COL32(90, 170, 255, 255), 5.f);
            } else {  /* P_DONE: the score and the table */
                std::string tb; snprintf(t, sizeof t, "Nexvyn Bench   score %.0f\n\n", g_score); tb = t;
                for (int i = 0; i < kNumStages; i++) if (R[i].run) { snprintf(t, sizeof t, "%-30s %7.1f fps  1%% low %7.1f  %6.2f ms\n", kStages[i].name, R[i].avgFps, R[i].low1Fps, R[i].avgMs); tb += t; }
                text_box(dl, 30, 30, tb.c_str());
            }
        }
        ImGui::Render();
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        if (gpuQ) glEndQuery(GL_TIME_ELAPSED);
        bool shotFrame = false;
        if (shotNow) { char nm[64]; snprintf(nm, sizeof nm, "bench_shot_%s.bmp", kStages[stage].id); screenshot(nm); shotDone[stage] = shotFrame = true; }
        for (GLenum e; (e = glGetError()) != GL_NO_ERROR;) { (void)e; }
        uint64_t tCpu1 = nxn_time_ns();
        nxn_display_swap(g_disp);

        /* GPU timer: read the oldest query of the ring (three frames old), never the newest (no stall) */
        if (queries) {
            if (gpuQ) qpend[qi] = true;
            int rd = (qi + 1) % 4;
            if (qpend[rd]) {
                GLuint avail = 0; glGetQueryObjectuiv(qid[rd], GL_QUERY_RESULT_AVAILABLE, &avail);
                if (avail) { GLuint64 ns = 0; glGetQueryObjectui64v(qid[rd], GL_QUERY_RESULT, &ns); qpend[rd] = false; if (measuring) { gpuSum += (double)ns / 1e6; gpuN++; } }
            }
            qi = (qi + 1) % 4;
        }
        if (measuring && !shotFrame) {
            frames.push_back(dt * 1000.f); cpuv.push_back((float)(tCpu1 - tCpu0) / 1e6f); drawSum += draws; triSum += tris;
            if (kStages[stage].kind == K_CPU || kStages[stage].kind == K_LIGHTS_TILED) visSum += (float)g_visibleObjs;
        }
        if (phase == P_DONE && autorun && now - doneT > 6000000000ull) { nxn_request_return(NXN_RETURN_NORMAL, 7, NULL); doneT = now + 3600ull * 1000000000ull; }
        if (phase == P_DONE && !autorun && (g_in.pressed & NXN_BTN_A)) { for (auto& r : R) r = Result(); g_complete = false; g_score = 0; phase = P_RUN; stage = -1; g_report.clear(); }
    }
    results_write(glr);
    if (C.h) ngfx_scene_free(g_dev, C.h);
    ngfx_device_destroy(g_dev);
    ImGui_ImplOpenGL3_Shutdown(); ImGui::DestroyContext();
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
