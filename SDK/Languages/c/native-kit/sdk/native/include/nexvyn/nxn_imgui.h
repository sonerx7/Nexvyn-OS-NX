/* Nexvyn Native SDK - Dear ImGui helper: the system font with the glyph ranges of the user's language.
 *
 * ImGui loads only Latin-1 (U+0020..U+00FF) unless it is told more, so Turkish "ı ğ ş İ", Polish, Greek, Cyrillic or
 * Japanese text shows as "?" or as boxes. nxn_imgui_add_font() adds one of the system fonts (nxn_ui_font_get) with the
 * ranges the language of the app needs (nxn_info_string(NXN_INFO_LANGUAGE)), so the atlas stays small:
 *
 *     en de es fr tr pl cs ...  Latin-1 + Latin Extended-A + general punctuation and currency signs
 *     vi                        + Latin Extended-B and Latin Extended Additional
 *     ru uk bg sr               + Cyrillic         el  + Greek
 *     ja ko zh                  + the characters of the app's own texts (or a compact common set), taken from the
 *                               system's CJK font (NXN_UI_FONT_CJK, see below); Latin text keeps working without it
 * NXN_IMGUI_ALL_SCRIPTS (flag) adds Latin Extended-B, Greek and Cyrillic whatever the language is: use it when the app
 * shows text it did not translate itself (file names, user content).
 *
 * Header only. Include "imgui.h" and <nexvyn/nexvyn_native.h> first. Call it before the first frame (the atlas is built
 * by the renderer backend). The ranges live in static storage, as ImGui requires.
 *
 *     ImFont* body = nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 16.f, 0, icon_ranges);   // icon_ranges may be NULL
 *
 * `icon_ranges` (optional): zero-terminated pairs of code points in the system icon font; they are merged into the
 * same ImFont (draw them with nxn_ui_icon_code). Returns NULL when the system has no such font: ImGui's default font is
 * added instead, so the result is always usable.
 *
 * CJK (Native 1.1, NXN_CAP_UI_FONT_CJK): nxn_ui_font_get(NXN_UI_FONT_CJK) is the console's or the SD card's Han / Kana /
 * Hangul font in the regional shape of the app's language. For ja, ko and zh this header merges it behind the font
 * with no change in the app. The atlas holds only what the app needs: kana (or Hangul jamo), CJK punctuation, full-width
 * forms and every character of the package's lang/<code>.json (NXN_DIR_BUNDLE), plus the strings given to
 * nxn_imgui_add_text() before the first nxn_imgui_add_font() (generated text, names). Text the app did not write (file
 * names, chat, web pages) needs NXN_IMGUI_CJK_COMMON: the common characters of the script instead (ImGui's Japanese and
 * Simplified Chinese tables, the 2350 syllables of KS X 1001), about 3000 glyphs per font, roughly 1 MB of atlas per
 * 20 px of size and font: keep it to the 2-3 text fonts. A font above 30 px, or one passed NXN_IMGUI_NO_CJK (digits,
 * monospace), gets no CJK glyphs (NXN_IMGUI_CJK_LARGE overrides the size rule). A system without the font (an older
 * Nexvyn OS, none installed) draws Latin and the app's symbols only; nothing fails. A character outside the set shows
 * as "?". */
#ifndef NEXVYN_NXN_IMGUI_H
#define NEXVYN_NXN_IMGUI_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    NXN_IMGUI_ALL_SCRIPTS = 1u << 0,
    NXN_IMGUI_NO_CJK = 1u << 1,     /* never merge the CJK font into this font (numbers, monospace, big headings) */
    NXN_IMGUI_CJK_LARGE = 1u << 2,  /* merge it even above 30 px */
    NXN_IMGUI_CJK_COMMON = 1u << 3  /* ja / ko / zh: the common characters of the script, not only the app's own texts */
};

