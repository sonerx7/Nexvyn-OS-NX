/* Host tool: bake an FBX file into the compact mesh blob that vk_model loads at runtime.
 *
 * The console app never parses FBX: parsing a large FBX needs several times its size in RAM and
 * seconds of CPU. This tool flattens every mesh instance into world space, triangulates it,
 * groups triangles by base texture (one draw per group), welds identical vertices and decodes
 * each base texture into an RGBA8 mip chain with a size cap.
 *
 * Build (host): cc -O2 -o vk_model_bake vk_model_bake.c ufbx.c -lm   (with -I to lib/ufbx and lib/stb)
 * Run:          vk_model_bake model.fbx out.nxvmesh [--max-tex 512]
 *
 * File layout (little endian, every section 4-byte aligned), version 1:
 *   vkm_header
 *   vkm_group[group_count]
 *   per texture: vkm_texture, then RGBA8 bytes of every mip level, largest first
 *   vkm_vertex[vertex_count]
 *   uint32_t indices[index_count]
 */
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ufbx.h"

#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_HDR
#define STBI_NO_LINEAR
#include "stb_image.h"

#include "../src/vk_model_format.h"

typedef struct TexEntry {
    const ufbx_texture* tex;
    uint32_t width, height, mips;
    uint8_t* rgba; /* all mips */
    size_t bytes;
} TexEntry;

typedef struct Group {
    int32_t texture;  /* index into textures, -1 none */
    float color[4];
    vkm_vertex* verts; /* unindexed triangle list */
    size_t count, cap;
} Group;

static TexEntry g_tex[VKM_MAX_TEXTURES];
static uint32_t g_tex_count;
static Group g_groups[VKM_MAX_GROUPS];
static uint32_t g_group_count;
static uint32_t g_max_tex = 512;
static char g_fbx_dir[1024];
static char g_model_stem[1024]; /* <dir>/<name> without extension */

static void die(const char* msg) {
    fprintf(stderr, "vk_model_bake: %s\n", msg);
    exit(1);
}

static const char* base_name(const char* p) {
    const char* b = p;
    for (const char* s = p; *s; ++s) {
        if (*s == '/' || *s == '\\') b = s + 1;
    }
    return b;
}

static uint8_t* load_file_image(const char* path, int* w, int* h) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;
    fclose(f);
    int n = 0;
    return stbi_load(path, w, h, &n, 4);
}

/* Find the texture's pixels: embedded content, absolute path, path relative to the FBX, or the
 * basename next to the FBX / in its .fbm folder. */
static uint8_t* decode_texture(const ufbx_texture* t, int* w, int* h, char* used, size_t used_size) {
    int n = 0;
    if (t->content.size > 0) {
        snprintf(used, used_size, "(embedded) %s", base_name(t->filename.data));
        return stbi_load_from_memory((const stbi_uc*)t->content.data, (int)t->content.size, w, h, &n, 4);
    }
    const char* candidates[3] = {t->absolute_filename.data, t->filename.data, t->relative_filename.data};
    for (int i = 0; i < 3; ++i) {
        if (!candidates[i] || !candidates[i][0]) continue;
        uint8_t* px = load_file_image(candidates[i], w, h);
        if (px) {
            snprintf(used, used_size, "%s", candidates[i]);
            return px;
        }
        char path[2048];
        snprintf(path, sizeof(path), "%s/%s", g_fbx_dir, candidates[i]);
        px = load_file_image(path, w, h);
        if (px) {
            snprintf(used, used_size, "%s", path);
            return px;
        }
    }
    const char* bn = base_name(t->filename.data && t->filename.data[0] ? t->filename.data
                                                                        : t->relative_filename.data);
    if (!bn || !bn[0]) return NULL;
    char path[2048];
    snprintf(path, sizeof(path), "%s/%s", g_fbx_dir, bn);
    uint8_t* px = load_file_image(path, w, h);
    if (!px) {
        /* <model>.fbm next to the FBX: the folder FBX exporters extract textures to. */
        snprintf(path, sizeof(path), "%s.fbm/%s", g_model_stem, bn);
        px = load_file_image(path, w, h);
    }
    if (px) snprintf(used, used_size, "%s", path);
    return px;
}

