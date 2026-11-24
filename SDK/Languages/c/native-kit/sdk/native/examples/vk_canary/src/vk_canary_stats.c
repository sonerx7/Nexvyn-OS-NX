#include "vk_canary_stats.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void heap_sift_down(uint64_t* a, uint32_t root, uint32_t end) {
    while (root * 2u + 1u < end) {
        uint32_t child = root * 2u + 1u;
        uint32_t swap_idx = root;
        if (a[swap_idx] < a[child]) swap_idx = child;
        if (child + 1u < end && a[swap_idx] < a[child + 1u]) swap_idx = child + 1u;
        if (swap_idx == root) return;
        uint64_t tmp = a[root];
        a[root] = a[swap_idx];
        a[swap_idx] = tmp;
        root = swap_idx;
    }
}

static void sort_u64(uint64_t* a, uint32_t n) {
    if (n < 2u) return;
    for (uint32_t start = n / 2u; start > 0u; --start) {
        heap_sift_down(a, start - 1u, n);
    }
    for (uint32_t end = n; end > 1u; --end) {
        uint64_t tmp = a[end - 1u];
        a[end - 1u] = a[0];
        a[0] = tmp;
        heap_sift_down(a, 0u, end - 1u);
    }
}

static uint64_t nearest_rank_percentile(const uint64_t* sorted, uint32_t n, uint32_t pct) {
    if (!sorted || n == 0u) return 0u;
    uint32_t rank = (pct * n + 99u) / 100u;
    if (rank == 0u) rank = 1u;
    if (rank > n) rank = n;
    return sorted[rank - 1u];
}

void vk_canary_stats_init(vk_canary_stats* s) {
    if (!s) return;
    memset(s, 0, sizeof(*s));
}

int vk_canary_stats_record(vk_canary_stats* s, uint64_t frame_ns) {
    if (!s) return 0;
    if (s->count < VK_CANARY_WINDOW_FRAMES) {
        s->samples_ns[s->count++] = frame_ns;
    }
    s->total_frames++;
    return s->count >= VK_CANARY_WINDOW_FRAMES ? 1 : 0;
}

int vk_canary_stats_summarize(const vk_canary_stats* s, vk_canary_summary* out) {
    if (!s || !out || s->count == 0u) return 0;
    uint32_t n = s->count <= VK_CANARY_WINDOW_FRAMES ? s->count : VK_CANARY_WINDOW_FRAMES;
    uint64_t sorted[VK_CANARY_WINDOW_FRAMES];
    memcpy(sorted, s->samples_ns, n * sizeof(uint64_t));
    sort_u64(sorted, n);

    uint64_t sum_q = 0u;
    uint64_t sum_r = 0u;
    for (uint32_t i = 0u; i < n; ++i) {
        sum_q += sorted[i] / n;
        sum_r += sorted[i] % n;
        if (sum_r >= n) {
            sum_q += sum_r / n;
            sum_r %= n;
        }
    }

    out->window_index = s->windows_completed + 1u;
    out->frames = n;
    out->total_frames = s->total_frames;
    out->min_ns = sorted[0];
    out->max_ns = sorted[n - 1u];
    out->avg_ns = sum_q;
    out->p50_ns = nearest_rank_percentile(sorted, n, 50u);
    out->p95_ns = nearest_rank_percentile(sorted, n, 95u);
    return 1;
}

void vk_canary_stats_reset_window(vk_canary_stats* s) {
    if (!s) return;
    if (s->count > 0u) {
        s->windows_completed++;
        s->count = 0u;
    }
}

const char* vk_canary_mode_name(vk_canary_mode mode) {
    return mode == VK_CANARY_MODE_FULLSCREEN ? "fullscreen" : "window";
}

static size_t skip_ws(const char* s, size_t len, size_t pos) {
    while (pos < len && (s[pos] == ' ' || s[pos] == '\t' || s[pos] == '\r' || s[pos] == '\n')) {
        ++pos;
    }
    return pos;
}

