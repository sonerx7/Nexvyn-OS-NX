/* Nexvyn Native SDK - OS dialogs (Native 1.2, NXN_CAP_DIALOG).
 *
 * The same alert / question / text prompt the OS apps and script apps show (ui.alert, ui.prompt): the OS look, the
 * user's theme, gamepad and touch work, Esc / B answers. Use it instead of drawing your own box for "Load this ROM?",
 * "Overwrite the save?", "Name of the new profile".
 *
 *     const char* labels[] = {"Overwrite", "Cancel"};
 *     nxn_dialog_params dp = NXN_STRUCT_INIT(nxn_dialog_params);
 *     dp.title = "Overwrite save?"; dp.message = "The slot already has a save.";
 *     dp.buttons = labels; dp.button_count = 2; dp.danger_button = 0; dp.cancel_button = 1;
 *     uint32_t picked;
 *     if (nxn_dialog(&dp, &picked) == NXN_OK && picked == 0) overwrite();
 *
 * These calls WAIT for the user (like nxn_pick) on the calling app thread; the OS main thread keeps drawing and the
 * window is not "not responding" meanwhile. So call them from a worker thread when the app has to keep running (an
 * emulator keeps emulating, a game keeps drawing), or from the main thread when pausing is what you want. One dialog
 * per app at a time: a second call while one is open returns NXN_ERR_BUSY. When the window closes while a dialog is
 * open the call returns NXN_ERR_NOT_READY. Texts are keys of the app's lang/<code>.json (nxn_tr) or plain text.
 * Needs NXN_CAP_DIALOG; otherwise NXN_ERR_UNSUPPORTED (a stand-alone .nro). Memory: strings are copied during the call. */
#ifndef NEXVYN_NXN_DIALOG_H
#define NEXVYN_NXN_DIALOG_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

#define NXN_DIALOG_MAX_BUTTONS 4
#define NXN_DIALOG_NONE 0xFFFFFFFFu /* cancel_button / danger_button: none (cancel: the last button answers Esc / B) */

typedef struct nxn_dialog_params {
    uint32_t size;
    uint32_t flags;           /* 0 */
    const char* title;        /* NULL = the app's name */
    const char* message;      /* NULL = none; cut at 2000 bytes */
    const char* const* buttons; /* 1..NXN_DIALOG_MAX_BUTTONS labels, the first is the default (Enter / A); each cut at 48 bytes */
    uint32_t button_count;
    uint32_t cancel_button;   /* the button Esc / B answers with; NXN_DIALOG_NONE = the last one */
    uint32_t danger_button;   /* the button drawn in the destructive style; NXN_DIALOG_NONE = none */
    uint32_t reserved;        /* 0 */
} nxn_dialog_params;

/* Shows the dialog and waits. NXN_OK: *picked is the index of the button the user chose (Esc / B gives cancel_button).
 * NXN_ERR_INVALID: no buttons, too many, a NULL label, a button index out of range. */
NXN_API nxn_result nxn_dialog(const nxn_dialog_params* params, uint32_t* picked);

/* A text prompt (a field with OK / Cancel; the OS keyboard opens on a console without one). `initial` may be NULL. NXN_OK:
 * the text is in `out` (UTF-8, terminated); NXN_ERR_CANCELLED: the user cancelled (out is ""); NXN_ERR_TOO_SMALL: the
 * text does not fit in `cap`. NXN_ERR_BUSY / NXN_ERR_NOT_READY as for nxn_dialog. */
NXN_API nxn_result nxn_prompt(const char* title, const char* message, const char* initial, char* out, size_t cap);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_DIALOG_H */