/* Halve with a box filter until both sides fit the cap, then build the mip chain down to 1x1. */
static void build_mips(TexEntry* e, uint8_t* src, int sw, int sh) {
    uint32_t w = (uint32_t)sw, h = (uint32_t)sh;
    uint8_t* cur = src;
    while (w > g_max_tex || h > g_max_tex) {
        uint32_t nw = w > 1 ? w / 2 : 1, nh = h > 1 ? h / 2 : 1;
        uint8_t* next = (uint8_t*)malloc((size_t)nw * nh * 4);
        for (uint32_t y = 0; y < nh; ++y)
            for (uint32_t x = 0; x < nw; ++x)
                for (int c = 0; c < 4; ++c) {
                    uint32_t x0 = x * 2 < w ? x * 2 : w - 1, x1 = x * 2 + 1 < w ? x * 2 + 1 : w - 1;
                    uint32_t y0 = y * 2 < h ? y * 2 : h - 1, y1 = y * 2 + 1 < h ? y * 2 + 1 : h - 1;
                    unsigned s = cur[(y0 * w + x0) * 4 + c] + cur[(y0 * w + x1) * 4 + c] +
                                 cur[(y1 * w + x0) * 4 + c] + cur[(y1 * w + x1) * 4 + c];
                    next[(y * nw + x) * 4 + c] = (uint8_t)((s + 2) / 4);
                }
        if (cur != src) free(cur);
        cur = next;
        w = nw;
        h = nh;
    }
    e->width = w;
    e->height = h;
    /* Total size of the chain. */
    size_t total = 0;
    uint32_t mw = w, mh = h, mips = 0;
    for (;;) {
        total += (size_t)mw * mh * 4;
        ++mips;
        if (mw == 1 && mh == 1) break;
        mw = mw > 1 ? mw / 2 : 1;
        mh = mh > 1 ? mh / 2 : 1;
    }
    e->mips = mips;
    e->bytes = total;
    e->rgba = (uint8_t*)malloc(total);
    memcpy(e->rgba, cur, (size_t)w * h * 4);
    uint8_t* prev = e->rgba;
    mw = w;
    mh = h;
    for (uint32_t m = 1; m < mips; ++m) {
        uint32_t nw = mw > 1 ? mw / 2 : 1, nh = mh > 1 ? mh / 2 : 1;
        uint8_t* dst = prev + (size_t)mw * mh * 4;
        for (uint32_t y = 0; y < nh; ++y)
            for (uint32_t x = 0; x < nw; ++x)
                for (int c = 0; c < 4; ++c) {
                    uint32_t x1 = x * 2 + 1 < mw ? x * 2 + 1 : mw - 1, y1 = y * 2 + 1 < mh ? y * 2 + 1 : mh - 1;
                    unsigned s = prev[(y * 2 * mw + x * 2) * 4 + c] + prev[(y * 2 * mw + x1) * 4 + c] +
                                 prev[(y1 * mw + x * 2) * 4 + c] + prev[(y1 * mw + x1) * 4 + c];
                    dst[(y * nw + x) * 4 + c] = (uint8_t)((s + 2) / 4);
                }
        prev = dst;
        mw = nw;
        mh = nh;
    }
    if (cur != src) free(cur);
}