static int read_json_string(const char* s, size_t len, size_t* pos_io, char* out, size_t cap) {
    size_t pos = *pos_io;
    if (pos >= len || s[pos] != '"') return 0;
    ++pos;
    size_t w = 0u;
    while (pos < len) {
        char c = s[pos++];
        if (c == '"') {
            if (cap > 0u) out[w < cap ? w : cap - 1u] = '\0';
            *pos_io = pos;
            return 1;
        }
        if (c == '\\') {
            if (pos >= len) return 0;
            c = s[pos++];
        }
        if (cap > 1u && w + 1u < cap) {
            out[w++] = c;
        }
    }
    return 0;
}

vk_canary_mode vk_canary_parse_manifest_mode(const char* json, size_t len) {
    if (!json || len == 0u) return VK_CANARY_MODE_WINDOW;
    int depth = 0;
    size_t pos = 0u;
    while (pos < len) {
        char c = json[pos];
        if (c == '{') {
            ++depth;
            ++pos;
            continue;
        }
        if (c == '}') {
            if (depth > 0) --depth;
            ++pos;
            continue;
        }
        if (c == '"') {
            char token[64];
            if (!read_json_string(json, len, &pos, token, sizeof(token))) {
                break;
            }
            size_t after = skip_ws(json, len, pos);
            if (depth == 1 && after < len && json[after] == ':') {
                size_t val_pos = skip_ws(json, len, after + 1u);
                if (strcmp(token, "mode") == 0 && val_pos < len && json[val_pos] == '"') {
                    char value[64];
                    if (read_json_string(json, len, &val_pos, value, sizeof(value))) {
                        if (strcmp(value, "fullscreen") == 0) {
                            return VK_CANARY_MODE_FULLSCREEN;
                        }
                        if (strcmp(value, "window") == 0) {
                            return VK_CANARY_MODE_WINDOW;
                        }
                    }
                    pos = val_pos;
                }
            }
            continue;
        }
        ++pos;
    }
    return VK_CANARY_MODE_WINDOW;
}

static int parse_u64(const char* s, uint64_t* out) {
    if (!s || s[0] < '0' || s[0] > '9') return 0;
    char* end = NULL;
    errno = 0;
    unsigned long long val = strtoull(s, &end, 10);
    if (errno == ERANGE || *end != '\0' || val > UINT64_MAX) return 0;
    *out = (uint64_t)val;
    return 1;
}

int vk_canary_parse_args(int argc, char* const* argv, vk_canary_config* out) {
    if (!out) return -1;
    out->mode = VK_CANARY_MODE_WINDOW;
    out->mode_override = 0;
    out->max_frames = 0u;
    out->max_windows = 0u;
    if (argc <= 1 || !argv) return 0;

    for (int i = 1; i < argc; ++i) {
        const char* arg = argv[i];
        if (!arg) continue;
        if (strcmp(arg, "--mode") == 0) {
            if (i + 1 >= argc || !argv[i + 1]) return -1;
            const char* val = argv[++i];
            if (strcmp(val, "window") == 0) {
                out->mode = VK_CANARY_MODE_WINDOW;
                out->mode_override = 1;
            } else if (strcmp(val, "fullscreen") == 0) {
                out->mode = VK_CANARY_MODE_FULLSCREEN;
                out->mode_override = 1;
            } else {
                return -1;
            }
        } else if (strcmp(arg, "--frames") == 0) {
            uint64_t v = 0u;
            if (i + 1 >= argc || !parse_u64(argv[++i], &v)) return -1;
            out->max_frames = v;
        } else if (strcmp(arg, "--windows") == 0) {
            uint64_t v = 0u;
            if (i + 1 >= argc || !parse_u64(argv[++i], &v) || v > UINT32_MAX) return -1;
            out->max_windows = (uint32_t)v;
        } else {
            return -1;
        }
    }
    return 0;
}

static int arg_space(char c) { return c == ' ' || c == '\t' || c == '\r' || c == '\n'; }

