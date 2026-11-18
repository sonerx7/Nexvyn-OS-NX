# Nexvyn Public SDK AI Lookup Map

## Cards
- [NATIVE_ABI.md](NATIVE_ABI.md) — Frozen Native ABI v1, `NXN_ABI_VERSION`, `nxn_app`/`nxn_app_api`, struct versioning, `minNative`, `nxn_caps`.
- [SCRIPT_SDK.md](SCRIPT_SDK.md) — Lua/JS/Python/C script modules (`gfx`, `ui`, `nxui`, `g3d`, `phys`, `nav`, `fs`, `store`, `net`, `sys`, `audio`, `TR`), callbacks.
- [UI_NXUI.md](UI_NXUI.md) — `nxui`, `nxn_nxui`, `nxn_os_ui`, `nxn_ui`, Dear ImGui frame layer, `nxn_menu`, `nxn_dialog`, OS design rules.
- [GRAPHICS.md](GRAPHICS.md) — `nxn_display`, GL 4.3 Core / GLES 3.2, `nexgfx_native` (`ngfx_*`), resize `NXN_ERR_BUSY` rule.
- [INPUT.md](INPUT.md) — `nxn_input`, action states, `nxn_port_input`, `nxn_imgui_input`, multi-touch `id`, focus nav vs `nxn_nav`.
- [AUDIO.md](AUDIO.md) — `nxn_audio` streams, OS mixer (`nxn_sfx_*`, `nxn_tone`), script `audio.*`, and `sfx` game kit.
- [FILES_STORAGE.md](FILES_STORAGE.md) — `nxn_fs`, `nxn_stream`, app-scoped paths, `nxn_pick`/`nxn_grant_*`, `nxn_save_*`, `fs.*`, `store.*`.
- [NETWORK.md](NETWORK.md) — `net.get`/`post`/`request`/`ws`/`oauth`, `gfx.imageUrl`, `sys.online()`, `"network"` permission, BSD sockets.
- [SYSTEM.md](SYSTEM.md) — `nxn_sys`, `nxn_power`, threads, `nxn_lib`, JIT (`nxn_jit`), guard pages, fault handler, N4 limits.
- [LIFECYCLE_WINDOW.md](LIFECYCLE_WINDOW.md) — `nxn_event_poll`, suspend/resume, focus loss, `nxn_window`, fullscreen, `liveResize`, `NXN_ERR_BUSY`.
- [PACKAGING.md](PACKAGING.md) — `.nxvapp`, `app.json`, `store.json`, `icon.png`, 8 required `lang/*.json` locales, optional signing, CLI tools.