static int32_t texture_index(const ufbx_texture* t) {
    if (!t) return -1;
    for (uint32_t i = 0; i < g_tex_count; ++i) {
        if (g_tex[i].tex == t) return g_tex[i].rgba ? (int32_t)i : -1;
    }
    if (g_tex_count >= VKM_MAX_TEXTURES) return -1;
    TexEntry* e = &g_tex[g_tex_count];
    memset(e, 0, sizeof(*e));
    e->tex = t;
    int w = 0, h = 0;
    char used[2200] = "";
    uint8_t* px = decode_texture(t, &w, &h, used, sizeof(used));
    if (!px) {
        fprintf(stderr, "vk_model_bake: texture not found, using material colour: %s\n", t->filename.data);
        ++g_tex_count; /* remember the miss */
        return -1;
    }
    build_mips(e, px, w, h);
    stbi_image_free(px);
    printf("texture %u: %s (%dx%d -> %ux%u, %u mips)\n", g_tex_count, base_name(used), w, h, e->width,
           e->height, e->mips);
    return (int32_t)g_tex_count++;
}

static const ufbx_texture* material_base_texture(const ufbx_material* m) {
    if (!m) return NULL;
    if (m->pbr.base_color.texture) return m->pbr.base_color.texture;
    if (m->fbx.diffuse_color.texture) return m->fbx.diffuse_color.texture;
    return NULL;
}

static Group* group_for(const ufbx_material* m) {
    int32_t tex = texture_index(material_base_texture(m));
    float col[4] = {0.8f, 0.8f, 0.8f, 1.0f};
    if (tex >= 0) {
        col[0] = col[1] = col[2] = 1.0f; /* the texture carries the colour */
    } else if (m) {
        const ufbx_material_map* map = m->pbr.base_color.has_value ? &m->pbr.base_color : &m->fbx.diffuse_color;
        if (map->has_value && map->value_components >= 3) {
            col[0] = (float)map->value_vec4.x;
            col[1] = (float)map->value_vec4.y;
            col[2] = (float)map->value_vec4.z;
        }
    }
    for (uint32_t i = 0; i < g_group_count; ++i) {
        Group* g = &g_groups[i];
        if (g->texture == tex && (tex >= 0 || memcmp(g->color, col, sizeof(col)) == 0)) return g;
    }
    if (g_group_count >= VKM_MAX_GROUPS) return &g_groups[g_group_count - 1];
    Group* g = &g_groups[g_group_count++];
    memset(g, 0, sizeof(*g));
    g->texture = tex;
    memcpy(g->color, col, sizeof(col));
    return g;
}

static void push_vertex(Group* g, const vkm_vertex* v) {
    if (g->count == g->cap) {
        g->cap = g->cap ? g->cap * 2 : 4096;
        g->verts = (vkm_vertex*)realloc(g->verts, g->cap * sizeof(vkm_vertex));
        if (!g->verts) die("out of memory");
    }
    g->verts[g->count++] = *v;
}

static int8_t snorm8(float f) {
    if (f > 1.0f) f = 1.0f;
    if (f < -1.0f) f = -1.0f;
    return (int8_t)lrintf(f * 127.0f);
}