int vk_canary_parse_arg_text(const char* text, vk_canary_config* out) {
    enum { MAX_WORDS = 8, MAX_WORD = 32 };
    char words[MAX_WORDS][MAX_WORD];
    char* argv[MAX_WORDS + 1];
    char name[] = "vk_canary";
    int argc = 1;
    argv[0] = name;
    for (const char* p = text; p && *p;) {
        while (arg_space(*p)) ++p;
        if (!*p) break;
        if (argc > MAX_WORDS) return -1;
        size_t n = 0;
        while (*p && !arg_space(*p)) {
            if (n + 1 >= MAX_WORD) return -1;
            words[argc - 1][n++] = *p++;
        }
        words[argc - 1][n] = '\0';
        argv[argc] = words[argc - 1];
        ++argc;
    }
    return vk_canary_parse_args(argc, argv, out);
}

int vk_canary_caps_supports_vulkan(const nxn_caps* caps, uint16_t* out_major, uint16_t* out_minor) {
    if (out_major) *out_major = 0u;
    if (out_minor) *out_minor = 0u;
    if (!caps || caps->size < offsetof(nxn_caps, features) + sizeof(caps->features)) return 0;
    if ((caps->features & NXN_CAP_VULKAN) == 0u) return 0;
    uint16_t major = 0, minor = 0;
    if (nxn_caps_gfx_version(caps, NXN_GFX_API_VULKAN, &major, &minor) != NXN_OK ||
        major == 0u || (major == 1u && minor < 3u)) return 0;
    if (out_major) *out_major = major;
    if (out_minor) *out_minor = minor;
    return 1;
}

/* Values from VkResult, kept Vulkan-header-free for refusal builds and host tests. */
enum {
    CANARY_VK_SUCCESS = 0,
    CANARY_VK_SUBOPTIMAL_KHR = 1000001003
};

int vk_canary_present_accepted(int32_t vk_result) {
    return vk_result == CANARY_VK_SUCCESS || vk_result == CANARY_VK_SUBOPTIMAL_KHR;
}

vk_canary_action vk_canary_classify_result(int32_t vk_result) {
    /* Standard Vulkan VkResult values (vulkan_core.h). */
    enum {
        CANARY_VK_NOT_READY = 1,
        CANARY_VK_TIMEOUT = 2,
        CANARY_VK_ERROR_DEVICE_LOST = -4,
        CANARY_VK_ERROR_SURFACE_LOST_KHR = -1000000000,
        CANARY_VK_ERROR_OUT_OF_DATE_KHR = -1000001004
    };
    switch (vk_result) {
        case CANARY_VK_SUCCESS:
            return VK_CANARY_ACTION_CONTINUE;
        case CANARY_VK_SUBOPTIMAL_KHR:
        case CANARY_VK_ERROR_OUT_OF_DATE_KHR:
            return VK_CANARY_ACTION_RECREATE;
        case CANARY_VK_ERROR_SURFACE_LOST_KHR:
            return VK_CANARY_ACTION_REOPEN_SURFACE;
        case CANARY_VK_NOT_READY:
        case CANARY_VK_TIMEOUT:
            return VK_CANARY_ACTION_RETRY;
        case CANARY_VK_ERROR_DEVICE_LOST:
            return VK_CANARY_ACTION_DEVICE_LOST;
        default:
            return VK_CANARY_ACTION_FATAL;
    }
}

uint32_t vk_canary_choose_image_count(uint32_t min_images, uint32_t max_images) {
    uint32_t desired = min_images >= VK_CANARY_MAX_SWAPCHAIN_IMAGES
        ? VK_CANARY_MAX_SWAPCHAIN_IMAGES
        : min_images > 0u ? min_images + 1u : 2u;
    if (max_images > 0u && desired > max_images) {
        desired = max_images;
    }
    if (desired > VK_CANARY_MAX_SWAPCHAIN_IMAGES) {
        desired = VK_CANARY_MAX_SWAPCHAIN_IMAGES;
    }
    if (desired == 0u) {
        desired = 2u;
    }
    return desired;
}