## Keywords
| Keyword | Card & Section |
|---|---|
| `app.autosave` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.close` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.draw` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.event` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.focus` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.json` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `app.load` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.menu` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.onmenu` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.open` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.resume` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.search` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.suspend` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.unsaved` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `app.update` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `audio.music` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `audio.play` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `audio.stopAll` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `audio.tone` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `category` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `design_check.py` | [UI_NXUI.md#Rules](UI_NXUI.md#Rules) |
| `fileTypes` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `fs.readBytes` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `fs.saveBackup` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `fs.unzip` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `g3d.model` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `g3d.renderer` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `g3d.voxels` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `gamepad` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `gfx.clear` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `gfx.imageUrl` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `gfx.size` | [SCRIPT_SDK.md#Rules](SCRIPT_SDK.md#Rules) |
| `gfx.text` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `GL 4.3` | [GRAPHICS.md#Purpose](GRAPHICS.md#Purpose) |
| `GLES 3.2` | [GRAPHICS.md#Purpose](GRAPHICS.md#Purpose) |
| `gladLoadGLLoader` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `icon.png` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `input.action` | [INPUT.md#Rules](INPUT.md#Rules) |
| `input.motion` | [INPUT.md#Keys](INPUT.md#Keys) |
| `input.stick` | [INPUT.md#Keys](INPUT.md#Keys) |
| `json.decode` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `lang/en.json` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `liveResize` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `loadingHint` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `minNative` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `minSdk` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `nav` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `net.cancel` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.download` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.get` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.json` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.oauth` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.post` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.request` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `net.ws` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `nexgfx_native.h` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `nexvyn_native.h` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `ngfx_device_create` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `ngfx_device_prepare` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `ngfx_render` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `ngfx_scene_load` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `ngfx_scene_step` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `NXN_ABI_GEN` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `NXN_ABI_VERSION` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `NXN_ACT_CANCEL` | [INPUT.md#Keys](INPUT.md#Keys) |
| `NXN_ACT_CONFIRM` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_app.h` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_app_api.h` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_app_exit` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_audio_clear` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `nxn_audio_open` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `nxn_audio_queue` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `nxn_BTN_*` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_CAP_*` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_capability_query` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_caps_get` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_clipboard_get` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_dialog` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `NXN_DIR_BUNDLE` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `NXN_DIR_DATA` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_display_open` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `nxn_display_proc` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `nxn_display_resize` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `nxn_display_swap` | [GRAPHICS.md#Keys](GRAPHICS.md#Keys) |
| `NXN_ERR_BUSY` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_FOCUS` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_POWER` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_QUIT` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_RESIZE` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_RESUME` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `NXN_EVENT_SUSPEND` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `nxn_event_poll` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `nxn_fault_handler_set` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_fs_read` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_fs_write` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_grant_get` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_imgui_add_font` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_imgui_input` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_imgui_input_event` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_info_get` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_init` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_input_action_buttons` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_action_down` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_key_poll` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_mouse` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_pad_poll` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_poll` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_relative_mouse` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_text_request` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_input_touch` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_jit_create` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_last_error` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_lib_open` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_log` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_mem_guard` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_menu_set` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_nav.h` | [INPUT.md#Pitfalls](INPUT.md#Pitfalls) |
| `nxn_notify` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_nxui_begin` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_nxui_end_ex` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_nxui_move_focus` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_os_frame_begin` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_os_ui.h` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_perm_query` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_pick` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_port_input.h` | [INPUT.md#Keys](INPUT.md#Keys) |
| `nxn_power_get` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_prompt` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_request_return` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_rumble` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_run` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `NXN_S` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_save_backup` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_sfx_play` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `nxn_should_quit` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_stream_open` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_stream_prefetch` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `nxn_stream_read` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `NXN_STRUCT_INIT` | [NATIVE_ABI.md#Keys](NATIVE_ABI.md#Keys) |
| `nxn_thread_start` | [SYSTEM.md#Keys](SYSTEM.md#Keys) |
| `nxn_tone` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `nxn_tr` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_ui_font_get` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_ui_tokens_get` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxn_window_set_mode` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `nxn_window_set_modified` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `nxn_window_set_title` | [LIFECYCLE_WINDOW.md#Keys](LIFECYCLE_WINDOW.md#Keys) |
| `nxui.begin` | [UI_NXUI.md#Keys](UI_NXUI.md#Keys) |
| `nxv.py` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `nxv_i18n.py` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `nxv_native` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `nxvapp` | [PACKAGING.md#Purpose](PACKAGING.md#Purpose) |
| `nxvmod` | [NATIVE_ABI.md#Purpose](NATIVE_ABI.md#Purpose) |
| `permissions` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `phys` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `sfx` | [AUDIO.md#Keys](AUDIO.md#Keys) |
| `shareTargets` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `store.json` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `store.set` | [FILES_STORAGE.md#Keys](FILES_STORAGE.md#Keys) |
| `sys.memory` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `sys.online` | [NETWORK.md#Keys](NETWORK.md#Keys) |
| `targetSdk` | [PACKAGING.md#Keys](PACKAGING.md#Keys) |
| `timer.after` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `TR` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
| `ui.tokens` | [SCRIPT_SDK.md#Keys](SCRIPT_SDK.md#Keys) |