static void bake_node(const ufbx_node* node) {
    const ufbx_mesh* mesh = node->mesh;
    if (!mesh || node->visible == false) return;
    const ufbx_matrix to_world = node->geometry_to_world;
    const ufbx_matrix normal_m = ufbx_matrix_for_normals(&to_world);
    uint32_t* tri = (uint32_t*)malloc(mesh->max_face_triangles * 3 * sizeof(uint32_t));
    for (size_t p = 0; p < mesh->material_parts.count; ++p) {
        const ufbx_mesh_part* part = &mesh->material_parts.data[p];
        if (part->num_triangles == 0) continue;
        const ufbx_material* mat = NULL;
        if (part->index < node->materials.count) mat = node->materials.data[part->index];
        else if (part->index < mesh->materials.count) mat = mesh->materials.data[part->index];
        Group* g = group_for(mat);
        for (size_t f = 0; f < part->face_indices.count; ++f) {
            const ufbx_face face = mesh->faces.data[part->face_indices.data[f]];
            const uint32_t nt = ufbx_triangulate_face(tri, mesh->max_face_triangles * 3, mesh, face);
            for (uint32_t k = 0; k < nt * 3; ++k) {
                const uint32_t ix = tri[k];
                const ufbx_vec3 pos = ufbx_transform_position(&to_world, ufbx_get_vertex_vec3(&mesh->vertex_position, ix));
                ufbx_vec3 n = {.x = 0, .y = 1, .z = 0};
                if (mesh->vertex_normal.exists) {
                    n = ufbx_transform_direction(&normal_m, ufbx_get_vertex_vec3(&mesh->vertex_normal, ix));
                    const double len = sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
                    if (len > 1e-12) { n.x /= len; n.y /= len; n.z /= len; }
                }
                ufbx_vec2 uv = {.x = 0, .y = 0};
                if (mesh->vertex_uv.exists) uv = ufbx_get_vertex_vec2(&mesh->vertex_uv, ix);
                vkm_vertex v;
                memset(&v, 0, sizeof(v));
                v.pos[0] = (float)pos.x;
                v.pos[1] = (float)pos.y;
                v.pos[2] = (float)pos.z;
                v.normal[0] = snorm8((float)n.x);
                v.normal[1] = snorm8((float)n.y);
                v.normal[2] = snorm8((float)n.z);
                v.uv[0] = (float)uv.x;
                v.uv[1] = 1.0f - (float)uv.y; /* FBX V points up; Vulkan rows go down */
                push_vertex(g, &v);
            }
        }
    }
    free(tri);
}

static void write_pad(FILE* f, size_t written) {
    static const uint8_t zero[4] = {0};
    if (written & 3u) fwrite(zero, 1, 4 - (written & 3u), f);
}

