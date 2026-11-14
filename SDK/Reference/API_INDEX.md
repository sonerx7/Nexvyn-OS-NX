# Nexvyn API index (machine-readable)

Compact index of every public API name. Source of truth: the SDK reference (script SDK) and the Native SDK headers
(`nxn_*.h`). Names are exact. If this index and a header disagree, the header wins.

Legend:
- **Runtimes**: `L` Lua, `J` JavaScript, `P` Python (`python` and `python3`), `C` C (`nexvyn.h`, name = `module_fn`), `Sq` Squirrel, `Jv` Java.
- **Since**: SDK version that added the function (`1.0*` = the module existed in 1.0; the function-level version is not stated in the reference).
- **Frozen**: Squirrel and Java are frozen at SDK 1.8. Every function they have keeps working. No new API is added to them. Start new apps in Lua, JavaScript, Python or C.
- **Deprecated**: a deprecated name still works. The first call per run writes a log line naming its replacement.
- Behaviour changes are gated by the app's `targetSdk`. Apps set `minSdk` to the newest SDK function they use.

---

## 1. Script SDK (`SDK.md`)

### 1.1 Program callbacks (`app.*`, all optional)

| Name | Signature | Since | Runtimes | Notes |
|---|---|---|---|---|
| `app.load` | `(arg)` | 1.0* | L J P C(`app_load`) | once; `arg` = file / URL / "" |
| `app.open` | `(arg)` | 1.0* | L J P C(`app_open`) | asked to open something while running |
| `app.update` | `(dt)` | 1.0* | L J P C(`app_update`) | every frame |
| `app.draw` | `(w, h)` | 1.0* | L J P C(`app_draw`) | draw and widgets |
| `app.event` | `(e)` | 1.0* | L J P C(`app_event`) | raw input |
| `app.menu` | `()` returns menus | 1.0* | L J P C(`app_menu`) | window menus |
| `app.onmenu` | `(id)` | 1.0* | L J P C(`app_onmenu`) | |
| `app.close` | `() -> bool` | 1.0* | L J P C(`app_close`) | `false` keeps window open |
| `app.search` | `(query)` | 1.4 | L J P C(`app_search`) | Quick Search items |
| `app.suspend` / `app.resume` | `()` | 1.4 | L J P C(`app_suspend`/`app_resume`) | background / foreground |
| `app.focus` | `(focused)` | 1.4 | L J P C(`app_focus`) | keyboard focus |
| `app.autosave` | `()` | 1.4 | L J P C(`app_autosave`) | save point |
| `app.unsaved` | `() -> bool` | 1.4 | L J P C(`app_unsaved`) | unsaved work |

### 1.2 `gfx` (drawing)

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `gfx.color` | `(c)` or `(r,g,b[,a])` | 1.0* | L J P C | `gfx_color` |
| `gfx.clear` | `([c])` | 1.0* | L J P C | `gfx_clear` |
| `gfx.rect` | `(x,y,w,h[,radius[,c]])` | 1.0* | L J P C | `gfx_rect` |
| `gfx.rectLine` | `(x,y,w,h[,radius[,thickness]])` | 1.0* | L J P C | `gfx_rectLine` |
| `gfx.circle` / `gfx.circleLine` | `(x,y,r[,c])` / `(x,y,r[,t])` | 1.0* | L J P C | `gfx_circle`, `gfx_circleLine` |
| `gfx.line` | `(x1,y1,x2,y2[,thickness])` | 1.0* | L J P C | `gfx_line` |
| `gfx.lines` | `({x1,y1,...}[,thickness[,closed]])` | 1.0* | L J P C | `gfx_lines` |
| `gfx.poly` | `({x1,y1,...}[,c])` convex only | 1.0* | L J P C | `gfx_poly` |
| `gfx.arc` / `gfx.pie` | `(x,y,r,a0,a1[,thickness])` / `(x,y,r,a0,a1)` | 1.0* | L J P C | `gfx_arc`, `gfx_pie` |
| `gfx.gradient` | `(x,y,w,h,c1,c2[,horizontal[,radius]])` | 1.0* | L J P C | `gfx_gradient` |
| `gfx.shadow` | `(x,y,w,h[,radius[,blur[,dy]]])` | 1.0* | L J P C | `gfx_shadow` |
| `gfx.text` | `(s,x,y[,size[,font[,align,width]]]) -> width` | 1.0* | L J P C | `gfx_text` |
| `gfx.textWidth` / `gfx.textHeight` | `(s[,size[,font]])` / `([size[,font]])` | 1.0* | L J P C | `gfx_textWidth`, `gfx_textHeight` |
| `gfx.wrap` | `(s,x,y,w[,size[,font[,align[,lineSpacing]]]]) -> height` | 1.0* | L J P C | `gfx_wrap` |
| `gfx.measureWrap` | `(s,w[,size[,font]]) -> height` | 1.0* | L J P C | `gfx_measureWrap` |
| `gfx.icon` | `(name,cx,cy[,size[,c]])` | 1.0* | L J P C | `gfx_icon` |
| `gfx.image` | `(path) -> img or nil` | 1.0* | L J P C | `gfx_image` |
| `gfx.draw` | `(img,x,y[,w,h[,radius[,tint]]])` | 1.0* | L J P C | `gfx_draw` (C takes a path) |
| `gfx.drawRegion` | `(img,sx,sy,sw,sh,x,y,w,h[,angleDeg])` | 1.0* | L J P C | `gfx_drawRegion` |
| `gfx.push` / `gfx.pop` | `(dx,dy)` / `()` | 1.0* | L J P C | `gfx_push`, `gfx_pop` |
| `gfx.clip` / `gfx.unclip` | `(x,y,w,h)` / `()` | 1.0* | L J P C | `gfx_clip`, `gfx_unclip` |
| `gfx.alpha` / `gfx.unalpha` | `(a)` / `()` | 1.0* | L J P C | `gfx_alpha`, `gfx_unalpha` |
| `gfx.size` | `() -> w,h` | 1.0* | L J P C | `gfx_size(&w,&h)` |
| `gfx.imageUrl` | `(url[,maxSize]) -> path or null` | 1.9 | L J P C | `gfx_imageUrl(url,maxSize,&w,&h)` |
| `gfx.imageState` | `(url[,maxSize])` | 1.9 | J C | `gfx_imageState` |

