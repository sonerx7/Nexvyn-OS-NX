/* Nexvyn Native SDK - window menu: the app's menus in the OS menu bar while its window is focused.
 *
 * For windowed apps that should behave like part of Nexvyn OS (editors, tools, front ends). A GAME does not use this:
 * it draws its own pause menu in its own art direction. The OS draws the menus with its own look; the app only says
 * what is in them. Same model as the script SDK's app.menu() / app.onmenu(id): menus with a title and items (label,
 * id, shortcut, enabled, checked, separator); a pick arrives as NXN_EVENT_MENU with the item's id.
 *
 *     nxn_menu_item file_items[] = {
 *         {sizeof(nxn_menu_item), 1, "menu.new", "Ctrl+N", 0, 0},          // size, id, label, shortcut, flags, reserved
 *         {sizeof(nxn_menu_item), 0, NULL, NULL, NXN_MENU_SEPARATOR, 0},
 *         {sizeof(nxn_menu_item), 2, "menu.save", "Ctrl+S", NXN_MENU_CHECKED, 0},
 *     };
 *     nxn_menu_menu menus[] = {{sizeof(nxn_menu_menu), "menu.file", file_items, 3, sizeof(nxn_menu_item)}};
 *     nxn_menu_spec spec = {sizeof(nxn_menu_spec), menus, 1, sizeof(nxn_menu_menu)};
 *     nxn_menu_set(&spec);
 *
 * Labels are keys of the app's lang/<code>.json (nxn_tr): a text without a key is shown as it is. Everything is copied
 * during the call. Call nxn_menu_set again whenever an item changes (enabled, checked); it replaces the whole menu.
 * Needs NXN_CAP_MENU (nxn_caps.features) and an app.json "minNative" of 1.1 or later, and Settings must allow it
 * (native.windowMenu); otherwise nxn_menu_set returns NXN_ERR_UNSUPPORTED and the app keeps running without a menu.
 * A stand-alone .nro has no OS menu bar: UNSUPPORTED. The menu is removed when the app ends. Everything is add-only
 * like the rest of the ABI. */
#ifndef NEXVYN_NXN_MENU_H
#define NEXVYN_NXN_MENU_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

#define NXN_MENU_MAX_MENUS 12   /* top-level menus */
#define NXN_MENU_MAX_ITEMS 48   /* items in one menu */
#define NXN_MENU_MAX_TEXT 64    /* bytes of a label (after translation) or a shortcut, without the NUL */

enum {
    NXN_MENU_SEPARATOR = 1u << 0, /* a line; id and label are ignored */
    NXN_MENU_DISABLED = 1u << 1,  /* shown grey, cannot be picked */
    NXN_MENU_CHECKED = 1u << 2    /* shown with a check mark */
};

typedef struct nxn_menu_item {
    uint32_t size;          /* sizeof(nxn_menu_item) of the caller */
    uint32_t id;            /* delivered in NXN_EVENT_MENU (item_id); not 0 for a pickable item */
    const char* label;      /* nxn_tr key or plain text */
    const char* shortcut;   /* shown beside the label ("Ctrl+S"), display only; NULL: none */
    uint32_t flags;         /* NXN_MENU_* */
    uint32_t reserved;      /* 0 (an initializer that leaves it out sets 0); the tail padding made explicit, see nxn_base.h */
} nxn_menu_item;

typedef struct nxn_menu_menu {
    uint32_t size;          /* sizeof(nxn_menu_menu) of the caller */
    const char* title;      /* the title in the bar: nxn_tr key or plain text */
    const nxn_menu_item* items;
    uint32_t item_count;    /* at most NXN_MENU_MAX_ITEMS */
    uint32_t item_stride;   /* sizeof(nxn_menu_item) of the caller (arrays of older and newer layouts both work) */
} nxn_menu_menu;

typedef struct nxn_menu_spec {
    uint32_t size;          /* sizeof(nxn_menu_spec) of the caller */
    const nxn_menu_menu* menus;
    uint32_t menu_count;    /* at most NXN_MENU_MAX_MENUS */
    uint32_t menu_stride;   /* sizeof(nxn_menu_menu) of the caller */
} nxn_menu_spec;

/* Replaces the app's menus with a copy of `spec`. NXN_OK; NXN_ERR_INVALID: NULL, a bad size / stride, too many menus or
 * items, a label longer than NXN_MENU_MAX_TEXT, an item (not a separator) with id 0 or no label, or a duplicate id
 * (nothing changed: the old menu stays); NXN_ERR_UNSUPPORTED: see above. A spec with menu_count 0 is nxn_menu_clear.
 * Thread: any app thread. Memory: nothing is kept; the caller's strings may go after the call. */
NXN_API nxn_result nxn_menu_set(const nxn_menu_spec* spec);

/* Removes the app's menus. Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_menu_clear(void);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_MENU_H */