int main(int argc, char** argv) {
    const char* in = NULL;
    const char* out = NULL;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--max-tex") == 0 && i + 1 < argc) g_max_tex = (uint32_t)atoi(argv[++i]);
        else if (!in) in = argv[i];
        else if (!out) out = argv[i];
    }
    if (!in || !out || g_max_tex < 1) die("usage: vk_model_bake model.fbx out.nxvmesh [--max-tex 512]");

    snprintf(g_model_stem, sizeof(g_model_stem), "%s", in);
    char* dot = strrchr(g_model_stem, '.');
    if (dot && dot > base_name(g_model_stem)) *dot = '\0';
    snprintf(g_fbx_dir, sizeof(g_fbx_dir), "%s", in);
    char* name = (char*)base_name(g_fbx_dir);
    if (name > g_fbx_dir) name[-1] = '\0';
    else snprintf(g_fbx_dir, sizeof(g_fbx_dir), ".");

    ufbx_load_opts opts;
    memset(&opts, 0, sizeof(opts));
    opts.target_axes = ufbx_axes_right_handed_y_up;
    opts.target_unit_meters = 1.0f;
    opts.generate_missing_normals = true;
    opts.load_external_files = false;
    ufbx_error err;
    ufbx_scene* scene = ufbx_load_file(in, &opts, &err);
    if (!scene) {
        fprintf(stderr, "vk_model_bake: %s: %s\n", in, err.description.data);
        return 1;
    }

    for (size_t i = 0; i < scene->nodes.count; ++i) bake_node(scene->nodes.data[i]);

    size_t total = 0;
    for (uint32_t i = 0; i < g_group_count; ++i) total += g_groups[i].count;
    if (total == 0 || total % 3 != 0) die("no triangles in the model");

    vkm_vertex* stream = (vkm_vertex*)malloc(total * sizeof(vkm_vertex));
    uint32_t* indices = (uint32_t*)malloc(total * sizeof(uint32_t));
    vkm_group groups[VKM_MAX_GROUPS];
    size_t at = 0;
    uint32_t out_groups = 0;
    for (uint32_t i = 0; i < g_group_count; ++i) {
        if (!g_groups[i].count) continue;
        memcpy(stream + at, g_groups[i].verts, g_groups[i].count * sizeof(vkm_vertex));
        vkm_group* og = &groups[out_groups++];
        memset(og, 0, sizeof(*og));
        og->first_index = (uint32_t)at;
        og->index_count = (uint32_t)g_groups[i].count;
        og->texture = g_groups[i].texture < 0 ? VKM_NO_TEXTURE : (uint32_t)g_groups[i].texture;
        memcpy(og->color, g_groups[i].color, sizeof(og->color));
        at += g_groups[i].count;
        free(g_groups[i].verts);
    }
    ufbx_vertex_stream vs = {.data = stream, .vertex_count = total, .vertex_size = sizeof(vkm_vertex)};
    const size_t vcount = ufbx_generate_indices(&vs, 1, indices, total, NULL, &err);
    if (err.type != UFBX_ERROR_NONE) die("index generation failed");

    vkm_header hdr;
    memset(&hdr, 0, sizeof(hdr));
    memcpy(hdr.magic, VKM_MAGIC, 4);
    hdr.version = VKM_VERSION;
    hdr.vertex_count = (uint32_t)vcount;
    hdr.index_count = (uint32_t)total;
    hdr.group_count = out_groups;
    hdr.bounds_min[0] = hdr.bounds_min[1] = hdr.bounds_min[2] = 1e30f;
    hdr.bounds_max[0] = hdr.bounds_max[1] = hdr.bounds_max[2] = -1e30f;
    for (size_t i = 0; i < vcount; ++i)
        for (int c = 0; c < 3; ++c) {
            if (stream[i].pos[c] < hdr.bounds_min[c]) hdr.bounds_min[c] = stream[i].pos[c];
            if (stream[i].pos[c] > hdr.bounds_max[c]) hdr.bounds_max[c] = stream[i].pos[c];
        }

    /* Only textures that a group uses, renumbered densely. */
    uint32_t remap[VKM_MAX_TEXTURES];
    uint32_t used = 0;
    for (uint32_t t = 0; t < g_tex_count; ++t) remap[t] = VKM_NO_TEXTURE;
    for (uint32_t i = 0; i < out_groups; ++i) {
        const uint32_t t = groups[i].texture;
        if (t == VKM_NO_TEXTURE) continue;
        if (remap[t] == VKM_NO_TEXTURE) remap[t] = used++;
        groups[i].texture = remap[t];
    }
    hdr.texture_count = used;

    FILE* f = fopen(out, "wb");
    if (!f) die("cannot write output");
    fwrite(&hdr, sizeof(hdr), 1, f);
    fwrite(groups, sizeof(vkm_group), out_groups, f);
    size_t tex_bytes = 0;
    for (uint32_t r = 0; r < used; ++r) {
        for (uint32_t t = 0; t < g_tex_count; ++t) {
            if (remap[t] != r) continue;
            vkm_texture th = {.width = g_tex[t].width, .height = g_tex[t].height, .mip_count = g_tex[t].mips, .bytes = (uint32_t)g_tex[t].bytes};
            fwrite(&th, sizeof(th), 1, f);
            fwrite(g_tex[t].rgba, 1, g_tex[t].bytes, f);
            write_pad(f, g_tex[t].bytes);
            tex_bytes += g_tex[t].bytes;
        }
    }
    fwrite(stream, sizeof(vkm_vertex), vcount, f);
    fwrite(indices, sizeof(uint32_t), total, f);
    const long size = ftell(f);
    fclose(f);

    printf("baked %s: %u triangles, %zu vertices, %u draw groups, %u textures (%zu KiB), file %ld KiB\n",
           base_name(in), hdr.index_count / 3u, vcount, out_groups, used, tex_bytes / 1024u, size / 1024L);
    printf("bounds min %.3f %.3f %.3f max %.3f %.3f %.3f\n", hdr.bounds_min[0], hdr.bounds_min[1],
           hdr.bounds_min[2], hdr.bounds_max[0], hdr.bounds_max[1], hdr.bounds_max[2]);
    ufbx_free_scene(scene);
    return 0;
}