### 1.3 `theme` and `ui.tokens`

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `theme` (fields) | `theme.dark, bg, window, sidebar, text, text2, text3, separator, control, field, selection, hover, accent, red..gray` | 1.0* | L J P | `theme_color(name)`, `theme_dark` |
| `ui.tokens` | `() -> table` (`dark`, `highContrast`, `boldText`, `textScale`, `colors{...}`, `cornerRadius`, `spacing`, `controlHeight`, `rowHeight`, `fontSmall/Body/Large/Title`) | 1.12 | L J P C (JSON text) | `ui_tokens()` |

### 1.4 `ui` (widgets, dialogs)

| Name | Signature / returns | Since | Runtimes | C |
|---|---|---|---|---|
| `ui.button` | `(label,x,y,w,h[,style[,icon[,enabled]]]) -> bool` | 1.0* | L J P C | `ui_button` |
| `ui.iconButton` | `(icon,x,y,w,h[,tint[,active[,idSuffix]]]) -> bool` | 1.0* | L J P C | `ui_iconButton` |
| `ui.toggle` | `(id,value,x,y[,w,h]) -> bool` | 1.0* | L J P C | `ui_toggle` |
| `ui.checkbox` | `(label,value,x,y) -> bool` | 1.0* | L J P C | `ui_checkbox` |
| `ui.radio` | `(label,selected,x,y) -> bool` | 1.0* | L J P C | `ui_radio` |
| `ui.slider` | `(id,value,min,max,x,y,w[,step]) -> number` | 1.0* | L J P C | `ui_slider` |
| `ui.textfield` | `(id,text,x,y,w[,h[,placeholder[,flags]]]) -> newText, submitted` | 1.0* | L J P C | `ui_textfield` (edits a char buffer) |
| `ui.submitted` | `(id)` | 1.0* | J C | `ui_submitted` (JS-only extra in the reference) |
| `ui.segmented` | `(id,{items},selected,x,y,w[,h]) -> index` (1-based) | 1.0* | L J P C | `ui_segmented` |
| `ui.dropdown` | `(id,{items},selected,x,y,w[,h]) -> index` (1-based) | 1.0* | L J P C | `ui_dropdown` |
| `ui.label` | `(text,x,y[,size[,color[,font]]])` | 1.0* | L J P C | `ui_label` |
| `ui.progress` | `(value,x,y,w[,h])` value 0..1 or -1 | 1.0* | L J P C | `ui_progress` |
| `ui.spinner` | `(x,y[,radius])` | 1.0* | L J P C | `ui_spinner` |
| `ui.row` | `(id,x,y,w,h,selected) -> clicked, doubleClicked` | 1.0* | L J P C | `ui_row` |
| `ui.group` / `ui.separator` | `(x,y,w,h)` / `(x1,y,x2)` | 1.0* | L J P C | `ui_group`, `ui_separator` |
| `ui.beginScroll` / `ui.endScroll` | `(id,x,y,w,h,contentHeight[,contentWidth]) -> scrollY, scrollX` / `()` | 1.0* | L J P C | `ui_beginScroll`, `ui_endScroll` |
| `ui.hit` | `(id,x,y,w,h) -> {hovered,held,pressed,clicked,rightClicked,doubleClicked,dx,dy}` | 1.0* | L J P C | `ui_hit` |
| `ui.mouse` | `() -> x,y,down,hovering` | 1.0* | L J P C | `ui_mouse(&x,&y,&down,&hover)` |
| `ui.focus` | `(id)` | 1.0* | L J P C | `ui_focus` |
| `ui.contextMenu` | `({items}, fn(id))` | 1.0* | L J P C | `ui_contextMenu` (C: `menu_*` builders) |
| `ui.alert` | `(title,message,{buttons}, fn(index))` 1-based | 1.0* | L J P C | `ui_alert` |
| `ui.prompt` | `(title,message,default, fn(textOrNil))` | 1.0* | L J P C | `ui_prompt` |
| `ui.openFile` | `(fn(pathOrNil), {exts}[, title])` | 1.0* | L J P C | `ui_openFile` |
| `ui.saveFile` | `(fn(pathOrNil), "name"[, title])` | 1.0* | L J P C | `ui_saveFile` |
| `ui.keyboard` | `(initial, fn(textOrNil)[, guide])` | 1.0* | L J P C | `ui_keyboard` |
| `ui.chooseFolder` | `({title, remember}, fn(path, err))` | 1.11 | L J P C | `ui_chooseFolder` |
| `ui.beginFeed` / `ui.feedItem` / `ui.endFeed` | feed list (0-based indexes in J and C) | 1.9 | L J P C | `ui_beginFeed`, `ui_feedItem(i,&x,&y,&w,&h)`, `ui_endFeed` |
| `ui.pager` | `(id,x,y,w,h,count[,options])` | 1.9 | L J P C | `ui_pager(...,&page)` |
| `ui.richText` | `(id,text,x,y,w[,size[,options]])` | 1.9 | L J P C | `ui_richText(...,&clicked)`, `ui_measureRichText` |