static uint32_t clamp_u32(uint32_t v, uint32_t lo, uint32_t hi) {
    if (hi > 0u && v > hi) v = hi;
    if (v < lo) v = lo;
    return v;
}

void vk_canary_choose_extent(uint32_t current_w, uint32_t current_h,
                             uint32_t min_w, uint32_t min_h,
                             uint32_t max_w, uint32_t max_h,
                             uint32_t desired_w, uint32_t desired_h,
                             uint32_t* out_w, uint32_t* out_h) {
    uint32_t w;
    uint32_t h;
    if (current_w != UINT32_MAX && current_h != UINT32_MAX) {
        w = current_w;
        h = current_h;
    } else {
        w = clamp_u32(desired_w, min_w, max_w);
        h = clamp_u32(desired_h, min_h, max_h);
    }
    if (out_w) *out_w = w;
    if (out_h) *out_h = h;
}

int vk_canary_format_unavailable(char* buf, size_t cap) {
    if (!buf || cap == 0u) return -1;
    return snprintf(buf, cap, "N5V11: UNAVAILABLE");
}

int vk_canary_format_start(char* buf, size_t cap, vk_canary_mode mode,
                           uint16_t vk_major, uint16_t vk_minor) {
    if (!buf || cap == 0u) return -1;
    return snprintf(buf, cap, "N5V11: start mode=%s vk_api=%u.%u",
                    vk_canary_mode_name(mode), (unsigned)vk_major, (unsigned)vk_minor);
}

int vk_canary_format_swapchain(char* buf, size_t cap, uint32_t image_count,
                               uint32_t width, uint32_t height, int32_t format) {
    if (!buf || cap == 0u) return -1;
    return snprintf(buf, cap, "N5V11: swapchain images=%u extent=%ux%u format=%d",
                    (unsigned)image_count, (unsigned)width, (unsigned)height, (int)format);
}

int vk_canary_format_window(char* buf, size_t cap, const vk_canary_summary* sum,
                            uint32_t swapchain_images) {
    if (!buf || cap == 0u || !sum) return -1;
    const double p50_ms = (double)sum->p50_ns / 1000000.0;
    const double p95_ms = (double)sum->p95_ns / 1000000.0;
    const double min_ms = (double)sum->min_ns / 1000000.0;
    const double max_ms = (double)sum->max_ns / 1000000.0;
    return snprintf(buf, cap,
                    "N5V11: window=%u frames=%u total_frames=%llu p50_ms=%.3f p95_ms=%.3f "
                    "min_ms=%.3f max_ms=%.3f swapchain_images=%u",
                    (unsigned)sum->window_index,
                    (unsigned)sum->frames,
                    (unsigned long long)sum->total_frames,
                    p50_ms, p95_ms, min_ms, max_ms,
                    (unsigned)swapchain_images);
}

int vk_canary_format_verdict(char* buf, size_t cap, int pass, vk_canary_mode mode,
                             uint64_t total_frames, uint32_t swapchain_images,
                             uint32_t resizes, uint32_t suspends,
                             const char* reason, int32_t vk_result) {
    if (!buf || cap == 0u) return -1;
    if (pass) {
        return snprintf(buf, cap,
                        "N5V11: PASS mode=%s frames=%llu swapchain_images=%u resizes=%u suspends=%u",
                        vk_canary_mode_name(mode),
                        (unsigned long long)total_frames,
                        (unsigned)swapchain_images,
                        (unsigned)resizes,
                        (unsigned)suspends);
    }
    return snprintf(buf, cap,
                    "N5V11: FAIL reason=%s vk_result=%d mode=%s frames=%llu",
                    reason && *reason ? reason : "unknown",
                    (int)vk_result,
                    vk_canary_mode_name(mode),
                    (unsigned long long)total_frames);
}
