/* Nexvyn Native SDK library - nxn_window.h in a stand-alone .nro: there is no window. The calls say so
 * (NXN_ERR_UNSUPPORTED, NXN_CAP_WINDOW_CTL not set), so an app that uses them still runs. Inside Nexvyn OS (windowed
 * mode) the system implements them (source/runtimes/nxwin_winctl.cpp). */
#include "nxn_internal.h"

nxn_result nxn_window_set_title(const char* title, const char* subtitle) {
    (void)title;
    (void)subtitle;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_window_set_mode(nxn_window_mode mode) {
    if (mode != NXN_WIN_NORMAL && mode != NXN_WIN_MAXIMIZED && mode != NXN_WIN_FULLSCREEN) return NXN_ERR_INVALID;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_window_set_modified(int modified) {
    (void)modified;
    return NXN_ERR_UNSUPPORTED;
}
