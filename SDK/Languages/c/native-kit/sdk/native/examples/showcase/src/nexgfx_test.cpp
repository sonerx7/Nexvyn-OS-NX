/* NexGFX native self-test (windowed only): draws one lit triangle with the ngfx_* PBR renderer into an offscreen target and
 * checks the pixels. The scene is written in memory (a 1-triangle .nxsc and an empty .nxtx), so the test needs no asset. */
#include "showcase.h"
#include <glad/glad.h>
#include <nexvyn/nexgfx_native.h>
#include <stdio.h>
#include <string.h>
#include <vector>

static void put32(std::vector<uint8_t>& b, uint32_t v) { b.insert(b.end(), (uint8_t*)&v, (uint8_t*)&v + 4); }
static void putf(std::vector<uint8_t>& b, float v) { b.insert(b.end(), (uint8_t*)&v, (uint8_t*)&v + 4); }

static std::vector<uint8_t> triangle_scene() {
    std::vector<uint8_t> b = {'N', 'X', 'S', 'C'};
    put32(b, 1); put32(b, 1); put32(b, 0); put32(b, 1); put32(b, 3); put32(b, 3); /* version, materials, textures, chunks, vertices, indices */
    const float lo[3] = {-3, -2, -5}, hi[3] = {3, 3, -5};
    for (float f : lo) putf(b, f);
    for (float f : hi) putf(b, f);
    put32(b, 0); for (int i = 0; i < 5; i++) putf(b, 0); putf(b, 60); /* no camera */
    put32(b, 0); for (int i = 0; i < 7; i++) putf(b, 0);              /* no sun (NexGFX uses its default) */
    const float base[4] = {0.9f, 0.1f, 0.1f, 1}, emis[3] = {0, 0, 0};
    for (float f : base) putf(b, f);
    for (float f : emis) putf(b, f);
    putf(b, 0.f); putf(b, 0.5f); putf(b, 1.f);                         /* metal, rough, opacity */
    for (int i = 0; i < 4; i++) put32(b, (uint32_t)-1);
    put32(b, 0); put32(b, 0); put32(b, 3); put32(b, 0); put32(b, 3);   /* chunk: material, vOff, vCount, iOff, iCount */
    for (float f : lo) putf(b, f);
    for (float f : hi) putf(b, f);
    const float pos[3][3] = {{-3, -2, -5}, {3, -2, -5}, {0, 3, -5}};
    for (int v = 0; v < 3; v++) {
        for (float f : pos[v]) putf(b, f);
        const int8_t nrm[4] = {0, 0, 127, 0}, tan[4] = {127, 0, 0, 127};
        b.insert(b.end(), (const uint8_t*)nrm, (const uint8_t*)nrm + 4);
        b.insert(b.end(), (const uint8_t*)tan, (const uint8_t*)tan + 4);
        putf(b, 0); putf(b, 0);
    }
    put32(b, 0); put32(b, 1); put32(b, 2);
    return b;
}

void nexgfx_selftest(void) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    if (!(caps.features & NXN_CAP_NEXGFX)) { feat_set(F_NEXGFX, RES_NA, "NXN_CAP_NEXGFX is not set (not in a Nexvyn OS window)"); return; }
    std::vector<uint8_t> sc = triangle_scene();
    const uint8_t tx[12] = {'N', 'X', 'T', 'X', 1, 0, 0, 0, 0, 0, 0, 0};
    char psc[512], ptx[512];
    if (nxn_fs_write(NXN_DIR_DATA, "nexgfx_test.nxsc", sc.data(), sc.size()) != NXN_OK || nxn_fs_write(NXN_DIR_DATA, "nexgfx_test.nxtx", tx, sizeof tx) != NXN_OK) {
        feat_set(F_NEXGFX, RES_FAIL, "cannot write the test scene"); return;
    }
    nxn_fs_path(NXN_DIR_DATA, "nexgfx_test.nxsc", psc, sizeof psc); nxn_fs_path(NXN_DIR_DATA, "nexgfx_test.nxtx", ptx, sizeof ptx);
    ngfx_device* dev = nullptr;
    if (ngfx_device_create(NULL, &dev) != NGFX_OK) { feat_set(F_NEXGFX, RES_FAIL, "device: %s", ngfx_native_error()); return; }
    int pr = 0, steps = 0;
    while (pr == 0 && steps++ < 32) pr = ngfx_device_prepare(dev, NULL, NULL);
    if (pr != 1) { feat_set(F_NEXGFX, RES_FAIL, "prepare: %s", ngfx_native_error()); ngfx_device_destroy(dev); return; }
    ngfx_scene sc_h = 0; ngfx_scene_desc d = {sizeof d, psc, ptx, 0};
    if (ngfx_scene_load(dev, &d, &sc_h) != NGFX_OK) { feat_set(F_NEXGFX, RES_FAIL, "load: %s", ngfx_native_error()); ngfx_device_destroy(dev); return; }
    ngfx_scene_status st = {sizeof st};
    uint64_t t0 = nxn_time_ns();
    while (!st.ready && !st.failed && nxn_time_ns() - t0 < 5000000000ull) { ngfx_scene_step(dev, sc_h, 4000000ull, &st); nxn_sleep_ns(2000000); }
    if (!st.ready) { feat_set(F_NEXGFX, RES_FAIL, "scene not ready: %s", st.failed ? st.error : "timeout"); ngfx_scene_free(dev, sc_h); ngfx_device_destroy(dev); return; }
    const int W = 64, H = 64;
    GLuint tex = 0, fbo = 0, dep = 0;
    glGenTextures(1, &tex); glBindTexture(GL_TEXTURE_2D, tex); glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenRenderbuffers(1, &dep); glBindRenderbuffer(GL_RENDERBUFFER, dep); glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, W, H);
    glGenFramebuffers(1, &fbo); glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, dep);
    ngfx_view view = {sizeof view, {0, 0, 0}, 0.f, 0.f, 60.f, (uint32_t)W, (uint32_t)H, 1.f, 0, 1.f, fbo};
    ngfx_frame_stats fs = {sizeof fs};
    int rr = ngfx_render(dev, sc_h, &view, &fs);
    uint8_t center[4] = {0}, corner[4] = {0};
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glReadPixels(W / 2, H / 3, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, center);
    glReadPixels(2, H - 3, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, corner);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &fbo); glDeleteRenderbuffers(1, &dep); glDeleteTextures(1, &tex);
    ngfx_device_caps dc = {sizeof dc}; ngfx_device_caps_get(dev, &dc);
    bool ok = rr == NGFX_OK && fs.draws == 1 && fs.triangles == 1 && center[0] > 40 && center[0] > 2 * center[1] && corner[2] > corner[0];
    feat_set(F_NEXGFX, ok ? RES_OK : RES_FAIL, "api %u.%u: red triangle pixel (%u,%u,%u), sky pixel (%u,%u,%u), %u draw, %u tri, gpu %.1f MB", ngfx_native_version() >> 16,
             ngfx_native_version() & 0xffff, center[0], center[1], center[2], corner[0], corner[1], corner[2], fs.draws, fs.triangles, (double)dc.gpu_bytes / 1048576.0);
    ngfx_scene_free(dev, sc_h);
    ngfx_device_destroy(dev);
}
