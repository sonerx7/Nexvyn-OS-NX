/* Baked mesh blob shared by the host bake tool (tools/vk_model_bake.c) and the app.
 * Little endian, every section 4-byte aligned. See vk_model_bake.c for the section order. */
#ifndef VK_MODEL_FORMAT_H
#define VK_MODEL_FORMAT_H

#include <stdint.h>

#define VKM_MAGIC "NXVM"
#define VKM_VERSION 1u
#define VKM_NO_TEXTURE 0xFFFFFFFFu
#define VKM_MAX_GROUPS 64u
#define VKM_MAX_TEXTURES 64u

typedef struct vkm_header {
    char magic[4];
    uint32_t version;
    uint32_t vertex_count;
    uint32_t index_count; /* triangle list: index_count / 3 triangles */
    uint32_t group_count;
    uint32_t texture_count;
    float bounds_min[3];
    float bounds_max[3];
} vkm_header;

/* One draw: a contiguous index range with one base texture (or a flat colour). */
typedef struct vkm_group {
    uint32_t first_index;
    uint32_t index_count;
    uint32_t texture; /* VKM_NO_TEXTURE: colour only */
    float color[4];
} vkm_group;

/* Followed by `bytes` of RGBA8 mip levels (largest first), padded to 4 bytes. */
typedef struct vkm_texture {
    uint32_t width;
    uint32_t height;
    uint32_t mip_count;
    uint32_t bytes;
} vkm_texture;

/* 24 bytes: position, normal (snorm8, w unused), texture coordinate. */
typedef struct vkm_vertex {
    float pos[3];
    int8_t normal[4];
    float uv[2];
} vkm_vertex;

#endif
