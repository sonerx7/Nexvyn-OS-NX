/* Nexvyn Native SDK - Nexvyn OS look (UI tokens, system font, icon names) and the app's own translated texts.
 *
 * For apps that should look like part of Nexvyn OS (tools, settings, editors, emulator front ends). A GAME does not use
 * this: games build their own look (font, layout, shader, sound) and never copy the OS menu. The values come from the
 * same source the OS's own widgets use; they are not copies, so the app follows the OS when the user switches between
 * light and dark, changes the accent colour or turns on high contrast.
 *
 *     nxn_ui_tokens t = NXN_STRUCT_INIT(nxn_ui_tokens);
 *     if (nxn_ui_tokens_get(&t) == NXN_OK) { clear to t.window_bg; draw buttons with t.accent / t.corner_radius; }
 *
 * Tokens are read at start and again when NXN_EVENT_THEME arrives (apps with "minNative" 1.1; older apps never get the
 * event but can compare nxn_ui_tokens.revision once per frame). Check nxn_caps.features for NXN_CAP_UI_TOKENS and
 * NXN_CAP_TEXT. Everything here is add-only like the rest of the ABI. */
#ifndef NEXVYN_NXN_UI_H
#define NEXVYN_NXN_UI_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* Colours are 0xAARRGGBB. Sizes are in pixels of the app's own surface at its 1.0 scale (the OS's UI points). */
typedef struct nxn_ui_tokens {
    uint32_t size;
    uint32_t dark;            /* 1 dark appearance, 0 light */
    uint32_t revision;        /* grows by one each time a value changes (theme, accent, accessibility) */
    uint32_t high_contrast;   /* 1: Settings > Accessibility > Increase Contrast is on (tokens already follow it) */
    /* colours */
    uint32_t accent, accent_hover, accent_text;       /* accent_text: text drawn on the accent */
    uint32_t window_bg, content_bg, sidebar_bg;       /* window chrome, document area, side panel */
    uint32_t surface, surface_hover, surface_pressed; /* control background (buttons) and its states */
    uint32_t text, text_secondary, text_tertiary;
    uint32_t separator, border;                       /* border: control outline */
    uint32_t field_bg, field_border;
    uint32_t selection, selection_text, hover;        /* selected row, text on it, row hover tint */
    uint32_t error, warning, success, info;           /* red, orange, green, blue of the system palette */
    /* sizes */
    float corner_radius;      /* buttons and controls */
    float corner_radius_field;
    float corner_radius_row;
    float spacing[6];         /* 4, 8, 12, 16, 24, 32: the OS's spacing steps */
    float control_height;     /* recommended button / field height */
    float row_height;         /* recommended list row height */
    float font_small, font_body, font_large, font_title; /* recommended text sizes (before the user's text-size scale) */
    float text_scale;         /* Settings > Accessibility text size (0.85 .. 1.3); multiply the font sizes by it */
    uint32_t bold_text;       /* 1: the user wants bold text */
} nxn_ui_tokens;

/* Fills min(out->size, sizeof(nxn_ui_tokens)) bytes from a snapshot the system refreshes when the look changes.
 * Thread: any app thread. Memory: written into the caller's struct. */
NXN_API nxn_result nxn_ui_tokens_get(nxn_ui_tokens* out);

typedef enum nxn_ui_font {
    NXN_UI_FONT_SANS = 0,
    NXN_UI_FONT_MEDIUM = 1,
    NXN_UI_FONT_SEMIBOLD = 2,
    NXN_UI_FONT_BOLD = 3,
    NXN_UI_FONT_MONO = 5,
    NXN_UI_FONT_MONO_BOLD = 6,
    NXN_UI_FONT_ICONS = 7,  /* the system icon font: draw nxn_ui_icon_code(name) with it */
    NXN_UI_FONT_CJK = 8     /* Native 1.1 (NXN_CAP_UI_FONT_CJK): Han, kana and Hangul for the app's language (ja, ko, zh: its
                               regional shapes), a stand-alone font file (a collection's face is already cut out, use it as
                               face 0); NXN_ERR_NOT_FOUND when the console has no CJK font and none is installed on the SD
                               card (Fonts app / App Market font pack). It holds only those scripts and Latin: merge it
                               behind NXN_UI_FONT_SANS (nxn_imgui_add_font does). Large (several MB): load it only when
                               the language needs it. */
} nxn_ui_font;

/* The font file's bytes (TrueType / OpenType), for ImGui AddFontFromMemoryTTF (set FontDataOwnedByAtlas = false) or
 * any text renderer. NXN_ERR_NOT_FOUND for an id the system does not have.
 * Thread: any app thread. Memory: the data is owned by the system, read-only, valid until the app ends; never freed. */
NXN_API nxn_result nxn_ui_font_get(nxn_ui_font font, const void** data, size_t* size);

/* Unicode code point of a system icon ("folder", "wifi", "settings"...: the Material Icons names) in the
 * NXN_UI_FONT_ICONS font; 0 when the name is unknown. Thread: any app thread. Memory: none. */
NXN_API uint32_t nxn_ui_icon_code(const char* name);

/* ---------------------------------------------------------------- the app's own texts (lang/<code>.json)
 * The package's lang/<code>.json files hold the app's texts: {"title": "Counter", "times": "Clicked {0} times"}. Nested
 * objects are joined with dots ("menu.open"), the same rule and the same fallback as TR() of the script SDK: the system
 * language, its base language ("pt-BR" -> "pt"), English, then the key itself (a missing text is visible but harmless).
 * The language is the one the app started with (nxn_info_string(NXN_INFO_LANGUAGE)). lang/en.json is the one required
 * file. Text of the system's own strings (TR("common.ok")) is not available here: ship the words the app uses. */

/* Never NULL, never an empty "key not found" crash: the translated text, or `key` itself. The pointer lives until the app
 * ends. Thread: any app thread. Memory: owned by the system, read-only, never freed by the caller. */
NXN_API const char* nxn_tr(const char* key);

/* Translated text with {0}, {1}... replaced by args[0], args[1]... (a placeholder without an argument is dropped).
 * NXN_ERR_TOO_SMALL when `out` cannot hold the result and its NUL (nothing is truncated silently).
 * Thread: any app thread. Memory: written into the caller's buffer; args are only read during the call. */
NXN_API nxn_result nxn_tr_format(const char* key, char* out, size_t cap, const char* const* args, uint32_t argc);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_UI_H */