/* Gamepad / Joy-Con navigation. ImGui moves focus with the pad only when the app asks for it (NavEnableGamepad) AND the
 * backend says it can deliver a pad (HasGamepad); the OpenGL3 backend never sets the second flag, so call this once after
 * ImGui::CreateContext() (nxn_imgui_add_font() calls it too). Feed the pad with io.AddKeyEvent(ImGuiKey_Gamepad...). */
static inline void nxn_imgui_enable_gamepad(ImGuiIO& io) {
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;
    io.BackendFlags |= ImGuiBackendFlags_HasGamepad;
}

/* The language group of nxn_info_string(NXN_INFO_LANGUAGE) ("pt-BR" -> "pt"): 2 letters, lower case. */
static inline void nxn_imgui_language(char out[3]) {
    const char* l = nxn_info_string(NXN_INFO_LANGUAGE);
    out[0] = l && l[0] ? (char)(l[0] | 0x20) : 'e';
    out[1] = l && l[0] && l[1] ? (char)(l[1] | 0x20) : 'n';
    out[2] = 0;
}

/* Zero-terminated pairs of code points for the app's language (static storage, valid for the whole run). */
static inline const ImWchar* nxn_imgui_ranges(unsigned flags) {
    static ImWchar store[2][24];  // one table per flag value: ImGui reads them when it builds the atlas, not when they are passed
    static bool built[2];
    ImWchar* r = store[flags & 1u];
    if (built[flags & 1u]) return r;
    char lang[3];
    nxn_imgui_language(lang);
    int n = 0;
    auto add = [&](unsigned lo, unsigned hi) { r[n++] = (ImWchar)lo, r[n++] = (ImWchar)hi; };
    auto is = [&](const char* l) { return lang[0] == l[0] && lang[1] == l[1]; };
    bool all = (flags & NXN_IMGUI_ALL_SCRIPTS) != 0;
    add(0x0020, 0x00FF);  // Latin-1
    add(0x0100, 0x017F);  // Latin Extended-A: tr (ı ğ ş İ), pl, cs, hu, ro, ...
    add(0x2000, 0x206F);  // general punctuation: dashes, quotes, ellipsis
    add(0x20A0, 0x20BF);  // currency signs (euro, lira, ...)
    add(0x2190, 0x21FF);  // arrows
    if (all || is("vi")) add(0x0180, 0x024F), add(0x1EA0, 0x1EF9);                     // Latin Extended-B + Vietnamese
    if (all || is("el")) add(0x0370, 0x03FF);                                            // Greek
    if (all || is("ru") || is("uk") || is("bg") || is("sr")) add(0x0400, 0x052F);       // Cyrillic
    r[n] = 0;
    built[flags & 1u] = true;
    return r;
}

