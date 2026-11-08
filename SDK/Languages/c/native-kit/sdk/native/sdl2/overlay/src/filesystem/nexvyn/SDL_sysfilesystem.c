/* Nexvyn OS SDL2 driver (windowed native apps): SDL_GetBasePath / SDL_GetPrefPath from the app's own folders.
 * Added to SDL2 (zlib license) by the Nexvyn native kit; see sdk/native/sdl2/README.md. Not part of upstream SDL. */
#include "../../SDL_internal.h"

#ifdef SDL_FILESYSTEM_NEXVYN

#include "SDL_error.h"
#include "SDL_stdinc.h"
#include "SDL_filesystem.h"
#include <nexvyn/nexvyn_native.h>

static char *dir_with_slash(nxn_dir dir, int create)
{
    char path[512];
    if (create && nxn_fs_mkdirs(dir, "") != NXN_OK) {
        SDL_SetError("cannot create the app folder: %s", nxn_last_error());
        return NULL;
    }
    if (nxn_fs_path(dir, "", path, sizeof(path)) != NXN_OK) {
        SDL_SetError("nxn_fs_path: %s", nxn_last_error());
        return NULL;
    }
    size_t n = SDL_strlen(path);
    if (n + 2 > sizeof(path)) {
        SDL_SetError("path too long");
        return NULL;
    }
    if (n == 0 || path[n - 1] != '/') {
        path[n++] = '/';
        path[n] = '\0';
    }
    return SDL_strdup(path);
}

/* the package folder (read-only): assets shipped with the app */
char *SDL_GetBasePath(void)
{
    return dir_with_slash(NXN_DIR_BUNDLE, 0);
}

/* org and app are not used: the folder is the app's own (NXN_DIR_DATA), kept across updates */
char *SDL_GetPrefPath(const char *org, const char *app)
{
    return dir_with_slash(NXN_DIR_DATA, 1);
}

#endif /* SDL_FILESYSTEM_NEXVYN */
