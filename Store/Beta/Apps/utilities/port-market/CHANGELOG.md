# Port Market changelog

## 0.3.0

- New Store tab: reads the Port Market catalog from the Internet Archive and lists apps and ports with icon, name, subtitle, version and size. All, Games and Software filters.
- Detail page with description in the system language, screenshots (previous and next), SDK and license info, download with progress and an install-screen button. The source link can be copied.
- Update badge when the downloaded version is older than the catalog version.
- Saves the last good catalog, refreshes it every five minutes and works offline. Invalid catalog entries are skipped, never the whole catalog.
- Downloads go to `downloads/<item>/<version>/` and are checked by size, and by SHA-256 for packages up to 8 MiB.
- Archive items and Local tabs are unchanged. Development moved to the private Nexvyn OS repository.

## 0.2.1

- Opens per-game and per-software subfolders in the local library. Can still read the old flat catalogs.

## 0.2.0

- Refreshes the version list directly from the Internet Archive items the user has saved.
- SDK network download, progress, file size check and a system package inspection screen.
- Moved to the SDK JavaScript runtime. Personal SD folder support continues.

## 0.1.0

- Native beta. Game and software filters, version, size and SHA-256 information in the personal library on the SD card.
- Link to the local package path and to Internet Archive packages that have distribution permission.
- SDK theme, resizing, gamepad/keyboard/touch and eight languages.