/* The 2350 Hangul syllables of KS X 1001 (the everyday ones), as distances from the previous one, starting at U+AC00. */
static const unsigned char nxn_imgui_ko_delta[2349] = {
    1, 3, 3, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 11, 2, 7, 4, 4, 20, 1,
    3, 3, 1, 2, 6, 1, 2, 1, 1, 1, 3, 1, 1, 1, 4, 4, 8, 1, 2, 1, 1, 7, 1, 1, 2, 3, 1, 8, 1, 2, 1, 1, 4, 3, 4, 4, 9,
    2, 9, 1, 3, 3, 1, 2, 2, 3, 1, 1, 2, 2, 1, 6, 1, 3, 4, 2, 6, 1, 2, 2, 7, 4, 4, 9, 3, 1, 7, 1, 3, 4, 8, 1, 2, 2,
    7, 4, 4, 9, 2, 9, 1, 3, 3, 1, 1, 1, 5, 1, 1, 2, 2, 1, 6, 1, 3, 4, 12, 1, 7, 19, 9, 1, 3, 4, 8, 1, 2, 9, 4, 4,
    20, 1, 3, 3, 1, 1, 7, 1, 2, 2, 7, 28, 1, 3, 3, 1, 2, 6, 1, 2, 2, 1, 4, 2, 1, 1, 2, 4, 2, 6, 1, 2, 1, 1, 4, 3, 1,
    3, 4, 8, 1, 2, 1, 1, 7, 1, 7, 48, 1, 1, 2, 4, 8, 1, 2, 1, 1, 7, 1, 3, 12, 3, 2, 7, 4, 4, 11, 1, 5, 3, 28, 1, 3,
    2, 2, 8, 1, 2, 2, 1, 1, 5, 1, 7, 12, 1, 7, 1, 20, 7, 4, 4, 8, 1, 4, 7, 28, 1, 3, 4, 7, 1, 1, 2, 2, 1, 6, 8, 12,
    1, 7, 1, 3, 4, 8, 1, 3, 8, 4, 4, 8, 1, 11, 28, 1, 3, 2, 2, 2, 5, 1, 1, 2, 2, 4, 31, 1, 3, 4, 8, 1, 2, 2, 7, 1,
    1, 2, 3, 1, 1, 1, 6, 1, 2, 1, 1, 1, 1, 2, 2, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8, 5, 35, 1, 2, 1, 4, 2, 1,
    5, 1, 2, 1, 1, 6, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 3, 1, 3, 4, 4, 24, 1, 3, 4, 2, 6, 1, 2, 2, 5, 1,
    1, 4, 4, 12, 36, 4, 4, 8, 1, 2, 9, 1, 3, 4, 9, 2, 2, 7, 1, 3, 3, 1, 8, 1, 2, 2, 7, 20, 8, 28, 4, 4, 8, 1, 11, 1,
    7, 8, 1, 4, 7, 1, 3, 4, 1, 1, 6, 1, 2, 2, 1, 4, 2, 4, 4, 20, 1, 3, 4, 2, 6, 1, 2, 2, 5, 2, 1, 1, 2, 3, 1, 1, 1,
    1, 4, 1, 1, 2, 1, 1, 1, 1, 4, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 56, 1, 1, 2, 3, 1, 2, 1, 5, 1, 2, 2, 2, 3, 2, 1, 3,
    4, 8, 1, 2, 1, 1, 7, 4, 4, 12, 1, 7, 4, 24, 1, 3, 3, 1, 2, 2, 4, 1, 2, 2, 2, 2, 3, 4, 4, 20, 20, 8, 4, 4, 8, 1,
    2, 9, 28, 1, 3, 4, 8, 1, 2, 2, 7, 20, 8, 21, 7, 4, 4, 9, 2, 2, 7, 4, 4, 8, 5, 7, 1, 3, 3, 1, 2, 6, 1, 2, 2, 7,
    28, 1, 3, 3, 1, 8, 1, 2, 1, 1, 1, 6, 1, 3, 4, 8, 1, 2, 1, 1, 6, 1, 1, 3, 4, 8, 1, 2, 1, 1, 63, 1, 3, 4, 2, 1, 5,
    1, 2, 1, 1, 6, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 20, 36, 1, 3, 4, 13, 7, 8, 20, 28, 4, 52, 1, 3, 4, 7, 1, 5, 35, 28,
    4, 4, 8, 1, 4, 35, 1, 3, 3, 1, 8, 1, 2, 9, 4, 4, 8, 1, 11, 4, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 1, 1, 1, 4, 1,
    1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 15, 2, 35, 1, 3, 4, 8, 1, 2, 1, 1, 6, 1, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8,
    1, 2, 1, 1, 7, 4, 13, 2, 9, 1, 3, 4, 8, 1, 2, 2, 7, 4, 17, 27, 8, 4, 4, 8, 1, 2, 2, 7, 4, 4, 9, 2, 2, 7, 1, 3,
    4, 8, 1, 2, 2, 7, 20, 8, 28, 1, 3, 4, 8, 3, 2, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 2, 1, 3, 1, 30, 1,
    3, 4, 8, 1, 2, 2, 7, 1, 3, 2, 1, 1, 1, 1, 6, 1, 2, 2, 1, 3, 2, 1, 1, 3, 4, 8, 1, 2, 1, 1, 1, 6, 1, 7, 13, 35, 1,
    3, 4, 2, 6, 1, 2, 2, 1, 5, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 11, 1, 1, 2, 5, 28, 1, 2, 1, 4, 2, 6, 1, 2, 2,
    7, 4, 16, 1, 35, 4, 4, 9, 2, 2, 7, 4, 4, 9, 2, 9, 1, 1, 2, 3, 1, 1, 1, 6, 1, 2, 2, 4, 2, 1, 4, 4, 9, 2, 9, 28,
    4, 4, 20, 4, 4, 8, 3, 9, 4, 4, 8, 3, 37, 1, 3, 3, 1, 2, 6, 1, 2, 1, 1, 2, 2, 3, 1, 1, 1, 1, 3, 1, 1, 1, 1, 5, 1,
    2, 2, 4, 3, 1, 3, 4, 8, 1, 2, 1, 1, 4, 3, 1, 3, 13, 39, 1, 3, 3, 1, 2, 6, 1, 2, 2, 1, 6, 1, 3, 3, 1, 8, 1, 2, 1,
    1, 7, 1, 3, 4, 9, 2, 1, 1, 4, 3, 4, 24, 1, 1, 2, 4, 8, 1, 2, 2, 7, 4, 16, 8, 20, 8, 1, 3, 4, 8, 1, 11, 4, 24, 1,
    3, 3, 1, 1, 1, 6, 1, 2, 2, 4, 1, 2, 8, 12, 8, 28, 1, 3, 4, 13, 7, 4, 4, 8, 3, 2, 7, 1, 3, 4, 8, 1, 2, 37, 1, 3,
    4, 2, 6, 1, 2, 2, 1, 1, 5, 1, 3, 4, 2, 6, 1, 2, 1, 1, 6, 1, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 15, 40, 1, 3, 3, 1, 8,
    3, 1, 1, 7, 21, 7, 1, 15, 1, 2, 1, 1, 35, 1, 3, 4, 8, 1, 4, 63, 28, 21, 7, 1, 3, 4, 8, 3, 2, 91, 21, 7, 4, 4, 8,
    1, 39, 1, 3, 4, 8, 1, 2, 2, 7, 1, 2, 1, 3, 1, 1, 1, 6, 1, 2, 1, 1, 4, 3, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8,
    1, 2, 2, 7, 4, 4, 8, 5, 7, 1, 1, 1, 1, 3, 1, 2, 1, 5, 1, 2, 1, 1, 5, 2, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8,
    1, 2, 1, 1, 7, 4, 4, 13, 7, 1, 1, 2, 4, 2, 6, 1, 2, 2, 4, 3, 1, 3, 4, 13, 7, 4, 4, 8, 3, 1, 8, 4, 4, 8, 1, 2, 9,
    1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 3, 1, 8, 1, 2, 2, 2, 2, 1, 2, 20, 8, 1, 3, 4, 8, 5, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1,
    7, 8, 3, 2, 7, 1, 3, 4, 1, 7, 1, 2, 2, 35, 1, 3, 3, 1, 7, 1, 1, 2, 2, 5, 2, 1, 2, 1, 4, 8, 1, 3, 1, 6, 1, 1, 3,
    4, 8, 1, 3, 1, 28, 35, 1, 3, 4, 2, 6, 1, 3, 1, 7, 4, 4, 52, 24, 1, 3, 3, 1, 2, 6, 1, 4, 7, 1, 3, 16, 8, 20, 8,
    4, 4, 8, 1, 11, 28, 1, 3, 4, 8, 1, 4, 7, 20, 8, 28, 4, 45, 7, 1, 3, 4, 2, 5, 1, 1, 11, 4, 4, 8, 12, 1, 3, 4, 8,
    1, 2, 2, 7, 1, 3, 1, 1, 2, 1, 1, 5, 1, 1, 2, 1, 1, 4, 1, 2, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 3, 5, 1, 2, 2,
    4, 2, 1, 4, 4, 9, 11, 1, 3, 1, 2, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 3, 4, 8, 1, 2, 2, 7, 1, 1, 2, 4, 2,
    1, 5, 1, 1, 1, 1, 1, 4, 1, 1, 1, 4, 4, 8, 1, 2, 1, 8, 1, 3, 4, 1, 1, 2, 3, 1, 1, 2, 2, 2, 5, 1, 3, 4, 8, 1, 2,
    1, 1, 7, 1, 3, 12, 3, 2, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 1, 1, 6, 1, 2, 2, 7, 1, 3,
    4, 8, 1, 3, 1, 7, 1, 3, 4, 8, 1, 4, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 2, 2, 5, 1, 3, 4, 6, 2, 1, 2,
    2, 1, 1, 1, 1, 1, 1, 1, 4, 4, 8, 3, 9, 1, 3, 4, 1, 1, 5, 1, 1, 2, 1, 1, 1, 4, 2, 1, 3, 2, 1, 1, 2, 6, 1, 2, 1,
    1, 1, 6, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 2, 2, 8, 5, 7, 4, 4, 20, 1, 3, 4, 2, 6, 1, 2, 2, 1, 6, 1, 3, 4, 8, 1,
    2, 2, 7, 4, 4, 8, 1, 3, 1, 7, 28, 1, 3, 4, 2, 6, 1, 2, 2, 1, 1, 4, 1, 1, 7, 9, 2, 2, 7, 20, 1, 7, 4, 4, 8, 1, 2,
    2, 7, 1, 3, 17, 7, 1, 3, 4, 1, 1, 6, 1, 2, 2, 7, 20, 8, 28, 1, 3, 4, 8, 1, 2, 9, 4, 4, 8, 12, 1, 3, 4, 8, 1, 2,
    2, 35, 1, 3, 3, 1, 2, 6, 1, 2, 2, 1, 3, 1, 2, 1, 3, 2, 2, 3, 5, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 2, 1, 1, 7, 4, 17,
    35, 1, 3, 4, 8, 1, 2, 1, 1, 7, 21, 7, 20, 36, 1, 3, 4, 8, 1, 2, 2, 2, 5, 1, 7, 12, 8, 20, 8, 4, 4, 8, 1, 32, 7,
    1, 3, 4, 8, 1, 4, 7, 20, 1, 35, 28, 28, 16, 3, 2, 35, 1, 3, 4, 8, 1, 4, 1, 5, 1, 1, 3, 2, 2, 8, 1, 2, 1, 1, 1,
    6, 1, 3, 4, 8, 1, 2, 1, 1, 7, 4, 2, 2, 8, 5, 35, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 16, 8, 4,
    17, 7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 4, 13, 35, 4, 4, 8, 1, 2, 2, 7, 16, 12, 1, 3, 4, 8, 1, 2, 2, 7, 20, 8, 4, 24,
    4, 4, 8, 1, 2, 2, 7, 4, 4, 8, 5, 7, 1, 3, 4, 8, 1, 2, 2, 35, 1, 3, 3, 1, 1, 7, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 2,
    7, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 20, 35, 1, 3, 3, 1, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 4, 8, 1, 2, 1,
    1, 7, 28, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 5, 7, 21, 7, 8, 20, 28, 1, 3, 4, 8, 1, 2, 2, 7, 4, 4, 13, 7, 21,
    7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 4, 8, 12, 1, 3, 4, 8, 1, 4, 35, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 1, 7, 1, 2, 1, 1,
    7, 1, 3, 4, 8, 1, 2, 1, 1, 7, 21, 35, 1, 3, 4, 2, 6, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 16, 8, 4, 24, 1,
    3, 4, 8, 1, 2, 2, 5, 2, 4, 24, 28, 4, 15, 2, 7, 28, 1, 3, 4, 8, 1, 2, 2, 7, 20, 8, 28, 1, 3, 4, 8, 1, 4, 7, 4,
    4, 8, 5, 7, 1, 3, 3, 1, 2, 6, 1, 2, 9, 4, 4, 8, 1, 11, 1, 3, 4, 8, 1, 2, 2, 7, 1, 1, 2, 4, 2, 6, 1, 2, 1, 1, 4,
    3, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 55, 1, 3, 4, 8, 1, 2, 1, 1, 7, 1, 3, 4, 8, 1, 2, 2, 7, 4, 4, 8, 1, 3, 1, 7, 8,
    9, 2, 9, 1, 3, 4, 8, 1, 2, 2, 7, 21, 35, 4, 24, 4, 4, 9, 2, 9, 1, 3, 3, 1, 2, 6, 1, 2, 2, 7, 21, 35, 4, 4, 8, 3,
    9, 4, 4, 8, 3, 2, 7, 4, 4, 8, 1, 2, 37, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 5, 3, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 1,
    1, 7, 21, 35, 1, 3, 4, 2, 6, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 1, 2, 1, 1, 7, 4, 4, 9, 11, 1, 3,
    4, 5, 3, 1, 2, 2, 4, 3, 1, 3, 4, 11, 2, 7, 1, 3, 15, 2, 7, 1, 3, 4, 9, 2, 2, 7, 4, 4, 9, 2, 9, 1, 3, 4, 5, 3, 3,
    2, 7, 4, 4, 8, 5, 7, 1, 3, 4, 13, 7, 1, 3, 4, 8, 1, 2, 2, 7, 1, 3, 4, 8, 3, 2, 7, 1, 3, 2, 1, 1, 1, 7, 1, 2, 2,
    4, 3, 4, 4, 8, 1, 4, 7, 1, 3, 4, 8, 1, 2, 2
};

