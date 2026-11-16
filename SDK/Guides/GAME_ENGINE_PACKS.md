# Game Engine asset packs

An asset pack is a folder of GLB models, PNG textures and OGG sounds with one `manifest.json` that lists every file
with its size and sha256. The Game Engine installs packs into `Documents/Game Engine/Packs/<id>/` on the SD card and
keeps them apart from projects, so a pack can be updated, verified or removed without touching a game.

## Folder layout

```
<id>/
  manifest.json
  LICENSE.txt            optional, listed in files; named in license.text
  models/wall_a.glb
  tex/stone.png
  audio/door.ogg
```

## manifest.json

```json
{
  "format": "nexvyn-assetpack",
  "formatVersion": 1,
  "id": "viking-kit",
  "version": "1.2.0",
  "category": "environment",
  "name": { "en": "Viking Kit", "tr": "Viking Seti" },
  "license": { "id": "CC0-1.0", "text": "LICENSE.txt", "author": "...", "source": "https://..." },
  "files": [
    { "path": "models/wall_a.glb", "sha256": "<64 lower-case hex>", "size": 48213, "type": "glb" }
  ],
  "totalSize": 48213,
  "pieces": [
    { "id": "wall_a", "file": "models/wall_a.glb", "kind": "model", "name": { "en": "Wall A" } }
  ],
  "depends": [ { "id": "base-textures", "minVersion": "1.0" } ]
}
```

| Field | Rule |
|---|---|
| `format`, `formatVersion` | `nexvyn-assetpack`, `1`. A later format version is refused, never guessed. |
| `id` | letters, digits, `.` `-` `_`; 1-64 characters; no `..`; no leading dot. It is the folder name. |
| `version` | `1`, `1.2` or `1.2.3`, optional `-tag` (`1.2.0-beta.1` is older than `1.2.0`). |
| `category` | `environment`, `props`, `characters`, `audio`, `textures`, `ui`, `kit`, `other`. |
| `name` | a string or a map of language code to text (`en` is the fallback). |
| `license` | object; `id` (for example an SPDX id) is required. `text`, if given, must be a listed file. |
| `files` | 1-5000 entries. `path`, `sha256`, `size` (whole bytes, at most 256 MiB each). `type` is optional and must equal the extension. |
| `totalSize` | required; equals the sum of the file sizes; at most 2 GiB. |
| `pieces` | optional. Each piece names a listed file; `kind` is `model`, `texture`, `sound` or `other`. |
| `depends` | optional, at most 64. Informational for the panel; a missing dependency never blocks an install. |

Allowed extensions: `glb png ogg ktx json txt`. Anything else is refused.

### Path safety

Every `path` (and `license.text`, piece `file`) must be a relative path made of normal segments. These are refused
with `bad_path`: an empty path, a leading `/`, a drive letter or any `:`, a backslash, an empty segment (`a//b`), a `.`
or `..` segment, a control character, a path longer than 240 bytes. The same rule guards `pack://<id>/<path>` links and
every file the downloader or importer writes, so a hostile manifest cannot write outside the pack folder.
Paths are compared case-insensitively for duplicates (`dup_file`), because the SD card is FAT.

## Error codes

Manifest: `too_large` `bad_json` `bad_format` `bad_id` `bad_version` `bad_category` `bad_license` `bad_files`
`bad_path` `bad_ext` `dup_file` `bad_sha256` `bad_size` `file_too_big` `size_mismatch` `pack_too_big` `bad_piece`
`missing_piece_file` `dup_piece` `bad_depends`. The first failing check in that order is reported; the runtime returns a specific error rather than importing partial content.

Folder: `no_manifest` `missing_file` `bad_size` `bad_hash` `id_mismatch` `same_folder` `io`.
Download: `net` `http_<status>` `no_space` `cancelled` `manifest_<code>` `id_mismatch` `bad_hash` `bad_size` `io`.

## Installed packs

The editor pack panel shows every folder under `Packs/`. A sound pack has a valid manifest whose id equals the folder name
and every file present with the listed size (the quick check). A damaged one is listed with its error and can be
deleted; it never stops the editor, a game or the OS. **Verify** in the panel hashes every file (the deep check).

`Store::resolve(id, path)` and `resolveUri("pack://id/path")` return the SD path of a listed file, or an empty string
when the pack or file is missing, unlisted, damaged (size differs) or the path is unsafe. A scene that gets an empty
result draws the "Missing asset" placeholder instead of failing.

Install and update never leave a half pack: files are written into `.new-<id>`, checked, then the old version is moved
to `.old-<id>`, the new one is moved in and the old one deleted. If a step fails the old version is moved back.
`recover()` settles an interrupted swap at the next start (a sound `.old-<id>` is restored, the rest is removed).

## Getting packs

Setting `gameengine.packs.catalog` (Project tab, Asset Packs) is empty by default: nothing public is offered. It can be:

- an `http(s)://` link to a `packs.json`;
- a folder on the SD card that holds `packs.json`, one pack (`manifest.json`), or several pack folders;
- a `packs.json` file on the SD card.

```json
{ "format": "nexvyn-assetpack-catalog",
  "packs": [ { "id": "viking-kit", "version": "1.2.0", "category": "environment", "name": { "en": "Viking Kit" },
               "size": 48213, "base": "packs/viking-kit" } ] }
```

`base` is a folder or URL that holds `manifest.json` and the files at their manifest paths. A relative `base` is
resolved against the catalog's location. An http(s) `base` is downloaded; a local `base` is imported (copied and
hashed). **Import** also takes any folder with a `manifest.json` typed into the panel.

### Download

One download runs at a time on its own thread. The main thread never touches the network or the files.

1. `manifest.json` is fetched and validated; its id must match the request.
2. Space check: the missing bytes plus 5 % plus 16 MiB must fit on the SD card, else `no_space` before any file is written.
3. Files go to `.dl-<id>/` next to the store, in 1 MiB ranged requests (`Range: bytes=a-b`). A file is kept as
   `<path>.part` until its sha256 matches, then renamed. A server that ignores `Range` and sends the whole file with
   `200` is accepted when the body is exactly the file.
4. Pause stops requests after the chunk in flight; resume continues. A failed download (lost connection, 5xx after 3
   tries) keeps `.dl-<id>/`: the next start asks only for the missing bytes. Cancel deletes it. A bad hash deletes just
   that file and fails with `bad_hash`.
5. When every file matches, the folder is installed with the swap above. The installed version is untouched until then.

## Not in this step

Loading `pack://` paths in `g3d.loadModel` and in scenes (the resolver is ready), compressed textures (WP2), the pack
build pipeline (WP3) and the Store catalog kind for packs.