### 1.5 Input (`app.event`, `input`)

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `app.event` event types | `mousedown mouseup mousemove scroll keydown keyup text paddown padup pinch rotate` | 1.0* | L J P C | `nxv_event` struct |
| `input.down` / `input.pressed` / `input.released` | `(button)` | 1.0* | L J P C | `input_down`, `input_pressed`, `input_released` |
| `input.stick` | `("left"\|"right") -> x,y` | 1.0* | L J P C | `input_stick` |
| `input.key` | `(name)` pressed this frame | 1.0* | L J P C | `input_key` |
| `input.touch` | `() -> bool` | 1.0* | L J P C | `input_touch` |
| `input.motion` | gyroscope values (`pitch, roll, yaw`) | not stated | C | `input_motion` (not described in the Lua/JS/Py section) |

Pad events arrive only when `"gamepad": true` is set in `app.json`. Pinch and rotate events are two-finger touch gestures.

### 1.6 Files (`fs`)

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `fs.read` | `(path) -> string or nil,err` | 1.0* | L J P C (`fs_read`, caller frees) | `fs_read` |
| `fs.write` | `(path,data) -> ok` | 1.0* | L J P C | `fs_write` |
| `fs.append` | `(path,data)` | 1.0* | L J P C | `fs_append` |
| `fs.exists` / `fs.isdir` | `(path) -> bool` | 1.0* | L J P C | `fs_exists`, `fs_isdir` |
| `fs.list` | `(path[,showHidden]) -> {{name,path,dir,size,mtime}...}` | 1.0* | L J P C | `fs_list` |
| `fs.mkdir` | `(path)` | 1.0* | L J P C | `fs_mkdir` |
| `fs.remove` | `(path[,permanently])` default to Trash | 1.0* | L J P C | `fs_remove` |
| `fs.rename` / `fs.copy` | `(a,b)` | 1.0* | L J P C | `fs_rename`, `fs_copy` |
| `fs.path` | `(relative) -> absolute` | 1.0* | L J P C | `fs_path` |
| `fs.dir` | `(which)` `data, bundle, cache, home, documents, desktop, downloads, pictures, music` | 1.0* | L J P C | `fs_dir` |
| `fs.unzip` | `(zipPath,destDir[,done[,progress]])` background | 1.6 | L J P | in `nexvyn.h`? not listed (verify) |
| `fs.readBytes` | `(path) -> Uint8Array or null` | 1.0* | J | - |
| `fs.folderGrants` / `fs.folderGranted` / `fs.revokeFolder` | list / `(path)->bool` / `(path)->bool` | 1.11 | L J P C | not listed in `nexvyn.h` (verify) |
| `fs.savePath` | `() -> path` (created) | 1.11 | L J P C | `sys_*` not listed (verify) |
| `fs.saveBackup` / `fs.saveRestore` / `fs.saveDeleteBackup` | `(slot, callback(ok,err))` | 1.11 | L J P | verify |
| `fs.saveBackups` | `() -> slot names` | 1.11 | L J P | verify |

### 1.7 Storage and JSON

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `store.get` / `store.set` | `(key[,default])` / `(key,value)` | 1.0* | L J P C | `store_getStr/Num/Bool/Json`, `store_setStr/Num/Bool/Json` |
| `store.save` | `()` | 1.0* | L J P C | `store_save` |
| `json.decode` / `json.encode` | `(text) -> value or nil,err` / `(value[,pretty]) -> text` | 1.0* | L J P C | `json_pretty` (C) |

### 1.8 Network (`net`)

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `net.get` | `(url[,headers],callback(res))` | 1.0* | L J P C (`net_get`) | `net_get` |
| `net.post` | `(url,body[,contentType],callback)` | 1.0* | L J P C | `net_post` |
| `net.json` | `(url, fn(data,err))` | 1.0* | L J P C | `net_json` |
| `net.download` | `(url,path,fn(ok,pathOrErr)[,progress])` | 1.0* | L J P C | `net_download` |
| `net.encode` | `(text) -> url-encoded` | 1.0* | L J P C | `net_encode` |
| `net.request` | `({url,method,body,contentType,headers}, cb)` (Lua table form) and full option table (see 1.8b) | 1.9 (Lua table form) | L J P C | `net_request` / `net_fetch(jsonOptions, cb, progress, user)` |
| `net.fetch` / `net.fetchJson` | promise-style | 1.9 | J | - |
| `net.clearCookies` / `net.clearCache` | `()` | 1.9 | L J P C | `net_clearCookies`, `net_clearCache` |
| `net.cancel` | `(id)` | 1.9 | C | `net_cancel` |
| `net.ws` | `(url[,options]) -> id` | 1.9 | L J P C | `net_ws`, `net_wsSend`, `net_wsPoll`, `net_wsClose`, `net_wsState` |
| `net.oauth` | `({options}, callback(result,err))` | 1.9 | L J P C | `net_oauth(options,on_json,user)` |

Option table for `net.request` (SDK 1.9): `url, method, headers, body, contentType, json, form, multipart, file, saveTo, responseType, timeout (1-600 s, default 30), redirects, maxBytes (default 16 MB, max 64 MB), retry (0-5), cache (seconds or true), cookies`. Response: `ok, status, body, error, url, headers, data, path, fromCache, stale`.