/* Characters the app adds for its CJK fonts (see the header comment): call before the first nxn_imgui_add_font(). */
static inline ImFontGlyphRangesBuilder& nxn_imgui_text_builder() {
    static ImFontGlyphRangesBuilder b;
    return b;
}
static inline unsigned& nxn_imgui_text_generation() {
    static unsigned g = 0;
    return g;
}
static inline void nxn_imgui_add_text(const char* utf8) {
    if (utf8 && *utf8) nxn_imgui_text_builder().AddText(utf8), nxn_imgui_text_generation()++;
}

/* Every character of <bundle>/lang/<code>.json (the app's own texts; language "pt-BR" tries "pt-BR", then "pt"). */
static inline void nxn_imgui_add_lang_text(const char* lang) {
    char rel[40];
    for (int pass = 0; pass < 2 && lang && lang[0]; pass++) {
        char code[16];
        size_t n = 0;
        while (lang[n] && n < sizeof code - 1 && !(pass && (lang[n] == '-' || lang[n] == '_'))) code[n] = lang[n], n++;
        code[n] = 0;
        snprintf(rel, sizeof rel, "lang/%s.json", code);
        const size_t cap = 256 * 1024;
        char* buf = (char*)malloc(cap);
        size_t got = 0;
        bool ok = buf && nxn_fs_read(NXN_DIR_BUNDLE, rel, buf, cap - 1, &got) == NXN_OK && got > 0;
        if (ok) {
            buf[got] = 0;
            nxn_imgui_add_text(buf);
        }
        free(buf);
        if (ok) return;
    }
}

