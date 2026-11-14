/* Nexvyn Native SDK N2 - Apple-Grade NXUI Retained & Semantic UI Library.
 * Provides unified design tokens, responsive containers, buttons, cards, typography,
 * hardware clipping, visible gamepad focus rings, and touch coordinate adapters.
 */
#ifndef NEXVYN_NXN_NXUI_H
#define NEXVYN_NXN_NXUI_H

#include "nxn_base.h"
#include <stdbool.h>
#include <stdint.h>

NXN_EXTERN_C_BEGIN

/* NXUI Tokens (Bölüm 5.2, 5.9) */
typedef struct nxn_nxui_tokens {
    uint32_t size;
    float space1;   /* 4 pt */
    float space2;   /* 8 pt */
    float space3;   /* 12 pt */
    float space4;   /* 16 pt */
    float space6;   /* 24 pt */
    float space8;   /* 32 pt */

    float radius_small;    /* 8 pt */
    float radius_medium;   /* 12 pt */
    float radius_large;    /* 16 pt */
    float radius_capsule;  /* 999 pt */

    float control_compact; /* 36 pt */
    float control_regular; /* 44 pt */
    float control_large;   /* 52 pt */

    float font_large_title; /* 28 pt */
    float font_title;       /* 22 pt */
    float font_headline;    /* 17 pt */
    float font_body;        /* 15 pt */
    float font_caption;     /* 12 pt */

    uint32_t accent;
    uint32_t window_bg;
    uint32_t surface;
    uint32_t text;
    uint32_t text_secondary;
    uint32_t border;
    uint32_t focus_ring;
    uint32_t error;
    uint32_t success;
} nxn_nxui_tokens;

/* Fetches active NXUI design tokens */
NXN_API nxn_result nxn_nxui_tokens_get(nxn_nxui_tokens* out);

typedef enum nxn_nxui_typo {
    NXN_TYPO_LARGE_TITLE = 0,
    NXN_TYPO_TITLE = 1,
    NXN_TYPO_HEADLINE = 2,
    NXN_TYPO_BODY = 3,
    NXN_TYPO_CAPTION = 4
} nxn_nxui_typo;

typedef enum nxn_nxui_btn_variant {
    NXN_BTN_DEFAULT = 0,
    NXN_BTN_PRIMARY = 1,
    NXN_BTN_DESTRUCTIVE = 2,
    NXN_BTN_PLAIN = 3
} nxn_nxui_btn_variant;

/* Declarative NXUI Frame Lifecycle (Per-Window Retained State) */
NXN_API void nxn_nxui_begin(float width, float height);
NXN_API void nxn_nxui_end(void);
NXN_API void nxn_nxui_release_window(int window_id);

/* Semantic Container Layouts */
NXN_API void nxn_nxui_row_begin(const char* id, float gap);
NXN_API void nxn_nxui_row_end(void);

NXN_API void nxn_nxui_column_begin(const char* id, float gap);
NXN_API void nxn_nxui_column_end(void);

NXN_API void nxn_nxui_card_begin(const char* id);
NXN_API void nxn_nxui_card_end(void);

NXN_API void nxn_nxui_scroll_begin(const char* id, float width, float height, float* scroll_y);
NXN_API void nxn_nxui_scroll_end(void);

NXN_API void nxn_nxui_canvas_begin(const char* id, float width, float height);
NXN_API void nxn_nxui_canvas_end(void);

/* Core Controls */
NXN_API bool nxn_nxui_button(const char* id, const char* label, nxn_nxui_btn_variant variant);
NXN_API void nxn_nxui_label(const char* id, const char* text, nxn_nxui_typo typo);
NXN_API void nxn_nxui_badge(const char* id, const char* text, uint32_t rgba_color);
NXN_API bool nxn_nxui_toggle(const char* id, bool* checked);
NXN_API void nxn_nxui_spacer(float size);

/* Standard Widgets (N2 Faz 3 & A3-03 Full Parity) */
NXN_API bool nxn_nxui_tabs(const char* id, const char** options, int count, int* selected_index);
NXN_API bool nxn_nxui_slider(const char* id, float* value, float min, float max);
NXN_API bool nxn_nxui_textfield(const char* id, char* buf, size_t buf_size, const char* placeholder);
NXN_API bool nxn_nxui_dropdown(const char* id, const char** options, int count, int* selected_index);
NXN_API bool nxn_nxui_dialog(const char* id, const char* title, const char* message, const char* confirm_label, const char* cancel_label);
NXN_API bool nxn_nxui_table(const char* id, const char** columns, int col_count, const char*** rows, int row_count, int* selected_row);
NXN_API bool nxn_nxui_virtuallist(const char* id, const char** items, int count, float row_height, float view_height, int* selected_row);

/* Gamepad / D-pad Navigation & Pointer Injection Bridge */
NXN_API bool nxn_nxui_move_focus(int direction); /* 0: Up, 1: Down, 2: Left, 3: Right */
NXN_API bool nxn_nxui_activate_focused(void);
NXN_API bool nxn_nxui_feed_pointer(float x, float y, bool down, bool pressed, bool released);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_NXUI_H */
