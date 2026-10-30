/* Tip Splitter: the tip, the total and each person's share of a bill, in plain C.
 * Shows: ui_textfield editing a char buffer in place ("numeric" flag), strtod with a decimal comma, ui_segmented,
 * ui_slider, ui_toggle, ui_iconButton, ui_group / ui_separator rows, store_* for the last values, sys_share. */
#include <nexvyn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const int PRESETS[] = {0, 10, 15, 18, 20, 25};
#define NPRESETS 6

static char bill[24];
static float tip = 15;       /* percent */
static int people = 2;
static bool roundUp;

static double amount(void) {
    char tmp[24];
    snprintf(tmp, sizeof tmp, "%s", bill);
    for (char* p = tmp; *p; p++)
        if (*p == ',') *p = '.';   /* "12,50" works as well as "12.50" */
    double v = strtod(tmp, NULL);
    return v > 0 ? v : 0;
}

static void save(void) {
    store_setStr("bill", bill);
    store_setNum("tip", tip);
    store_setNum("people", people);
    store_setBool("roundUp", roundUp);
}

void app_load(const char* arg) {
    snprintf(bill, sizeof bill, "%s", store_getStr("bill", ""));
    tip = (float)store_getNum("tip", 15);
    people = (int)store_getNum("people", 2);
    roundUp = store_getBool("roundUp", false);
}

/* each share, rounded up to a whole number when asked; the total follows the rounded shares */
static void compute(double* tipAmount, double* total, double* share) {
    double b = amount();
    *tipAmount = b * tip / 100.0;
    *share = (b + *tipAmount) / people;
    if (roundUp) *share = ceil(*share);
    *total = *share * people;
    if (roundUp) *tipAmount = *total - b;
}

static void row(const char* label, const char* value, float x, float y, float w, bool big) {
    gfx_color(theme_color(big ? "text" : "text2"));
    gfx_text(label, x + 16, y + (big ? 12 : 10), big ? 16 : 14, big ? "semibold" : NULL, NULL, 0);
    gfx_color(theme_color(big ? "accent" : "text"));
    gfx_text(value, x, y + (big ? 8 : 10), big ? 22 : 14, big ? "bold" : "medium", "right", w - 16);
}

void app_draw(float w, float h) {
    gfx_clear(theme_color("bg"));
    float x = 20, cw = w - 40, y = 16;

    gfx_color(theme_color("text"));
    gfx_text(TR("bill"), x, y + 8, 14, "medium", NULL, 0);
    if (ui_textfield("bill", bill, sizeof bill, x + 140, y, cw - 140, 34, "0.00", "numeric")) save();
    y += 50;

    gfx_text(TR("tip"), x, y + 8, 14, "medium", NULL, 0);
    const char* items[NPRESETS];
    char labels[NPRESETS][8];
    int selected = -1;
    for (int i = 0; i < NPRESETS; i++) {
        snprintf(labels[i], sizeof labels[i], "%d%%", PRESETS[i]);
        items[i] = labels[i];
        if ((int)tip == PRESETS[i]) selected = i;
    }
    int s = ui_segmented("presets", items, NPRESETS, selected, x + 140, y, cw - 140, 32);
    if (s != selected && s >= 0) {
        tip = (float)PRESETS[s];
        save();
    }
    y += 44;
    gfx_color(theme_color("text2"));
    gfx_text(nxv_fmt("%d%%", (int)tip), x, y + 4, 14, "mono", NULL, 0);
    float t = ui_slider("tipslider", tip, 0, 40, x + 140, y, cw - 140, 1);
    if (t != tip) {
        tip = t;
        save();
    }
    y += 44;

    gfx_color(theme_color("text"));
    gfx_text(TR("people"), x, y + 8, 14, "medium", NULL, 0);
    if (ui_iconButton("remove", x + 140, y, 34, 34, NULL, false, "minus") && people > 1) {
        people--;
        save();
    }
    gfx_text(nxv_fmt("%d", people), x + 178, y + 6, 18, "semibold", "center", 50);
    if (ui_iconButton("add", x + 232, y, 34, 34, NULL, false, "plus") && people < 50) {
        people++;
        save();
    }
    gfx_color(theme_color("text"));
    gfx_text(TR("round_up"), x + 290, y + 8, 14, NULL, NULL, 0);
    bool r = ui_toggle("round", roundUp, w - 20 - 52, y + 4);
    if (r != roundUp) {
        roundUp = r;
        save();
    }
    y += 54;

    double tipAmount, total, share;
    compute(&tipAmount, &total, &share);
    char tipText[32], totalText[32], shareText[32];
    snprintf(tipText, sizeof tipText, "%.2f", tipAmount);
    snprintf(totalText, sizeof totalText, "%.2f", total);
    snprintf(shareText, sizeof shareText, "%.2f", share);
    ui_group(x, y, cw, 132);
    row(TR("tip_amount"), tipText, x, y, cw, false);
    ui_separator(x + 16, y + 40, x + cw - 16);
    row(TR("total"), totalText, x, y + 42, cw, false);
    ui_separator(x + 16, y + 82, x + cw - 16);
    row(TR("each"), shareText, x, y + 86, cw, true);
    y += 148;

    if (ui_button(TR("share"), x, y, 140, 34, NULL, "ios_share", amount() > 0))
        sys_share(TR3("share_text", totalText, nxv_fmt("%d", people), shareText));
}

void app_menu(void) {
    menu_begin(TR("app"));
    menu_item(TR("clear"), 1, NULL, false, bill[0] != 0);
}

void app_onmenu(int id) {
    if (id == 1) {
        bill[0] = 0;
        save();
    }
}