### 1.9 System (`sys`) and `audio`, `timer`, `TR`, `print`

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `sys.time` / `sys.epoch` | `() -> seconds` (monotonic) / Unix time | 1.0* | L J P C | `sys_time`, `sys_epoch` |
| `sys.date` | `([epoch]) -> {year,month,day,hour,min,sec,wday,yday,epoch}` | 1.0* | L J P C | `sys_date` (`nxv_date`) |
| `sys.battery` | `() -> percent, charging` | 1.0* | L J P C | `sys_battery` |
| `sys.online` | `() -> bool` | 1.0* | L J P C | `sys_online` |
| `sys.lang` / `sys.username` / `sys.model` / `sys.firmware` | `()` | 1.0* | L J P C | `sys_lang`, `sys_username`, `sys_model`, `sys_firmware` |
| `sys.notify` | `(title,body)` needs `"notifications"` | 1.0* | L J P C | `sys_notify` |
| `sys.open` | `(path or nxv://url)` | 1.0* | L J P C | `sys_open` |
| `sys.launch` | `(appId[,arg])` needs `"launch"` | 1.0* | L J P C | `sys_launch` |
| `sys.clipboard` | `([text])` get or set | 1.0* | L J P C | `sys_clipboard`, `sys_setClipboard` |
| `sys.log` | `(...)` (`print` is the same) | 1.0* | L J P C | `sys_log` |
| `sys.title` | `(text)` | 1.0* | L J P C | `sys_title` |
| `sys.exit` | `()` closes the window | 1.0* | L J P C | `sys_exit` |
| `sys.fps` | `() -> number` | 1.0* | L J P C | `sys_fps` |
| `sys.vibrate` | `([strength 0..1[,ms]])`, max 2000 ms, `0` stops | 1.0* | L J P C | `sys_vibrate` |
| `sys.appid` / `sys.sdkVersion` | `()` (`sys.sdkVersion()` returns `"1.13"`) | 1.0* / 1.2 | L J P C | `sys_appid`, `sys_sdkVersion` |
| `sys.memory` | `() -> used, limit` (limit 64 MB) | 1.4 | L J P C | `sys_memory` |
| `sys.share` | `(textOrPath) -> bool` | 1.4 | L J P C | `sys_share` |
| `sys.schedule` / `sys.unschedule` / `sys.scheduled` | `(epoch,title[,body[,arg]]) -> id` / `(id)` / `() -> list` | 1.4 | L J P C | `sys_schedule`, `sys_unschedule`, `sys_scheduled` |
| `sys.hasPermission` / `sys.requestPermission` | `(name) -> bool` / `(name[,fn(granted)])` | 1.4 | L J P C | `sys_hasPermission`, `sys_requestPermission` |
| `sys.appUrl` | `(id[,arg]) -> nxv://app/...` | 1.4 | L J P C | `sys_appUrl` |
| `sys.games` | `([fn(list)]) -> list` needs `"games"` | 1.6 | L J P | not listed in `nexvyn.h` (verify) |
| `sys.speak` / `sys.stopSpeaking` | `(text[,lang])` / `()` | 1.6 | L J P C | `sys_speak`, `sys_stopSpeaking` |
| `sys.relativeTime` | `(epoch[,now])` | 1.9 | L J P C | `sys_relativeTime` |
| `audio.tone` | `(freq,seconds[,volume[,wave]]) -> channel` | 1.0* | L J P C | `audio_tone` |
| `audio.play` | `(nameOrPath[,volume[,loops]]) -> channel` | 1.0* | L J P C | `audio_play` |
| `audio.stop` | `(channel)` | 1.0* | L J P C | `audio_stop` |
| `audio.music` / `audio.musicPause` / `audio.musicStop` | `(path)` / `(bool)` / `()` | 1.0* | L J P C | `audio_music`, `audio_musicPause`, `audio_musicStop` |
| `audio.stopAll` | `()` | 1.12 | L J P C | not listed in `nexvyn.h` (verify) |
| `timer.after` / `timer.every` | `(seconds,fn) -> id` | 1.0* | L J P C | `timer_after`, `timer_every` |
| `timer.cancel` | `(id)` | 1.0* | L J P C | `timer_cancel` |
| `timer.sleep` | promise-style | 1.0* | J | - |
| `TR` | `(key, ...)`; `{0}`, `{1}` replaced | 1.0* | L J P C | `TR`, `TR1`, `TR2`, `TR3` |

### 1.10 `g3d` (3D)

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `g3d.mesh` | `(kind, ...)` primitives | 1.0 | L J P C | `g3d_mesh` |
| `g3d.load` | `(path[,size]) -> mesh or nil,err` (`.obj`, `.stl`) | 1.0 | L J P C | `g3d_load` |
| `g3d.custom` | `({x,y,z...},{i...}[,colors[,flat[,uv]]])` | 1.0 | L J P C | `g3d_custom` |
| `mesh:setColor` / `mesh:flat` / `mesh:triangles` / `mesh:setTexture` | method | 1.0 (setTexture: 1.7 in L/J) | L J P C | `g3d_setColor`, `g3d_flat`, `g3d_triangles`, `g3d_setTexture` |
| `g3d.gpu` | `() -> bool` | 1.0 | L J P C | `g3d_gpu` |
| `g3d.begin` / `g3d.camera` / `g3d.light` / `g3d.fog` / `g3d.draw` / `g3d.line` / `g3d.point` / `g3d.project` / `g3d.finish` | frame calls | 1.0 | L J P C | `g3d_begin`, `g3d_camera`, `g3d_light`, `g3d_fog`, `g3d_draw`, `g3d_line`, `g3d_point`, `g3d_project`, `g3d_finish` |
| `g3d.loadModel` | `(path[,size],callback(model,err))` background | 1.8 | L J P C | `g3d_loadModel` |
| `g3d.model` | `(path[,size]) -> model or nil,err` (`.glb .gltf .fbx .obj .stl`) | 1.8 | L J P C | `g3d_model` |
| `g3d.draw` (model) | `(model,x,y,z,rx,ry,rz,sx,sy,sz,tint,flags)` | 1.8 | L J P C | `g3d_draw` |
| `g3d.drawMatrix` | `(meshOrModel, matrix16[,tint[,flags]])` | 1.8 | L J P C | `g3d_drawMatrix` |
| `model:info / play / stop / update / time / clip / playing / node / nodeMatrix / triangles / free` | method | 1.8 | L J P C | `g3d_modelInfo`, `g3d_modelPlay`, `g3d_modelStop`, `g3d_modelUpdate`, `g3d_modelTime`, `g3d_modelSetTime`, `g3d_modelClip`, `g3d_modelPlaying`, `g3d_modelNode`, `g3d_modelNodeMatrix`, `g3d_model_free` (C name `g3d_free`) |
| `g3d.renderer` | `([name]) -> "pbr" or "basic"` | 1.9 | L J P C | `g3d_renderer` |
| `g3d.caps` / `g3d.rendererInfo` | `() -> table` | 1.9 | L J P C | `g3d_caps`, `g3d_rendererInfo` |
| `g3d.addLight` / `updateLight` / `removeLight` / `clearLights` / `lights` | light list (`type` point, spot, directional) | 1.9 | L J P C | `g3d_addLight`, `g3d_updateLight`, `g3d_removeLight`, `g3d_clearLights`, `g3d_lights` |
| `g3d.shadows` | `(true\|false\|options)` | 1.9 | L J P C | `g3d_shadows` |
| `g3d.postfx` / `g3d.environment` / `g3d.material` | options tables | 1.9 | L J P C | `g3d_postfx`, `g3d_environment`, `g3d_material` |
| `g3d.drawInstanced` | `(meshOrModel, transforms[,tint[,flags[,stride]]])` | 1.9 | L J P C | `g3d_drawInstanced`, `g3d_drawInstancedMatrices` |
| `g3d.voxels` | `(options) -> world` (`world.define`, `view`, `update`, `draw`, `get`, `set`, `raycast`, `move`, `save`, `close`, ...) | 1.7 | J only | not in `nexvyn.h` |