/* Glyph ranges of the CJK scripts for merging. NULL for other languages. Default: kana (Hangul jamo), CJK punctuation,
 * full-width forms and the characters of the app's texts when its lang file is readable; else (or with
 * NXN_IMGUI_CJK_COMMON) the common characters of the script: ImGui's Japanese / Simplified Chinese tables, KS X 1001. */
static inline const ImWchar* nxn_imgui_cjk_ranges(ImFontAtlas* atlas, const char lang[3], unsigned flags) {
    bool ja = lang[0] == 'j' && lang[1] == 'a', zh = lang[0] == 'z' && lang[1] == 'h', ko = lang[0] == 'k' && lang[1] == 'o';
    if (!ja && !zh && !ko) return NULL;
    static bool lang_read;
    if (!lang_read) {
        lang_read = true;
        nxn_imgui_add_lang_text(nxn_info_string(NXN_INFO_LANGUAGE));
    }
    bool own = nxn_imgui_text_generation() > 0 && !(flags & NXN_IMGUI_CJK_COMMON);
    static ImVector<ImWchar>* ranges[2];
    static unsigned built_gen[2] = {~0u, ~0u};
    int slot = own ? 1 : 0;
    if (built_gen[slot] != nxn_imgui_text_generation() || !ranges[slot]) {
        built_gen[slot] = nxn_imgui_text_generation();
        ranges[slot] = IM_NEW(ImVector<ImWchar>)();  // kept for the run: ImGui reads the ranges when it builds the atlas
        ImFontGlyphRangesBuilder b;
        static const ImWchar base[] = {0x3000, 0x30FF, 0x3131, 0x3163, 0xFF00, 0xFFEF, 0};
        b.AddRanges(base);
        if (own) {
            ImFontGlyphRangesBuilder& t = nxn_imgui_text_builder();
            for (int i = 0x3100; i < 0xFF00; i++)  // the app's Han / Hangul (kana, punctuation and full-width forms are in `base`)
                if (t.GetBit((size_t)i)) b.AddChar((ImWchar)i);
        } else if (ja) {
            b.AddRanges(atlas->GetGlyphRangesJapanese());
        } else if (zh) {
            b.AddRanges(atlas->GetGlyphRangesChineseSimplifiedCommon());
        } else {
            unsigned c = 0xAC00;
            b.AddChar((ImWchar)c);
            for (unsigned i = 0; i < sizeof nxn_imgui_ko_delta; i++) b.AddChar((ImWchar)(c += nxn_imgui_ko_delta[i]));
        }
        b.BuildRanges(ranges[slot]);
    }
    return ranges[slot]->Data;
}

