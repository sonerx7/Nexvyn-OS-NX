Patches against the upstream source, applied in name order by `fetch.py`
(`0001-short-reason.patch`, `0002-...`). Keep each one small and give it one reason.

Make one from a clean checkout of `upstream/`: edit, then `git -C upstream diff > patches/0001-what-and-why.patch`
(reset the checkout with `git -C upstream checkout .` and run `python fetch.py` again to test the set).

Typical reasons (see sdk/native/ports/chocolate-doom/patches for real ones):
- the app's data folder: read settings and assets from `nxn_fs_path(NXN_DIR_DATA, ...)`, not from the current directory
- leaving: the window's close button arrives as the library's quit event (SDL_QUIT, or NXN_EVENT_QUIT): return from main
- a call the target does not have: prefer the compat layer (`nexvyn_use_compat`) to a patch; patch only the rest
- thread_local data: a window module cannot have it (PT_TLS); use a plain static for a single-threaded core

Do not patch the upstream licence, copyright notices or credits.