### 1.11 Media, 2D game engine, other

| Name | Signature | Since | Runtimes | C |
|---|---|---|---|---|
| `media` (video/audio player) | `open, draw, play, pause, seek, set, info, close` | 1.9 | L J P C (C names listed) | `media_open`, `media_draw`, `media_play`, `media_pause`, `media_seek`, `media_set`, `media_info`, `media_close` |
| `nexvyn.game` (2D engine) | `game.run(config)`, `game.switch`, `game.push`, `game.pop`, `game.sheet`, `game.sprite`, `game.world`, `game.tilemap`, `game.camera`, `game.lights`, `game.input`, `game.tween`, `game.emitter`, `game.path.find` | not stated | L (system Lua library, `require("nexvyn.game")`) | - |
| `menu_begin` / `menu_item` / `menu_separator` | C menu builders | 1.5 (C) | C | `menu_begin`, `menu_item`, `menu_separator` |
| `nxv_fmt` / `rgba` / `search_result` | C helpers | 1.5 (C) | C | as named |

### 1.12 Permissions and manifest keys used by the calls above

`files` (writes outside app folders, `fs.unzip` target), `launch` (`sys.open` of links, `sys.launch`), `notifications` (`sys.notify`, `sys.schedule`), `games` (`sys.games`). Other permission names: see the app.json section of the SDK reference. Unknown `app.json` fields and unknown permissions are ignored. `minSdk` and `targetSdk` are SDK version strings such as `"1.13"`.

### 1.13 Deprecated

| Name | Replacement | Status |
|---|---|---|
| `require("snx.*")` | `require("nexvyn.*")` | deprecated, still works |
| permission `"clipboard"` | none (clipboard needs no permission) | accepted and ignored |

---

## 2. Native SDK (`nxn_*.h`, `docs/NATIVE_KIT.md`)

Native apps are C or C++ `.nxvmod` packages. `app.json`: `"runtime": "native"`, `"minNative"` (Native SDK version) and `"minSdk"`. Raise `minNative` to the version of any function you call that is newer than 1.0. Check `nxn_caps_get` bits before optional calls. Every struct: `NXN_STRUCT_INIT(type)`. The `nxn_*` ABI v1 is frozen (add-only).

### 2.1 Core (`nxn_app.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_init` | `nxn_result nxn_init(const nxn_init_params* params)` | - | 1.0 |
| `nxn_shutdown` | `void nxn_shutdown(void)` | - | 1.0 |
| `nxn_run` | `int nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params)` | - | 1.0 |
| `nxn_should_quit` | `int nxn_should_quit(void)` | - | 1.0 |
| `nxn_request_return` | `void nxn_request_return(nxn_return_reason reason, int32_t code, const char* message)` | - (`NXN_CAP_RETURN` says the OS returns) | 1.0 |
| `nxn_caps_get` | `nxn_result nxn_caps_get(nxn_caps* out)` | - | 1.0 |
| `nxn_info_get` | `nxn_result nxn_info_get(nxn_info* out)` | - | 1.0 |
| `nxn_info_string` | `const char* nxn_info_string(nxn_info_key key)` | - | 1.0 |
| `nxn_last_error` | `const char* nxn_last_error(void)` | - | 1.0 |

### 2.2 Audio (`nxn_audio.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_audio_open` | `nxn_result nxn_audio_open(const nxn_audio_params* params, nxn_audio** out)` | - | 1.0 |
| `nxn_audio_close` | `void nxn_audio_close(nxn_audio* a)` | - | 1.0 |
| `nxn_audio_pause` | `nxn_result nxn_audio_pause(nxn_audio* a, int paused)` | - | 1.0 |
| `nxn_audio_queue` | `nxn_result nxn_audio_queue(nxn_audio* a, const void* data, uint32_t bytes)` | - | 1.0 |
| `nxn_audio_queued_bytes` | `uint32_t nxn_audio_queued_bytes(nxn_audio* a)` | - | 1.0 |
| `nxn_audio_clear` | `nxn_result nxn_audio_clear(nxn_audio* a)` | `NXN_CAP_AUDIO_CLEAR` | 1.1 |
| `nxn_sfx_play` | `nxn_result nxn_sfx_play(const char* name_or_path, float volume, int32_t loops)` | `NXN_CAP_MIXER` | not stated |
| `nxn_tone` | `nxn_result nxn_tone(float freq_hz, float seconds, float volume, uint32_t wave)` | `NXN_CAP_MIXER` | not stated |
| `nxn_sfx_stop_all` | `nxn_result nxn_sfx_stop_all(void)` | `NXN_CAP_MIXER` | not stated |

