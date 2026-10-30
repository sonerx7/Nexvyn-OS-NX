# App Guard

App Guard keeps apps from the SD card away from your private data and tells you, before you install an app, when its
code looks like it could harm you. It is small on purpose: one sandbox rule that always applies, one static scan that
runs only when you install something or ask for it, and a lock on the system files. It never runs in the background on
a schedule and costs nothing while you use the console.

> Türkçe: [APP_GUARD.tr.md](APP_GUARD.tr.md)

## 1. Protected folders (always on)

Apps installed on the SD card (`sdmc:/NexvynOS/Applications`) work in a file sandbox. With the `files` permission they
may use your documents and the rest of the SD card, but some folders stay closed to them **even with that
permission**:

| Folder | What lives there |
|---|---|
| `sdmc:/NexvynOS/System` (except `System/Library` and `System/Fonts`) | settings, users and PIN, permissions, signers, logs, the Overlay |
| `sdmc:/NexvynOS/Applications/<other app>` | other apps' code |
| `~/Library` outside the app's own `Application Support/<id>` and `Caches/<id>` | other apps' data: the Browser's cookies, history and saved passwords, the AI Chat keys, FTP passwords, the Tube account, the words the keyboard learned |
| `sdmc:/NexvynOS/Users/<another user>/Library` | another user's app data |
| `sdmc:/NexvynOS/Users/<another user>` | another user's files: only a file you picked in a file dialog |

Paths are compared the way the SD card compares them (letter case, `..`, `\`, trailing dots), so another spelling of
the same folder is refused too. A refused path comes back empty to the app, and its log
(`System/Logs/Apps/<id>.log`, readable in Files) says `protected path: ...` once. Built-in apps are not affected.

## 2. Checking an app before it is installed

**App Installer** (opening a `.nxvapp` file): while the sheet is open, App Guard reads the package's text sources
(`.lua`, `.js`, `.py`, `.nut`, `.c`, `.java`, `.json`) on a background thread and shows a card:

- **No issues found**: nothing suspicious (there may be notes behind *Show Details*).
- **Review**: something worth a look, for example an app that writes `.nro` files or builds code while it runs.
- **Dangerous**: code that could harm you or your data. *Install* becomes **Install Anyway** (and *Run* becomes
  **Run Anyway**), which asks once more and lists the reasons.

**App Market**: the permission sheet says **Reviewed by Nexvyn OS** for apps from the store's own catalog. Every
download is scanned the same way before it is installed; a Dangerous one waits for **Install Anyway**.

Turn this off with *System Settings > Privacy & Permissions > App Guard > Scan apps before installing*.

### What the scan looks for

| Finding | Level |
|---|---|
| Paths to Nexvyn OS's private data or other apps' data, with the network permission ("could send your data") | Dangerous |
| The same without the network permission | Review |
| The console's key files (`prod.keys`, `title.keys`), with / without the network permission | Dangerous / Review |
| Custom firmware, bootloader or `.nro` files, the Overlay, other apps' folders | Review |
| Code that is downloaded and run (`net.*`, `fetch`, `urlopen` fed to `load`, `eval`, `Function`, `exec`) | Dangerous |
| Code decoded from an encoded blob inside `load` / `eval` / `exec` (base64, hex, escapes) | Dangerous |
| A long encoded blob next to dynamic code; Lua `string.dump` | Review |
| Typed text (`e.text`, `e.key`) collected in an app that uses the network | Review |
| A raw socket to a port web services do not use (CPython apps) | Review |
| Dynamic code in an app with the network permission | Review |
| Dynamic code without the network, a permission the code never uses, a bundle without a permissions list, code App Guard cannot read (a jar, a native module, `.pyc`), files too large to read | Note |
| The package's hash is on the App Market's blocklist | Dangerous |

A static check reads intent, not behaviour: it can miss things, and a "No issues found" is not a promise. The
protected folders above are what really keep your data safe.

### The blocklist

The App Market catalog may name known-bad packages by their SHA-256 (`security.blocklist`,
[NXVAPP_FORMAT.en.md](NXVAPP_FORMAT.en.md) section 6). App Guard reads it from the catalog the App Market cached last
and shows a listed package as Dangerous, before installing and among the installed apps (Nexvyn OS remembers the hash
of the package each app was installed from).

**App Guard only warns.** It never turns off, removes or blocks an app, and nothing from the internet can make it.
You decide.

## 3. Checking the installed apps

*System Settings > Privacy & Permissions > App Guard > Scan installed apps* checks every app on the SD card and lists
each one with its level. *Show Details* lists the findings (file and line), *Permissions* jumps to the app's
permission switches below, *Uninstall* removes it. Nothing is scanned until you press **Scan**.

## 4. System files are read-only

Files Nexvyn OS manages, `sdmc:/NexvynOS/System` except the add-on folders `Library` (fonts, languages, wallpapers,
sounds) and `Fonts`, can be opened and copied but not changed:

- **Files** shows a lock and "System file — managed by Nexvyn OS"; rename, move, delete, paste and new items are off.
- **Terminal** refuses `touch`, `mkdir`, `rm`, `rmdir`, `cp` into it, `mv` into or out of it, `>` redirects and
  downloads into it (`cp` out of it works).
- The file dialogs do not save there; **Text Editor** and **Code Editor** open such files read-only (Save As still
  works).

Developers can lift the lock with *System Settings > Developer > Allow system edits* (off by default). Nexvyn OS's own
settings and logs are written as usual either way.

## 5. Settings keys

| Key | Default | Meaning |
|---|---|---|
| `appguard.scanBeforeInstall` | `true` | scan packages on the install sheets and App Market downloads |
| `developer.allowSystemEdits` | `false` | Files, Terminal and the editors may change `sdmc:/NexvynOS/System` |

The hashes of installed packages are kept in `sdmc:/NexvynOS/System/Config/appguard.json`.