static inline ImFont* nxn_imgui_add_font(ImFontAtlas* atlas, nxn_ui_font font, float px, unsigned flags,
                                         const ImWchar* icon_ranges) {
    if (ImGui::GetCurrentContext()) nxn_imgui_enable_gamepad(ImGui::GetIO());
    const void* data = NULL;
    size_t size = 0;
    if (nxn_ui_font_get(font, &data, &size) != NXN_OK) {
        ImFontConfig dc;
        dc.SizePixels = px;
        return atlas->AddFontDefault(&dc);
    }
    ImFontConfig fc;
    fc.FontDataOwnedByAtlas = false;  // the system keeps the font bytes until the app ends
    ImFont* f = atlas->AddFontFromMemoryTTF((void*)data, (int)size, px, &fc, nxn_imgui_ranges(flags));
    if (font != NXN_UI_FONT_ICONS && !(flags & NXN_IMGUI_NO_CJK) && (px <= 30.f || (flags & NXN_IMGUI_CJK_LARGE))) {
        char lang[3];
        nxn_imgui_language(lang);
        const ImWchar* cjk = nxn_imgui_cjk_ranges(atlas, lang, flags);
        const void* cd = NULL;
        size_t cs = 0;
        if (cjk && nxn_ui_font_get(NXN_UI_FONT_CJK, &cd, &cs) == NXN_OK) {
            ImFontConfig mc;
            mc.FontDataOwnedByAtlas = false;  // the system keeps the font bytes until the app ends
            mc.MergeMode = true;
            atlas->AddFontFromMemoryTTF((void*)cd, (int)cs, px, &mc, cjk);
        }
    }
    if (icon_ranges && icon_ranges[0]) {
        const void* id = NULL;
        size_t is = 0;
        if (nxn_ui_font_get(NXN_UI_FONT_ICONS, &id, &is) == NXN_OK) {
            ImFontConfig mc;
            mc.FontDataOwnedByAtlas = false;
            mc.MergeMode = true;
            mc.GlyphMinAdvanceX = px;
            mc.GlyphOffset = ImVec2(0, px * 0.12f);
            atlas->AddFontFromMemoryTTF((void*)id, (int)is, px * 1.1f, &mc, icon_ranges);
        }
    }
    return f;
}

#endif /* NEXVYN_NXN_IMGUI_H */