### 2.3 Display and events (`nxn_display.h`, `nxn_event.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_display_open` | `nxn_result nxn_display_open(const nxn_display_params* params, nxn_display** out)` | - | 1.0 |
| `nxn_display_close` | `void nxn_display_close(nxn_display* d)` | - | 1.0 |
| `nxn_display_swap` | `nxn_result nxn_display_swap(nxn_display* d)` | - | 1.0 |
| `nxn_display_size` | `nxn_result nxn_display_size(nxn_display* d, uint32_t* width, uint32_t* height)` | - | 1.0 |
| `nxn_display_resize` | `nxn_result nxn_display_resize(nxn_display* d, uint32_t width, uint32_t height)` | `NXN_CAP_EVENTS` | 1.0 |
| `nxn_display_proc` | `void* nxn_display_proc(const char* name)` | - | 1.0 |
| `nxn_event_poll` | `int nxn_event_poll(nxn_event* out)` | `NXN_CAP_EVENTS` (resize) | 1.0 |

### 2.4 Input (`nxn_input.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_input_poll` | `nxn_result nxn_input_poll(nxn_input_state* out)` | - | 1.0 |
| `nxn_input_touch` | `nxn_result nxn_input_touch(uint32_t index, nxn_touch* out)` | - | 1.0 |
| `nxn_input_key_held` | `int nxn_input_key_held(uint32_t hid_usage)` | - | 1.0 |
| `nxn_input_key_poll` | `int nxn_input_key_poll(nxn_key_event* out)` | `NXN_CAP_USB_INPUT` | 1.1 |
| `nxn_input_text` | `int nxn_input_text(char* out, size_t cap)` | `NXN_CAP_USB_INPUT` | 1.1 |
| `nxn_input_mouse` | `nxn_result nxn_input_mouse(nxn_mouse* out)` | `NXN_CAP_USB_INPUT` | 1.1 |
| `nxn_input_text_request` | `nxn_result nxn_input_text_request(int wanted)` | `NXN_CAP_TEXT_REQUEST` | header: 1.1 add-on; kit doc: 1.2 add-on (CONFLICT, verify before use) |
| `nxn_input_action_buttons` | `nxn_result nxn_input_action_buttons(const char* action, uint64_t* mask)` | `NXN_CAP_INPUT_ACTIONS` | not stated |

### 2.5 Files (`nxn_fs.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_fs_path` | `nxn_result nxn_fs_path(nxn_dir dir, const char* rel, char* out, size_t out_size)` | - | 1.0 |
| `nxn_fs_mkdirs` | `nxn_result nxn_fs_mkdirs(nxn_dir dir, const char* rel)` | - | 1.0 |
| `nxn_fs_write` | `nxn_result nxn_fs_write(nxn_dir dir, const char* rel, const void* data, size_t bytes)` | - | 1.0 |
| `nxn_fs_read` | `nxn_result nxn_fs_read(nxn_dir dir, const char* rel, void* buf, size_t cap, size_t* read_bytes)` | - | 1.0 |

### 2.6 System (`nxn_sys.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_time_ns` | `uint64_t nxn_time_ns(void)` | - | 1.0 |
| `nxn_time_unix` | `int64_t nxn_time_unix(void)` | - | 1.0 |
| `nxn_sleep_ns` | `void nxn_sleep_ns(uint64_t ns)` | - | 1.0 |
| `nxn_thread_start` | `nxn_result nxn_thread_start(const nxn_thread_params* params, nxn_thread** out)` | - | 1.0 |
| `nxn_thread_join` | `nxn_result nxn_thread_join(nxn_thread* t)` | - | 1.0 |
| `nxn_log` | `void nxn_log(nxn_log_level level, const char* fmt, ...)` | - | 1.0 |
| `nxn_log_write` | `void nxn_log_write(nxn_log_level level, const char* message)` | - | 1.0 |
| `nxn_perm_query` | `nxn_result nxn_perm_query(const char* name, nxn_perm_state* out)` | `NXN_CAP_PERMISSIONS` | 1.1 |
| `nxn_perm_request` | `nxn_result nxn_perm_request(const char* name, nxn_perm_state* out)` | `NXN_CAP_PERMISSIONS` | 1.1 |
| `nxn_notify` | `nxn_result nxn_notify(const char* title, const char* body)` | `NXN_CAP_NOTIFY` | 1.1 |
| `nxn_clipboard_get` | `nxn_result nxn_clipboard_get(char* buf, size_t cap, size_t* len)` | `NXN_CAP_CLIPBOARD` | 1.1 |
| `nxn_clipboard_set` | `nxn_result nxn_clipboard_set(const char* text)` | `NXN_CAP_CLIPBOARD` | 1.1 |
| `nxn_rumble` | `nxn_result nxn_rumble(float strength, uint32_t ms)` | `NXN_CAP_RUMBLE` | 1.1 |
| `nxn_pick` | `nxn_result nxn_pick(const nxn_pick_params* params, char* path, size_t cap)` | `NXN_CAP_PICKER` | 1.1 |
| `nxn_grant_get` | `nxn_result nxn_grant_get(uint32_t index, char* path, size_t cap)` | `NXN_CAP_PICKER` | 1.1 |
| `nxn_grant_check` | `nxn_result nxn_grant_check(const char* path, int* granted)` | `NXN_CAP_PICKER` | 1.1 |
| `nxn_grant_revoke` | `nxn_result nxn_grant_revoke(const char* path)` | `NXN_CAP_PICKER` | 1.1 |
| `nxn_save_path` | `nxn_result nxn_save_path(char* path, size_t cap)` | `NXN_CAP_SAVEDATA` | 1.1 |
| `nxn_save_backup` | `nxn_result nxn_save_backup(const char* slot)` | `NXN_CAP_SAVEDATA` | 1.1 |
| `nxn_save_restore` | `nxn_result nxn_save_restore(const char* slot)` | `NXN_CAP_SAVEDATA` | 1.1 |
| `nxn_save_backup_get` | `nxn_result nxn_save_backup_get(uint32_t index, char* slot, size_t cap)` | `NXN_CAP_SAVEDATA` | 1.1 |
| `nxn_save_backup_delete` | `nxn_result nxn_save_backup_delete(const char* slot)` | `NXN_CAP_SAVEDATA` | 1.1 |

