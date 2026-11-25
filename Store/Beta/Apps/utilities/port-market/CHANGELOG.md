# Port Market changelog

## 0.3.1

- New Store design: a featured banner with the newest listing's screenshot and a Get button, a New row with screenshot tiles, and a card grid with large icons, a kind label, version and size. Sections have clear headers and item counts.
- Search field in the top bar (gamepad Y): matches name, subtitle, category and tags; works together with the All, Games and Software chips. Designed empty, no-results, offline and loading states.
- Detail page: dark header with a large icon and one Get, Update or Open button that shows download progress, an info strip (version, size, age, license, SDK), a screenshot carousel with arrows and page dots, and Information rows. Optional What's new notes (`whatsNew` in the catalog) are shown when present.
- Polish: hover states, a focus ring that glides between items, eased gamepad scrolling and pulsing placeholders while images load. Colors follow the system light or dark theme.
- Speed: each icon and screenshot is requested once and kept; truncated text is cached instead of measured every frame.

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
