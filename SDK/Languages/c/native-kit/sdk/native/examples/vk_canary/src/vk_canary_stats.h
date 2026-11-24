#ifndef VK_CANARY_STATS_H
#define VK_CANARY_STATS_H

#include <stddef.h>
#include <stdint.h>
#ifndef NEXVYN_NXN_CAPS_H
#include <nexvyn/nxn_caps.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define VK_CANARY_WINDOW_FRAMES 600u
#define VK_CANARY_MAX_SWAPCHAIN_IMAGES 8u

typedef enum vk_canary_mode {
    VK_CANARY_MODE_WINDOW = 0,
    VK_CANARY_MODE_FULLSCREEN = 1
} vk_canary_mode;

typedef enum vk_canary_action {
    VK_CANARY_ACTION_CONTINUE = 0,
    VK_CANARY_ACTION_RECREATE = 1,
    VK_CANARY_ACTION_REOPEN_SURFACE = 2,
    VK_CANARY_ACTION_RETRY = 3,
    VK_CANARY_ACTION_DEVICE_LOST = 4,
    VK_CANARY_ACTION_FATAL = 5
} vk_canary_action;

typedef enum vk_canary_phase {
    VK_CANARY_OPEN_SURFACE,
    VK_CANARY_CREATE_CHAIN,
    VK_CANARY_DRAW,
    VK_CANARY_PAUSE,
    VK_CANARY_STOP
} vk_canary_phase;

typedef enum vk_canary_retirement {
    VK_CANARY_RETIRED,
    VK_CANARY_RETIRE_DEVICE_LOST,
    VK_CANARY_RETIRE_FAILED
} vk_canary_retirement;

typedef struct vk_canary_config {
    vk_canary_mode mode;
    int mode_override;
    uint64_t max_frames;
    uint32_t max_windows;
} vk_canary_config;

typedef struct vk_canary_stats {
    uint64_t samples_ns[VK_CANARY_WINDOW_FRAMES];
    uint32_t count;
    uint32_t windows_completed;
    uint64_t total_frames;
} vk_canary_stats;

typedef struct vk_canary_summary {
    uint32_t window_index;
    uint32_t frames;
    uint64_t total_frames;
    uint64_t min_ns;
    uint64_t max_ns;
    uint64_t avg_ns;
    uint64_t p50_ns;
    uint64_t p95_ns;
} vk_canary_summary;

void vk_canary_stats_init(vk_canary_stats* s);
/* Records one frame duration in nanoseconds. Returns 1 when a 600-frame window is full. */
int vk_canary_stats_record(vk_canary_stats* s, uint64_t frame_ns);
/* Computes min/max/avg/p50/p95 over the currently buffered samples. Returns 1 on success, 0 if empty. */
int vk_canary_stats_summarize(const vk_canary_stats* s, vk_canary_summary* out);
/* Advances window counter and clears the sample buffer for the next 600 frames. */
void vk_canary_stats_reset_window(vk_canary_stats* s);

const char* vk_canary_mode_name(vk_canary_mode mode);
vk_canary_mode vk_canary_parse_manifest_mode(const char* json, size_t len);
int vk_canary_parse_args(int argc, char* const* argv, vk_canary_config* out);
/* Same options as vk_canary_parse_args, from whitespace-separated text (the data folder's args.txt: native apps
 * get no command line, so a test script writes the options there). NULL or empty text gives the defaults.
 * Returns 0 on success, -1 on an invalid option or more than 8 words / a word longer than 31 bytes. */
int vk_canary_parse_arg_text(const char* text, vk_canary_config* out);

int vk_canary_caps_supports_vulkan(const nxn_caps* caps, uint16_t* out_major, uint16_t* out_minor);
vk_canary_action vk_canary_classify_result(int32_t vk_result);
int vk_canary_present_accepted(int32_t vk_result);

static inline vk_canary_action vk_canary_wsi_action(vk_canary_phase phase, int32_t vk_result) {
    enum { CANARY_VK_ERROR_NATIVE_WINDOW_IN_USE_KHR = -1000000001 };
    if (phase == VK_CANARY_OPEN_SURFACE && vk_result == CANARY_VK_ERROR_NATIVE_WINDOW_IN_USE_KHR) {
        return VK_CANARY_ACTION_RETRY;
    }
    return vk_canary_classify_result(vk_result);
}

/* Pause is a loop decision. The pending WSI phase survives until resume. */
static inline vk_canary_phase vk_canary_next_step(vk_canary_phase phase, int quit, int suspended,
                                                  uint32_t width, uint32_t height) {
    if (quit || phase == VK_CANARY_STOP) return VK_CANARY_STOP;
    if (suspended || width == 0u || height == 0u) return VK_CANARY_PAUSE;
    return phase;
}

static inline vk_canary_phase vk_canary_wsi_transition(vk_canary_phase phase, vk_canary_action action) {
    switch (action) {
        case VK_CANARY_ACTION_CONTINUE:
            return phase == VK_CANARY_OPEN_SURFACE ? VK_CANARY_CREATE_CHAIN : VK_CANARY_DRAW;
        case VK_CANARY_ACTION_REOPEN_SURFACE:
            return VK_CANARY_OPEN_SURFACE;
        case VK_CANARY_ACTION_RECREATE:
            return phase == VK_CANARY_OPEN_SURFACE ? phase : VK_CANARY_CREATE_CHAIN;
        case VK_CANARY_ACTION_RETRY:
            return phase;
        default:
            return VK_CANARY_STOP;
    }
}

static inline vk_canary_retirement vk_canary_idle_policy(int32_t vk_result) {
    switch (vk_canary_classify_result(vk_result)) {
        case VK_CANARY_ACTION_CONTINUE: return VK_CANARY_RETIRED;
        case VK_CANARY_ACTION_DEVICE_LOST: return VK_CANARY_RETIRE_DEVICE_LOST;
        default: return VK_CANARY_RETIRE_FAILED;
    }
}

static inline uint32_t vk_canary_present_semaphore_index(uint32_t image_index, uint32_t image_count) {
    return image_index < image_count ? image_index : UINT32_MAX;
}

uint32_t vk_canary_choose_image_count(uint32_t min_images, uint32_t max_images);
void vk_canary_choose_extent(uint32_t current_w, uint32_t current_h,
                             uint32_t min_w, uint32_t min_h,
                             uint32_t max_w, uint32_t max_h,
                             uint32_t desired_w, uint32_t desired_h,
                             uint32_t* out_w, uint32_t* out_h);

int vk_canary_format_unavailable(char* buf, size_t cap);
int vk_canary_format_start(char* buf, size_t cap, vk_canary_mode mode,
                           uint16_t vk_major, uint16_t vk_minor);
int vk_canary_format_swapchain(char* buf, size_t cap, uint32_t image_count,
                               uint32_t width, uint32_t height, int32_t format);
int vk_canary_format_window(char* buf, size_t cap, const vk_canary_summary* sum,
                            uint32_t swapchain_images);
int vk_canary_format_verdict(char* buf, size_t cap, int pass, vk_canary_mode mode,
                             uint64_t total_frames, uint32_t swapchain_images,
                             uint32_t resizes, uint32_t suspends,
                             const char* reason, int32_t vk_result);

#ifdef __cplusplus
}
#endif

#endif /* VK_CANARY_STATS_H */