Version column for 2.6 rows marked 1.1 comes from the header section "system services (Native 1.1)".

### 2.7 UI and text (`nxn_ui.h`, `nxn_imgui.h`)

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_ui_tokens_get` | `nxn_result nxn_ui_tokens_get(nxn_ui_tokens* out)` | `NXN_CAP_UI_TOKENS` | 1.1 |
| `nxn_ui_font_get` | `nxn_result nxn_ui_font_get(nxn_ui_font font, const void** data, size_t* size)` | `NXN_CAP_UI_FONT_CJK` for `NXN_UI_FONT_CJK` | 1.1 (CJK font) |
| `nxn_ui_icon_code` | `uint32_t nxn_ui_icon_code(const char* name)` | - | 1.1 |
| `nxn_tr` | `const char* nxn_tr(const char* key)` | `NXN_CAP_TEXT` | 1.1 |
| `nxn_tr_format` | `nxn_result nxn_tr_format(const char* key, char* out, size_t cap, const char* const* args, uint32_t argc)` | `NXN_CAP_TEXT` | 1.1 |
| `nxn_imgui_add_font` | header helper (`nxn_imgui.h`), `nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, px, 0, icon_ranges)` | - | 1.1 (kit doc) |
| `nxn_imgui_enable_gamepad` | header helper, `nxn_imgui_enable_gamepad(io)` | - | 1.1 |

### 2.8 Menu, window, power, dialog

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_menu_set` | `nxn_result nxn_menu_set(const nxn_menu_spec* spec)` | `NXN_CAP_MENU` | 1.1 |
| `nxn_menu_clear` | `nxn_result nxn_menu_clear(void)` | `NXN_CAP_MENU` | 1.1 |
| `nxn_window_set_title` | `nxn_result nxn_window_set_title(const char* title, const char* subtitle)` | `NXN_CAP_WINDOW_CTL` | 1.2 |
| `nxn_window_set_mode` | `nxn_result nxn_window_set_mode(nxn_window_mode mode)` | `NXN_CAP_WINDOW_CTL` | 1.2 |
| `nxn_window_set_modified` | `nxn_result nxn_window_set_modified(int modified)` | `NXN_CAP_WINDOW_CTL` | 1.2 |
| `nxn_power_get` | `nxn_result nxn_power_get(nxn_power* out)` | `NXN_CAP_POWER_STATE` | 1.2 |
| `nxn_dialog` | `nxn_result nxn_dialog(const nxn_dialog_params* params, uint32_t* picked)` | `NXN_CAP_DIALOG` | 1.2 |
| `nxn_prompt` | `nxn_result nxn_prompt(const char* title, const char* message, const char* initial, char* out, size_t cap)` | `NXN_CAP_DIALOG` | 1.2 |

### 2.9 Shared libraries, JIT, memory

| Function | Signature | Cap bit | minNative |
|---|---|---|---|
| `nxn_lib_open` | `nxn_result nxn_lib_open(const char* name, const char* min_version, nxn_lib** out)` | `NXN_CAP_SHARED_LIBS` | not stated |
| `nxn_lib_sym` | `void* nxn_lib_sym(nxn_lib* lib, const char* name)` | `NXN_CAP_SHARED_LIBS` | not stated |
| `nxn_lib_close` | `nxn_result nxn_lib_close(nxn_lib* lib)` | `NXN_CAP_SHARED_LIBS` | not stated |
| `nxn_lib_error` | `const char* nxn_lib_error(void)` | `NXN_CAP_SHARED_LIBS` | not stated |
| `nxn_lib_version` / `nxn_lib_name` | `const char* f(nxn_lib* lib)` | `NXN_CAP_SHARED_LIBS` | not stated |
| `nxn_jit_create` | `nxn_result nxn_jit_create(uint64_t bytes, nxn_jit** out)` | `NXN_CAP_JIT` | not stated |
| `nxn_jit_get` | `nxn_result nxn_jit_get(nxn_jit* j, nxn_jit_info* out)` | `NXN_CAP_JIT` | not stated |
| `nxn_jit_begin_write` | `nxn_result nxn_jit_begin_write(nxn_jit* j)` | `NXN_CAP_JIT` | not stated |
| `nxn_jit_end_write` | `nxn_result nxn_jit_end_write(nxn_jit* j, uint64_t offset, uint64_t len)` | `NXN_CAP_JIT` | not stated |
| `nxn_jit_destroy` | `void nxn_jit_destroy(nxn_jit* j)` | `NXN_CAP_JIT` | not stated |
| `nxn_fault_handler_set` | `nxn_result nxn_fault_handler_set(nxn_fault_fn fn, void* user)` | `NXN_CAP_FAULT_HANDLER` | not stated |
| `nxn_mem_guard` | `nxn_result nxn_mem_guard(void* block, uint64_t offset, uint64_t len, uint32_t mode)` | `NXN_CAP_GUARD_PAGES` | not stated |

### 2.10 Events (`nxn_event.h`, `nxn_event` type)

| Constant | Value | minNative | Cap bit | Meaning |
|---|---|---|---|---|
| `NXN_EVENT_NONE` | 0 | 1.0 | - | no event |
| `NXN_EVENT_RESIZE` | 1 | 1.0 | `NXN_CAP_EVENTS` | content size changed (window or full screen) |
| `NXN_EVENT_QUIT` | 2 | 1.0 | - | close button or OS quitting; save and return soon |
| `NXN_EVENT_FOCUS` | 3 | 1.0 | - | `focused` 1 gained, 0 lost |
| `NXN_EVENT_DOCK` | 4 | 1.1 | `NXN_CAP_POWER_EVENTS` | docked (1) or undocked (0) |
| `NXN_EVENT_SUSPEND` | 5 | 1.1 | `NXN_CAP_POWER_EVENTS` | background or sleep: save, stop sound |
| `NXN_EVENT_RESUME` | 6 | 1.1 | `NXN_CAP_POWER_EVENTS` | foreground or woke up |
| `NXN_EVENT_THEME` | 7 | 1.1 | `NXN_CAP_UI_TOKENS` | OS look changed: read tokens again |
| `NXN_EVENT_MENU` | 8 | 1.1 | `NXN_CAP_MENU` | `item_id` picked |
| `NXN_EVENT_POWER` | 9 | 1.2 | `NXN_CAP_POWER_STATE` | battery, charger, dock or network changed |

### 2.11 Capability bits (`NXN_CAP_*`, `uint64_t`, `nxn_app.h`, `nxn_caps.features`)

| Bit | Name | Bit | Name |
|---|---|---|---|
| 0 | `NXN_CAP_HOSTED` | 19 | `NXN_CAP_SAVEDATA` |
| 1 | `NXN_CAP_RETURN` | 20 | `NXN_CAP_PERMISSIONS` |
| 2 | `NXN_CAP_CRASH_GUARD` | 21 | `NXN_CAP_UI_TOKENS` |
| 3 | `NXN_CAP_GL_CORE` | 22 | `NXN_CAP_TEXT` |
| 4 | `NXN_CAP_GLES` | 23 | `NXN_CAP_NEXGFX` |
| 5 | `NXN_CAP_AUDIO` | 24 | `NXN_CAP_MIXER` |
| 6 | `NXN_CAP_TOUCH` | 25 | `NXN_CAP_INPUT_ACTIONS` |
| 7 | `NXN_CAP_KEYBOARD` | 26 | `NXN_CAP_TLS` |
| 8 | `NXN_CAP_APPLET_MODE` | 27 | `NXN_CAP_CXX_EXCEPTIONS` |
| 9 | `NXN_CAP_EVENTS` | 28 | `NXN_CAP_JIT` |
| 10 | `NXN_CAP_SHARED_LIBS` | 29 | `NXN_CAP_FAULT_HANDLER` |
| 11 | `NXN_CAP_WINDOWED` | 30 | `NXN_CAP_GUARD_PAGES` |
| 12 | `NXN_CAP_AUDIO_CLEAR` | 31 | `NXN_CAP_MENU` |
| 13 | `NXN_CAP_USB_INPUT` | 32 | `NXN_CAP_UI_FONT_CJK` |
| 14 | `NXN_CAP_POWER_EVENTS` | 33 | `NXN_CAP_WINDOW_CTL` |
| 15 | `NXN_CAP_NOTIFY` | 34 | `NXN_CAP_POWER_STATE` |
| 16 | `NXN_CAP_CLIPBOARD` | 35 | `NXN_CAP_DIALOG` |
| 17 | `NXN_CAP_RUMBLE` | 36 | `NXN_CAP_TEXT_REQUEST` |
| 18 | `NXN_CAP_PICKER` | | |

Bit 31 is `NXN_CAP_MENU`; bits 32 and above are `uint64_t` masks. `NXN_CAP_WINDOWED` (bit 11) means the app runs inside the OS window. A stand-alone `.nro` lacks it, and system-service calls then return `NXN_ERR_UNSUPPORTED`.

### 2.12 Result codes (`nxn_result`, `nxn_base.h`)

| Name | Value | Meaning |
|---|---|---|
| `NXN_OK` | 0 | success |
| `NXN_ERR_INVALID` | -1 | bad argument |
| `NXN_ERR_UNSUPPORTED` | -2 | feature missing (`nxn_caps_get`) |
| `NXN_ERR_NOT_READY` | -3 | `nxn_init` not called, or object closed |
| `NXN_ERR_IO` | -4 | file system error |
| `NXN_ERR_DENIED` | -5 | refused (path outside app folders, read-only) |
| `NXN_ERR_NO_MEMORY` | -6 | out of memory |
| `NXN_ERR_TOO_SMALL` | -7 | output buffer too small (nothing truncated silently) |
| `NXN_ERR_NOT_FOUND` | -8 | not found |
| `NXN_ERR_SYSTEM` | -9 | system service failed (`nxn_last_error`) |
| `NXN_ERR_CANCELLED` | -10 | user dismissed a dialog or picker |
| `NXN_ERR_TIMEOUT` | -11 | reserved, not returned yet |
| `NXN_ERR_BUSY` | -12 | a second dialog while one is open (`nxn_dialog`, `nxn_prompt`); other calls: reserved |
| `NXN_ERR_EXISTS` | -13 | reserved, not returned yet |
| `NXN_ERR_LIMIT` | -14 | reserved, not returned yet |

Values never change. Treat an unknown negative value as a plain failure.

### 2.13 Deprecated in the Native SDK

None. No `nxn_*` function is marked deprecated in the headers. Functions are added only.

---

## 3. Rules that apply to every name above

- Script SDK: names are never removed. Behaviour changes apply only to apps whose `targetSdk` is at or above the version stated in the reference.
- New script API arrives in Lua, JavaScript, Python and C together. Squirrel and Java are frozen at SDK 1.8.
- Native: `minNative` must equal the highest version of any function you call. Older systems refuse a module that imports a missing `nxn_*` name, with a clear message.
- Script functions with `C` column `-` are not in the C header (`nexvyn.h`) under that name. Check `nexvyn.h` before using them in C.
