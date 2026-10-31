# Nexvyn OS user guide

[Türkçe](USER_GUIDE.tr.md) · **English**

This guide is for the person who installs Nexvyn OS on their console and uses it every day. If you want to write
apps, see [DEVELOPER_GUIDE.en.md](DEVELOPER_GUIDE.en.md).

Nexvyn OS is a homebrew desktop shell for the Nintendo Switch (`NexvynOS.nro`). It does not change the console's own
system: it is opened from the Homebrew menu, and closing it returns you to the Homebrew menu. The interface is in
Turkish and English; new languages can be added.

## Contents

1. [Installation and starting](#1-installation-and-starting)
2. [Setup assistant](#2-setup-assistant)
3. [Two desktop layouts](#3-two-desktop-layouts)
4. [Windows](#4-windows)
5. [Input: touch, controller, keyboard](#5-input-touch-controller-keyboard)
6. [Desktop, folders and shortcuts](#6-desktop-folders-and-shortcuts)
7. [Files, USB drives and connecting to a computer](#7-files-usb-drives-and-connecting-to-a-computer)
8. [System Settings](#8-system-settings)
9. [Built-in apps](#9-built-in-apps)
10. [Troubleshooting and FAQ](#10-troubleshooting-and-faq)

---

## 1. Installation and starting

### Requirements

- A Switch that boots with Atmosphère. A current Atmosphère version and emuMMC are recommended.
- Some free space on the SD card. Videos, PC games and Retro games need more.

### Installation

1. Copy `NexvynOS.nro` to `sdmc:/switch/NexvynOS.nro` on the SD card.
2. Open the Homebrew menu and choose **Nexvyn OS**.
3. On the first start the setup assistant begins (see [section 2](#2-setup-assistant)).

Nexvyn OS keeps its own files in the `sdmc:/NexvynOS/` folder:

```
sdmc:/NexvynOS/
├── System/Config/       settings (settings.json)
├── System/Logs/         system and app logs
├── System/Library/      add-on fonts, languages, wallpapers, sounds
├── System/Overlay/      files that replace system files (optional)
├── Applications/        apps you installed (.nxvapp)
├── Users/<name>/        Desktop, Documents, Downloads, Pictures, Music, Movies, Library, .Trash
└── tmp/
```

### Three ways to start

How much memory Nexvyn OS gets depends on how it is opened.

| Way | How to open | Memory | Note |
|---|---|---|---|
| **Title mode** (recommended) | Hold **R** while starting a game. The Homebrew menu opens instead of the game; start Nexvyn OS from there. | Full | No extra setup. Launching Switch games, the system browser and PC games work in this mode. |
| **Applet mode** | Open the Homebrew menu from the Album and start Nexvyn OS. | Limited | Nexvyn OS shows a warning once. Large apps, the system browser and launching games are restricted. |
| **Forwarder** | Press the Nexvyn OS icon installed on the HOME menu. | Full | Needs a separate installation. Details: [FORWARDER.en.md](FORWARDER.en.md). |

The **System Settings > About > Launch mode** row shows which mode you are in: "Application (full memory)" or
"Applet (Album, limited memory)". In applet mode the same screen also shows the real memory limit.

The forwarder installation has not been tried on a real console by the Nexvyn OS team yet. Read the legal and safety
notes in the guide.

### Leaving Nexvyn OS

**Quit Nexvyn OS…** in the system menu closes Nexvyn OS and returns to the Homebrew menu. The same menu also has
**Sleep**, **Lock Screen**, **Restart Console…** and **Shut Down Console…**. Save unsaved documents first.

### In the emulator (Ryujinx)

Nexvyn OS also opens in Ryujinx. Hardware services the emulator does not have (brightness, USB, MTP, launching games,
PC games, game saves, build IDs and the like) are off there or shown as "not available".

---

## 2. Setup assistant

On the first start a welcome screen appears. Press A or touch the screen. The assistant then asks, in order:

| Step | What you choose |
|---|---|
| **Language** | The language of menus and apps. |
| **Keyboard** | The on-screen keyboard and USB keyboard layout: Turkish Q or English (US). You can try it on the same screen. |
| **Desktop layout** | Dock layout or Taskbar layout (see [section 3](#3-two-desktop-layouts)). |
| **Network** | Nexvyn OS uses the console's internet connection. Wi-Fi is set up in the console's own settings. You can continue without a connection. |
| **Recommended Programs** | Optional. See below. |
| **Account** | Your name and profile picture: your console account's picture, a picture that comes with Nexvyn OS or your own. Your home folder is created with this name. |
| **Protect your account** | "No password" or a 4–6 digit PIN. If you choose a PIN, it is asked on the lock screen. |
| **Appearance** | Light, Dark or Automatic (dark from 19:00 to 07:00), the accent color and Night Mode, which turns on every evening. |
| **Wallpaper** | The desktop behind changes as soon as you choose. |
| **Interface size** | Small, Normal or Large (separate percentages for handheld mode and TV) and large window buttons (Automatic, Always, Off). Normal is recommended for touch in handheld mode. |
| **Controller and input** | Cursor speed with the left stick, the on-screen keyboard style (docked at the bottom, floating, split) and touch vibration. |
| **More options** | Checking for updates automatically, the startup sound and apps that open automatically every time Nexvyn OS starts. |
| **Short tour** | Touch gestures, screen edges, controller buttons and keyboard shortcuts. Can be skipped with "Skip Tour". |
| **Summary** | The "Is everything ready?" screen lists all your choices. Tap the one you want to change (**Edit**), then **Back to Summary**. **Finish Setup** completes the setup. |

The steps Desktop layout, Recommended Programs, and Appearance through More options are optional: **Skip** leaves that
step's defaults as they are. If you choose a large interface size, the assistant stays a bit smaller so it fits on the
screen; the size you chose is applied as soon as setup ends.

On the last screen Nexvyn OS prepares your home folder, your settings and your desktop. It writes a short note called
"Nexvyn OS'a Hoş Geldiniz.txt" (Welcome to Nexvyn OS) on the desktop. A log of these steps is written to
`System/Logs/setup.log`.

Every choice can be changed later in **System Settings**.

### The Recommended Programs step

In this step Nexvyn OS offers to download a program for PC games: **None**, **CorkDeck (Steam library)** or
**Autorun**. None is preselected. If you make a choice, the program is downloaded from its developer's GitHub release
and installed in the last step of setup. The download size is shown on screen.

These programs are not part of Nexvyn OS; they are separate projects of their own developers. Nexvyn OS installs and
starts them. Read the [PC Games](#pc-games) section for their warnings. Later you can install, update or remove them
in **System Settings > Homebrew**.

### The Welcome Tour

When you press **Get Started** at the end of setup, the **Welcome Tour** starts on your desktop: ten short steps through
the best parts of Nexvyn OS, about two minutes in all. Each step puts a highlight on the real part of the screen and
shows a card beside it:

- **Show me**: Nexvyn OS does it for you on your own desktop. It opens three apps and snaps them to halves and a quarter
  of the screen, types two letters into Quick Search, switches to the taskbar layout and back, turns on dark mode in
  Control Center, builds an app in Studio and runs it, makes a game with the Game Engine's wizard and plays it, and
  shows the interface in Japanese for a moment.
- **Let me try**: the screen stays fully usable and the card tells you what to do. The step finishes as soon as you
  have done it.
- **Skip** goes to the next step; **×** ends the tour.

With a controller: **A** = Show me, **X** = Let me try, **B** = Skip, **+** = End tour. With a keyboard: Enter, T,
Esc and Q. Everything a demonstration changed (layout, dark mode, accent color, language, the windows it opened, the
Studio project and the game it made) is put back when its step ends. If you set **Reduce Motion**, the highlight and
the pointer of the demonstrations do not move.

The tour starts by itself only once. Take it again (it continues where you left it) from **Tips**, **Help > Take the
Tour** in the menu bar or **System Settings > About > Welcome Tour**. Erase Nexvyn OS and Reset Settings start it again
after the next setup.

---

## 3. Two desktop layouts

Nexvyn OS has two desktop layouts. Only the bars change: windows, apps and gestures work the same in both.

| | **Dock layout** | **Taskbar layout** |
|---|---|---|
| Top | Menu bar: system menu, the app's menus, battery, Wi-Fi, clock, search, Control Center | None |
| Bottom | Dock: pinned and running apps | Taskbar: Start menu, search, Window View, pinned and running apps, notification area |
| App menus | In the menu bar | In the window's title bar; also by right-clicking (or holding) the title or the taskbar button |
| Window buttons | Close / minimize / zoom at the top left | Minimize / maximize / close at the top right |

### Changing the layout

- **System Settings > Appearance > Desktop layout**
- The **Control Center > Layout** quick action
- The layout button at the bottom right corner of the screen ("Switch to Dock layout" / "Switch to Taskbar layout")
- The "Change desktop layout" action in the **Automation** app

The change applies immediately.

### Dock layout

- The Dock shows apps with a magnification effect; a running app has a dot under it.
- Right-click an app and pin it with **Keep in Dock**.
- **System Settings > Desktop and Dock**: Dock size, magnification, automatic hiding and the apps in the Dock.

### Taskbar layout

- The **Start** menu has a search field at the top and category tabs: **All**, **Pinned** and the app categories
  (Productivity, Utilities, Media, Games...). **All** shows the pinned apps and, below them, **Recommended**
  (recently opened apps and files) and **Suggested for you** (apps new from the App Market, apps you open often).
- Typing filters the apps of the current tab at once; the **Search files and settings** row continues in Quick
  Search, the last row searches the web. Enter opens the first result.
- The side panel (the button next to the search field) lists **All apps** A–Z; tap a letter to jump. Its
  **Details** tab shows the app or file under the pointer with **Open**, **Pin to Start**, **Pin to Taskbar**, **Add
  to Desktop**, **App Info** and, for installed apps, **Uninstall**. On small screens it opens as a page.
- Right click (X on the controller, a long press on touch) opens the same actions as a menu. Pinned apps can be
  moved to the front from there.
- The bottom bar: your name and picture (Users & Accounts), **Files**, **Settings** and **Power** (Lock Screen, Sleep,
  Restart Console, Shut Down Console, Restart Nexvyn OS, Quit Nexvyn OS).
- Controller: the D-pad moves between items, **L** / **R** switch tabs, **A** opens, **X** opens the menu, **B**
  closes. Keyboard: type to search, Down or Tab leaves the search field, arrows move, Enter opens, Ctrl+Tab
  switches tabs.
- The taskbar marks running apps with a short line and the focused app with a raised tile and a wide accent line.
  Hovering over a button shows live thumbnails of the windows. The clock shows the number of unread notifications.
- Right-clicking a button shows **Recent**, **New Window** and **Close All Windows**. The same menu has **Pin to
  Taskbar** / **Unpin from Taskbar**.
- **System Settings > Appearance** (with the taskbar layout chosen): **Taskbar size** (small, medium, large),
  **Taskbar buttons** ("Always combine": one button per app, "Never combine": one button per window), **Taskbar
  alignment** (centered or on the left), **Show recommended in Start**, **Show recent files in Start** and **Open
  Start with the side panel expanded**.

---

## 4. Windows

### Basic operations

- **Move:** drag by the title bar.
- **Resize:** drag an edge or a corner.
- **Maximize / Previous Size:** the maximize button or a double click on the title bar.
- **Minimize:** the minimize button or Ctrl+M.
- **Close:** the close button or Ctrl+W. Ctrl+Q closes all windows of an app.
- **Always on Top** and **Move to Desktop** are in the window menu.

In handheld mode the window buttons grow to suit touch. Change this with **System Settings > Display > Large window
buttons**: Automatic (in handheld mode), Always or Off.

### Snapping and arrangements

- Drag a window to the left or right edge of the screen: it fills half of the screen.
- Drag it to the top edge: it fills the screen.
- The arrangement menu: in the Dock layout hover over the zoom (green) button, in the Taskbar layout over the maximize
  button. The menu has **Maximize**, **Snap left**, **Snap right**, the four quarters and **Full Screen**.

### Full screen

- Ctrl+Alt+F or **Full Screen** in the arrangement menu. In full screen the title bar and the bars are hidden.
- To leave, use the **Exit full screen** button on screen or press the same shortcut.

### Opening size

Every app's window opens again at the position, size and state (normal, maximized or full screen) it had when it was
last closed.

When an app is opened for the first time it opens at normal size; games that use the controller open in full screen.
Two settings decide this first opening (**System Settings > Display**):

| Setting | Default | Effect (first opening only) |
|---|---|---|
| **Open windows at full size** | Off | New windows fill the space between the top of the screen and the Dock or taskbar. Small, fixed-size windows open at their own size. |
| **Open games in full screen** | On | Games that use the controller fill the whole screen. |

On later openings the window's last state is used, not these settings. If the window was saved at another interface
size or no longer fits on the screen, it is fitted into the work area when it opens, so it does not end up under the
Dock or the taskbar.

### Desktops and Window View

- **Window View** shows all open windows side by side. To open it: the − button, F3, Ctrl+Up arrow, a three-finger
  swipe up, or a swipe in from the left edge.
- At the top of Window View there is a strip of desktops. Add a new desktop with **+**; delete one by right-clicking
  it and choosing **Remove Desktop**.
- Switching between desktops: Ctrl+Left/Right arrow or a three-finger swipe left/right. The switch uses a cube
  animation.
- **App switcher:** the L / R buttons or Alt+Tab (Alt+Shift+Tab to go back).
- **Show desktop:** F11, Ctrl+Alt+D or a three-finger swipe down.

---

## 5. Input: touch, controller, keyboard

### Touch screen

| Gesture | Action |
|---|---|
| Tap | Clicks |
| Press and hold | Right click (context menu) |
| Two-finger swipe | Scrolls |
| Spread / pinch two fingers | Zooms in / out: Photos (picture and thumbnail size), Files (icon size), 3D Modeling, Studio's sprite and tile editors, Game Engine |
| Rotate with two fingers | Rotates the view around the target in 3D Modeling |
| Three fingers left / right | Switches between desktops |
| Three fingers down | Shows the desktop |
| Three fingers up | Opens Window View |
| Down from the top left | Notification Center |
| Down from the top right | Control Center |
| Up from the bottom | The Apps screen |
| In from the left edge | Window View |

When using touch:

- Menus and drop-down lists open with larger rows after touch input.
- Holding a button that has only an icon shows what it does.
- Lists stretch when they reach the edge; touching a scrolling list stops it.
- A long press, flipping a switch, snapping a window and starting a drag give a short, light vibration on the
  controller. Setting: **System Settings > Accessibility > Touch > Touch vibration** (Automatic: on in handheld mode;
  Always; Off).

Touching a text field opens the on-screen keyboard. The keyboard can be docked, floating (movable, resizable) or
split. A long press shows accented letters; the globe key changes the layout.

**Editing text with touch** (in text fields and editors):


| Gesture | Action |
|---|---|
| Tap | Puts the cursor there; a draggable handle appears for a few seconds |
| Double tap | Selects the word |
| Press and hold | Selects the word; selection handles and a Cut / Copy / Paste bubble appear |
| Tap the cursor | Opens the bubble (Paste, Select, Select All…) |
| Drag a handle | Grows or shrinks the selection; the text under your finger is shown in a magnifier |

**Word suggestions:** the bar above the on-screen keyboard completes the word you are typing (about 20,000 Turkish and
15,000 English words). It learns the words you type often on this device. To turn it off: **System Settings >
Keyboard and Input > Word suggestions**, or the keyboard's own menu.

### Controller

| Button | Action |
|---|---|
| Left stick | Moves the cursor |
| A | Clicks (pressing twice is a double click) |
| X | Right click |
| B | Back / closes menus and panels |
| Right stick | Scrolls |
| D-pad | Jumps between buttons (focus ring) |
| + | The Apps screen |
| − | Window View |
| ZR | Search |
| ZL | Notification Center |
| L / R | App switcher |
| Y | Opens / closes the on-screen keyboard |
| Press the left stick | Control Center |
| Press the right stick | Screenshot |

**The controller in games:** while a game that uses the controller (or an app such as Retro) is focused, the
controller goes to the game and the cursor does not move. A badge at the bottom right of the screen shows this. To get
the controller back for the cursor, **hold L+R for one second**. The one-second wait is there because of games that
press L and R together. The touch screen always works.

Cursor and scroll speed: **System Settings > Keyboard and Input > Cursor**.

### USB keyboard and mouse

You can plug a USB keyboard and mouse into the console. The mouse's right button opens the context menu. After a USB
keyboard has been used, the on-screen keyboard stays hidden.

| Shortcut | Action |
|---|---|
| Ctrl+Space | Search |
| F3 or Ctrl+Up arrow | Window View |
| F4 | The Apps screen |
| Alt+Tab / Alt+Shift+Tab | Switch between apps |
| Ctrl+Left / Right arrow | Previous / next desktop |
| F11 or Ctrl+Alt+D | Show desktop |
| Ctrl+W | Close the window |
| Ctrl+M | Minimize the window |
| Ctrl+Q | Close all of the app's windows |
| Ctrl+Alt+F | Full screen |
| Ctrl+Shift+3 | Full-screen screenshot |
| Ctrl+Shift+4 | Window screenshot |
| Ctrl+Alt+I | Invert colors |
| Ctrl+Alt+8 | Turn zoom on / off |
| Ctrl+Alt+= / Ctrl+Alt+− | Zoom in / out |
| Ctrl+/ | Shortcut list (in Code Editor and Studio it comments out the line) |
| Esc | Closes the open menu, search or panel |

Keyboard layout (Turkish Q or English US): **System Settings > Keyboard and Input**. In the same place you can choose
the console's own keyboard ("Nintendo system keyboard") instead of the on-screen keyboard.

---

## 6. Desktop, folders and shortcuts

### Desktop

- The desktop shows the `Desktop` folder in your home folder. Icons are arranged in a grid from the top left; their
  positions are saved.
- Move them by dragging. Drag on an empty spot to select several icons. Add to the selection with Ctrl and Shift.
- With the keyboard: arrows, Enter, Delete, F2 (rename), Ctrl+A/C/X/V.
- System icons: **This Console**, your user folder and the **Recycle Bin**. They can be hidden in **System Settings >
  Desktop and Dock**.

Right-clicking the desktop gives:

- **View**: large, medium or small icons; arrange icons automatically; show system icons.
- **Sort by**: name, size, item type, date modified.
- **New**: Folder, Text document, Markdown document, Lua script.
- **Paste**, **Open in Terminal**, **Add Widget**, **Change Wallpaper…**, **Personalize**.

Right-clicking an icon gives: **Open**, **Open With**, Copy, Cut, **Duplicate**, **Create Shortcut**, Rename, **Set as
Desktop Picture** (for pictures), **Move to Recycle Bin**, **Get Info**.

### Widgets

Clock, Calendar, Weather, Battery, System, Notes, Reminders, World Clock and Radio widgets can be added to the desktop.
Move them by dragging; resize or remove them with a right click.

### Folders

After the first setup the desktop has **Games**, **Tools**, **Office**, **Media** and **Switch Tools** folders,
containing shortcuts to the related apps. On an older installation the Switch Tools folder is added once; if you delete
it, it does not come back. These folders have their own icons. You can delete or rename them, or create new ones.

- **They keep up with your apps.** When you get an app from the App Market (or install a package) that belongs in one
  of these folders, its shortcut appears there; Switch tools go to **Switch Tools**. When you remove the app, the
  shortcut goes too. A shortcut you delete from such a folder does not come back.
- **They follow the language.** When you change the interface language, these folders and the shortcuts the system
  made (on the desktop and in the folders) take their names in the new language. A folder or shortcut you renamed
  yourself keeps your name. If a name is already taken by one of your files, nothing is overwritten.

### Shortcuts

- Shortcuts are `.nxvlink` files. They point to an app, a file or a folder.
- To create one: right-click an item > **Create Shortcut**. On the Apps screen, right-click an app > **Add to
  Desktop**.
- A shortcut shows its target's icon with an arrow badge. The extension is not shown.
- If you drop a file on an app shortcut, the file opens with that app.
- If the target was deleted or moved, a "Shortcut does not work" warning appears. **Open Target Location** takes you to
  the target's folder.

### Search and the Apps screen

- **Search** (ZR, Ctrl+Space): finds apps, files, settings and Automation routines; does simple calculations
  ("Calculator · select to copy") and suggests a web search.
- The **Apps** screen (+, F4, swipe up from the bottom): categories, search and pages. The grid adjusts to the screen;
  icons do not overflow the screen even at large interface sizes. Right-clicking an app shows **Add to Desktop** and
  (for apps you installed) **Uninstall**.

### Notification Center and Control Center

- **Notification Center**: the date, widgets and notifications. Empty it with **Clear All**.
- **Control Center**: Wi-Fi/IP, Do Not Disturb, Dark Mode, volume, brightness, interface size and quick actions
  (Screenshot, Keyboard, Window View, Layout).
- A warning appears when the battery drops to 20%, 10% and 5%; a notification appears when you plug in the charger.

---

## 7. Files, USB drives and connecting to a computer

### Files

The **Files** app shows the SD card and your home folder:

- Favorites and Locations in the sidebar; list and grid views.
- Drag and drop, copy/cut/paste, zip compression and extraction, the Recycle Bin (with put back).
- Double-clicking a file opens the right app. **Open With** lets you choose another app.
- A `.nxvapp` file opens the install sheet (see [App Market](#app-store-and-installing-apps)).
- An `.exe` file opens with PC Games.
- **Deleting.** Delete moves items to the Trash (Undo puts them back). **Delete Immediately**, **Empty Trash** and
  deleting on a USB drive (USB drives have no Trash) always ask first and say how many items and how much data go.
- **Same names.** When pasted or moved items are already in the folder, Files asks: **Replace**, **Keep Both** (the
  new ones get a number), **Skip** or **Cancel**. For a folder going onto a folder with the same name, **Merge** comes
  first: the new contents are added to the existing folder, and when files inside have the same names one more
  question decides for all of them. **Replace** on a folder deletes the existing folder and everything in it first;
  Files says so, with its size, before it starts.
- The status bar shows the real path of the open folder or of the selected item, for example
  `sdmc:/NexvynOS/Users/Soner/Documents/Odev.txt`.

### Where are my files?

Nexvyn OS keeps your files in your home folder on the SD card:

| In Nexvyn OS | On the SD card |
|---|---|
| Home | `sdmc:/NexvynOS/Users/<your name>/` |
| Documents | `sdmc:/NexvynOS/Users/<your name>/Documents` |
| Desktop, Downloads, Pictures, Music, Movies | the folders with these English names next to `Documents` |
| Trash | `sdmc:/NexvynOS/Users/<your name>/.Trash` (a hidden folder) |

- Nexvyn OS shows these folders in your language ("Belgeler" in Turkish), but on the card they always have their
  English names. On a computer or in another homebrew file manager, look for `NexvynOS/Users/<your name>/Documents`.
- Text Editor, Writer, Sheets, Slides, Paint and the other apps save to Documents unless you pick another folder. The
  save dialog shows the full path the file goes to under the name field; tapping a folder in its list once picks that
  folder (double-tap opens it).
- In Text Editor, **File > Show in Files** opens the document's folder with the file selected.
- The whole SD card is in Files under **This Console > SD Card** (`sdmc:/`): you can open and save anywhere on it.

### File names on the SD card

The console's own SD card driver cannot list some names with letters outside A-Z: a file called `Kuş.txt` could be
saved, and opened again by the app that saved it, yet Files and other homebrew (sphaira...) did not show it, while a
computer did. Nexvyn OS therefore writes names on the SD card with plain letters: `ş ğ ı ö ü ç` become `s g i o u c`
(`İ Ş Ğ Ö Ü Ç` likewise), `ß` becomes `ss`, other accents are dropped, other scripts become `_`, and the characters
`" * / : < > ? \ |` are replaced. The save dialog and Files say so when a name changes. USB drives keep every letter.

Files saved by an earlier version with such names are looked for the first time Files opens (among the recently used
files and in the Trash), and Files offers to repair their names so they show up again. **File > Repair File Names...**
does the same for the folder that is open.

### The console's system files

Files, Terminal, Text Editor and Code warn before they change anything that belongs to the console's custom firmware or
to other homebrew: `sdmc:/atmosphere`, `sdmc:/bootloader`, `sdmc:/Nintendo`, `sdmc:/emuMMC`, `sdmc:/switch`,
`sdmc:/config` and the boot files in the root of the card (`hbmenu.nro`, `boot.dat`, `boot.ini`, `payload.bin`,
`exosphere.ini`). Changing or deleting them can stop the console from booting. **Cancel** is the default; **I
understand, continue** goes ahead, and **Don't ask again for this session** stops the question until Nexvyn OS starts
again. Deleting, renaming, moving, pasting or saving over, new files and folders and Terminal's `rm`, `mv`, `cp`,
`touch`, `mkdir`, downloads and `>` all ask. Opening, reading and copying out of these folders never ask. The Switch
tools (Mod Manager, Cheats, Sysmodules, Overlays, Turkish Patches) write there by design and keep their own questions;
`sdmc:/NexvynOS/System` stays locked by App Guard as before.

### USB drives

- Plug a USB drive into the dock, or into the console with a USB-C adapter. A "USB drive connected" notification
  appears; tapping it opens the drive in Files.
- Supported file systems: FAT12/16/32 and exFAT. NTFS is not supported.
- Before unplugging, press the **Safely Remove** button next to the drive in Files. Unplug it when "You can now remove
  it" appears.
- USB drives do not work in Ryujinx.

### Connect to Computer

The **Connect to Computer** app lets you reach the SD card from a computer.

**Wireless (FTP):**

1. Connect the console and the computer to the same network.
2. Start the server in the app. An address (`ftp://…`) appears on screen.
3. Type this address in the address bar of the computer's file manager, or use any FTP client. The "How to connect
   from a computer" section of the app has steps for a file manager, an FTP client and a phone or tablet.

In the settings you choose the user name and password, the access area (the whole SD card or only your home folder),
read-only mode and the port. Without a password anyone on the same network can connect. FTP is not encrypted; use it
only on a home network you trust.

**USB cable (MTP):** connect the console, out of the dock, to the computer with a USB-C cable; the computer sees it like
a phone. This feature works only on a real console.

Known status: the FTP server was tried from Windows against Ryujinx; listing, folders and downloads worked, uploading
could not be tried there because of the emulator's network layer. MTP and FTP uploads still need to be confirmed on a
real console.

### FTP Client

**FTP Client** connects to another FTP/FTPS server: a site manager, a two-pane view and a transfer queue.

---

## 8. System Settings

The panes of System Settings: Wi-Fi and Network, Controllers, Notifications and Focus, Sound, Appearance, Wallpaper,
Desktop and Dock, Display, Accessibility, Battery, Lock Screen and Security, Users and Accounts, Language and Region,
Date and Time, Keyboard and Input, Storage, Apps, Homebrew, Software Update, About, Developer. The search field at the
top finds settings by name.

Notable settings:

| Setting | Where | Description |
|---|---|---|
| **Interface Size** | Display | 100%, 110%, 125%, 140% or 150%. Enlarges windows, text and buttons together. 125% or 140% is recommended for touch in handheld mode. Can also be changed from Control Center. |
| **Automatic by mode** | Display | Uses separate interface sizes for handheld mode and Dock mode (TV). The size changes by itself when you put the console in the dock. |
| **Open windows at full size**, **Open games in full screen** | Display | See [Opening size](#opening-size). |
| **Night Mode** | Display | Shifts the screen colors to warm tones. "Turn on now" or "Schedule" (start and end time), color temperature. Does not affect screenshots. |
| **Hardware video decoding (experimental)** | Display > Video | High-resolution videos play more smoothly. Turn it off if there are problems. |
| **Desktop layout**, light/dark/automatic appearance, accent color, **Reduce transparency**, **Reduce motion** | Appearance | |
| **Accessibility** | Accessibility | **Zoom** (follows the cursor), **Invert colors** (Ctrl+Alt+I), **Cursor size**. |
| **Hot Corners** | Desktop and Dock | An action for each of the four corners: Window View, Apps, Show Desktop, Notification Center, Control Center, Lock Screen, Screen Saver. It runs when you push the cursor into the corner. With touch, edge gestures are used. |
| **Screen Saver** | Desktop and Dock | Start time (or Never) and style: **3D Shapes** or **Star Voyage**. There is a preview button. |
| **PIN** | Lock Screen and Security | Adding, changing and removing a 4–6 digit PIN. |
| **Open at login** | Users and Accounts | Apps that open one after another when you log in; a "Minimized" option for each. |
| **Adding a language** | Language and Region | A new language can be added from the SD card (see below). |
| **Community app repository** | Apps | The `index.json` address the App Market lists. When empty, the default repository is used. |
| **Homebrew Programs** | Homebrew | Downloading, updating and removing the recommended homebrew programs. |
| **Software Update** | Software Update | Downloads the new Nexvyn OS version from GitHub; keeps a backup of the current version. Works only with public GitHub releases. |
| **System folder** | About | Overlay status and **Reset system updates** (see [FAQ](#resetting-the-overlay-folder)). |
| **Diagnostics**, **System logs**, **Restart Shell**, **Reset all settings** | Developer | |

### Adding a new language

Put `_meta.json` and the module `.json` files (or a single `key,en,tr,...` CSV file) into
`sdmc:/NexvynOS/System/Library/Languages/<code>/`. The language appears in **System Settings > Language and Region**.

---

## 9. Built-in apps

Nexvyn OS comes with more than 90 apps. They are all sorted into categories on the Apps screen. The highlights are
described below; the full list is in [FEATURES.md](../../README.md).

### Browser

A web browser running on Nexvyn OS's own HTML/CSS engine: tabs and a tab overview, bookmarks, history, reader mode,
downloads, forms and cookies.

- **JavaScript:** pages run JavaScript (DOM, events, fetch/XHR, localStorage). Every page has a time and memory limit.
  It can be turned off per site: **JavaScript on This Site** in the menu.
- **Passwords:** login details are saved and filled in automatically. The password store is kept encrypted on the
  device; it can be protected with an optional PIN. It is managed from the **Passwords…** menu.
- **Limits:** very large web apps (webmail, video sites, maps) need a full browser. A warning appears on those sites.
  **Open in System Browser** opens the console's own browser (restricted in applet mode); Tube is recommended for
  video sites.

### AI Chat

A chat app that works with several AI providers: Anthropic, Gemini, OpenAI, NVIDIA and OpenAI-compatible custom
servers. Answers stream in; chats are saved; Markdown is rendered.

- Add your own API key: choose the provider in the settings, **Add API key**. The key is stored encrypted on the
  device and removed with **Delete**. On a custom server the key is optional.
- Requests go directly to the provider; usage is billed to your account with the provider.
- An internet connection is required.

### Media

| App | What it does |
|---|---|
| **Video Player** | MP4, MKV, WebM, AVI, TS and others; HTTPS and HLS streams; resume where you left off; full screen. |
| **Tube** | Searching and watching YouTube, Shorts, comments, optional sign-in. See below. |
| **Radio** | Internet radio by country and genre. See below. |
| **Live TV** | IPTV with M3U playlists; ready-made iptv-org lists. Channels and streams belong to whoever provides the list. |
| **Music** | Tags, cover art, playlists. Also plays m4a/aac, wma, ac3. |
| **Photos** | Pictures, plus the screenshots and video clips in the console's Album. |

If a stream stops responding, the players do not freeze while waiting: after a while they show a network error.
Seeking in a video or changing channels does not freeze the sound even while Radio plays in the background.

### Tube

An app for searching and watching YouTube. It is not an official client; if the site changes, some parts may stop
working.

- **Browsing:** Home sections, search suggestions and filters (type, duration, date, sort order), channel pages
  (Videos, Shorts, Live, Playlists, About tabs), playlists, history. Pull down to refresh a list.
- **Watching:** speed 0.5×–2× (the pitch does not change), subtitles, chapters, tapping timestamps and links in the
  description, moving on to the next video with a countdown, background audio. In full screen a double tap seeks 10
  seconds forward or back. When you leave the watch page, the video continues in a small player.
- **Quality:** the menu shows the video's real resolutions. 1080p and above can only be chosen when the video offers an
  HLS stream; otherwise it says "Higher quality is not offered for this video". Automatic: 720p with hardware decoding
  on, 480p with it off. If high quality stutters, it falls back to standard quality.
- **Shorts:** a vertical feed. Move with swipes up / down; a tap pauses, a double tap likes (when signed in). Short
  videos play in a loop.
- **Comments:** the Popular / Newest order and replies can be read without signing in. Writing and replying to comments
  requires signing in and granting the comment permission.
- **Share:** copy the link, a "from this moment" link, or a QR code to scan with a phone.
- **Watch Later:** a local list kept on this device. Google does not share the account's Watch Later list with apps.
- **There are no downloads.** Tube does not save videos; it only plays them as streams.

**Signing in (optional).** Needed for your subscription feed, your playlists, your liked videos, liking / subscribing /
saving to a list, writing comments and notifications about new videos from your subscriptions. Tube does not use the
credentials of Google's own apps; you need to create **your own OAuth client**. It is done once, takes about 5 minutes
and is free:

1. On a computer, create a new project at console.cloud.google.com.
2. Enable "YouTube Data API v3" in **APIs & Services > Library**.
3. Configure the OAuth consent screen (Google Auth Platform): choose "External" as the audience and add your own Google
   account as a test user.
4. In **Clients**, create a new OAuth client ID; the application type must be **"TVs and Limited Input devices"**.
5. Enter the client ID and client secret on Tube's **Sign in** page (or copy the downloaded JSON file to the SD card
   and use **Import from file**).
6. Tap **Sign in with Google account**. Scan the QR code on screen with your phone or open google.com/device, enter
   the code and allow access. Your password is never typed on the console.

While the project is in "Testing" status, Google shows an unverified app warning and ends the session every 7 days;
publishing the project removes this limit. The daily API quota of 10,000 units belongs to your project. The client
details and the session token are stored encrypted on the device and sent only to Google; signing out revokes the
token.

### Radio

Plays internet radio stations from the Radio Browser community directory.

- **Favorites**, **Recently Played**, **Popular**, countries (Türkiye first) and genres in the sidebar; station search
  at the top.
- The name of the song playing (if the station sends it), favorites (star), a sleep timer (moon icon).
- It keeps playing after you close the window; if the stream drops it reconnects by itself.
- The **Radio widget** shows the playing station on the desktop: play / pause, previous and next favorite.
- Stations and streams belong to those who provide them; some streams may shut down or change. An internet connection
  is required.

### Retro

A libretro front end that plays NES, SNES, Game Boy, Game Boy Color, Game Boy Advance and Mega Drive games in a
window: library, search, favorites, recently played, save slots with pictures, rewind, fast forward, auto-resume, a
touch controller and a pause menu used with the controller, keyboard or touch.

- **Cores must be built.** Emulator cores are added to Nexvyn OS only when it is built from source
  (`tools/build_retro_cores.sh`). In a build without cores, Retro says "Emulator cores are not installed" and shows the
  build steps.
- **Games are not included.** Play only backups of cartridges you own. Nexvyn OS contains and downloads no games. Put
  your files in the `sdmc:/roms/<system>/` folders; **Create ROM Folders** creates them.

### Game Library and Homebrew

- **Game Library:** lists installed Switch games with cover, play time, size and Album pictures, and launches them.
  Launching games works only in full-memory mode (title mode or forwarder). The Steam and PC tabs show PC Games'
  library.
- **Homebrew:** lists and launches the `.nro` programs on the SD card. For this, Nexvyn OS must have been opened from
  the Homebrew menu. When a program starts, Nexvyn OS closes.

### The Modding folder

The **Modding** folder on the desktop gathers six apps for modding games. First, know this:

- **Atmosphère is required.** Mods, cheats and patches are loaded from Atmosphère's folders on the SD card
  (`sdmc:/atmosphere/contents/<Game ID>/…`). Nexvyn OS does not touch the game files themselves.
- **Changes take effect the next time the game starts.** Close the running game and start it again. (The only
  exception: the "Running game" section of Cheat Manager.)
- **Playing online with a modded game or with cheats can get your account banned.**
- These apps work only on the SD card; paths in archives that point outside the SD card are not written.
- Parts that need console services (build ID, running game, starting/stopping system modules, saves) work only on a
  real console; in the emulator they show "unknown". These apps were tried in Ryujinx and have not been confirmed on a
  real console yet. Back up your important saves and files first.

| App | What it does |
|---|---|
| **Mod Manager** | Mods per game: `atmosphere/contents`, the `sdmc:/mods` library and exefs (`.ips`) patches. Turns each mod on and off; records exactly which files it copied. Warns about conflicts for mods that change the same files. Installs from a `.zip` file or a folder, shows the files, and **Create mod** prepares an empty mod folder (romfs, exefs, README). Does not touch files that belong to Turkish Patches. |
| **Cheat Manager** | Reads cheat files (`.txt`) and points out a broken line, and tells whether they match the build ID of the installed version. Turns each cheat on and off separately (`toggles.txt`); while the game is running, the **Running game** section changes cheats immediately (only on a real console). |
| **System Modules** | Lists the background modules in `atmosphere/contents`. A **Start at boot** setting (takes effect on the next boot) and Start / Stop for modules that allow it. Do not turn off a module you do not know. |
| **Game Info** | The installed game's version, update, DLCs, Game ID, build ID, cheat file name, save data and size; system software, Atmosphère version, emuMMC / sysMMC and SD card usage. From there you can go to Cheats and Mods. |
| **Turkish Patches** | Installs, enables / disables and removes a Turkish patch zip you downloaded yourself. See below. |
| **Save Backup** | Backs up and restores game saves per user. See below. |

**Turkish Patches.** Download the patch as a `.zip` from the translation team's site (with the Browser, a computer or a
cable), then choose it with **Install from Zip**. The app finds the game and the folder layout by itself; if it cannot,
you pick the game from a list or enter the title ID. Every original file that would be overwritten is first backed up
under `sdmc:/NexvynOS/Backups/TurkcePatches`; if the backup cannot be made, nothing is installed. Disabling or removing
the patch puts the original files back. The game version the patch was made for is compared with the version on the
console; if they differ, a warning appears (the game may crash or the text may look broken). The **Patch Sites** tab
opens the teams' pages in the Browser.

The app does not download patches by itself. The patch archives have no public interface that allows other apps to use
them, and the patches belong to the translators who made them. YamaNX's code, on the other hand, is published under a
license limited to non-commercial use, so it cannot be taken into Nexvyn OS's GPL license. Details:
[TURKISH_PATCHES.en.md](TURKISH_PATCHES.en.md). Patches installed with YamaNX are recognized and can be removed.

**Save Backup.** Choose the user at the top, then **Back Up Now** on a game or **Back Up All**. Backups are written
under `sdmc:/NexvynOS/Backups/Saves/<Game>/<User>/<date>/` as a folder, or as a zip when **Compress as zip** is
selected. Be careful when restoring:

- Restoring **replaces** that user's current save. Nexvyn OS first takes the current save as an automatic safety
  backup; if this backup cannot be taken, the restore does not happen. If something goes wrong, restore the safety
  backup from the list.
- Close the game before restoring; the save of a running game cannot be opened.
- The game must have a save for that user: start the game once and save, then restore.
- A warning appears when restoring a backup taken from another user.
- Do not turn off the console until the operation finishes. For important saves, also copy the backup to a computer.

### PC Games

**PC Games** plays PC games with two separate homebrew programs. The games run inside that program, not in a Nexvyn
OS window.

| Program | What it provides |
|---|---|
| **CorkDeck** | Signs in to your Steam account and downloads the games you own to the console. Your Steam library appears in the **Steam** tab. |
| **Autorun** | Runs PC (x86/x64) games and programs with Wine, FEX and DXVK. You copy game folders into `switch/wine/drive_c`; they appear in the **PC Library** tab. |

Both use the same folder (`switch/wine`); only one of them can be installed at a time. If neither is installed, the app
shows installation cards.

**Read first:**

- **Experimental.** Both projects are experimental; many games may not work.
- **Use emuMMC.** Use CorkDeck only with emuMMC; online use carries a ban risk.
- **Make a backup.** The first setup step may install boot patches. First back up the `atmosphere` and `bootloader`
  folders on the SD card.
- **Nexvyn OS closes.** When you press Play, Nexvyn OS shows a transition screen, closes and starts the program. Save
  your open documents first.
- **No automatic return.** When you leave the game, CorkDeck or Autorun shows its own library. To return to Nexvyn OS,
  start it again from the Homebrew menu.
- **Full memory is required.** In applet mode a warning appears for PC games; use title mode.
- **First start.** CorkDeck prepares a Steam game in its own menu on the first start. Do this once from CorkDeck's own
  menu; after that the Play button opens the game directly.
- Some games run only from CorkDeck's / Autorun's HOME menu shortcut; the app says so separately.
- PC games do not work in the emulator.

To see your whole Steam library and play times, you can enter a **SteamID…** and an optional **Steam Web API Key…**
from the menu. Game details must be public in your Steam profile.

CorkDeck and Autorun are separate open-source projects of their own developers; Nexvyn OS installs and starts them and
does not contain their code. **System Settings > Homebrew** and the Homebrew section of the App Market can also install
Moonlight, JKSV and NX Activity Log.

### Automation and login items

**Automation** has two parts:

- **Routine:** actions that run in order. Actions: open an app, open a file or folder, open a web page, wait, show a
  notification, set the appearance, set the volume, set the brightness, Night Mode, change the desktop layout, set the
  interface size, change the wallpaper, show the desktop, lock the screen, close all windows, run another routine.
  Routines appear as colored tiles; they can be put on the desktop and are found in Search.
- **Automation:** ties a routine to a trigger: login, a time of day, the battery level, the charger, dock / handheld
  mode, plugging in a USB drive or an app opening.

To open just a few apps at login you do not need Automation: **System Settings > Users and Accounts > Open at login**.

### 3D Modeling

Low-poly modeling with touch, controller and keyboard: a scene hierarchy, a properties panel, adjustable primitives, a
move/rotate/scale tool with snapping, and vertex, edge and face editing (extrude, inset, merge, subdivide, normals).
64 levels of undo. `.nxv3d` projects, OBJ/STL import, OBJ+MTL/STL export and saving PNG images. Samples: a house, a
tree, a car.

### Game Engine

A 2D and 3D game-making app that children can use too (formerly Game Workshop). It is in the **Developer** group in
Apps and in the Start menu, next to Studio.

- **Game wizard:** the first card on the home screen. Pick a genre (Platformer, Adventure, Space battle, Puzzle,
  Racing 3D, Runner 3D), a world (Forest, Snow, Desert, Cave, Space, Candy land, Ocean) and a name; **Build my game!**
  prepares a game you can play right away.
- **Make a new game:** or pick a picture card (Platformer, Forest Adventure, Maze, Key Puzzle, Space, Racing 3D,
  Runner 3D, Ball Collecting 3D, Empty 2D, Empty 3D and others). **Sample games** (Cat Adventure, Penguin Adventure,
  Star Hunter, Golden Island, Robot Run) can be opened and changed; on the first change they are copied to My Games.
  Your games live in the `Documents/Oyunlarım` (My Games) folder; the green ▶ on their cards starts a game with one
  tap.
- **Guided tour:** on the first start a short tour introduces the parts of the screen; watch it again with the **Help**
  button.
- **History:** the History button in the toolbar lists the latest changes with their times; tapping one undoes
  everything done since then. The game is saved automatically ("Saved" under the title).
- **Easy mode:** drag a character, an enemy, a collectible or a block from the big buttons on the left into the scene
  (or tap a picture and then tap the scene; it works with the controller too). Tapping an object opens the behaviour
  tiles: player control, walking left and right, wandering randomly, jumping, chasing, points or counting when
  collected, losing a life on touch, has lives, says something, trampoline, finish and others. What each behaviour does
  is shown in one sentence. The big green **▶ Play** starts the game at once; the red ■ goes back to editing. Undo /
  Redo are always visible.
- **Advanced mode:** an inspector with numbers, layers, Scratch-like event blocks (each with a short description below
  it), pixel drawing and tile editors, sounds and Lua code generated from the blocks (**Convert to code**).
- **Share:** **Share as app** saves the game as `Documents/<Game>.nxvapp` and opens it in the App Installer; **Add to
  desktop** installs it and puts a shortcut on the desktop; **Open in Studio** installs the game as a Lua app and opens
  it in Studio, where you continue with code. The package works the same on another Nexvyn OS.

Details and the project format: [GAME_ENGINE_PROJECTS.en.md](GAME_ENGINE_PROJECTS.en.md).

### Showcase

A six-scene tour of what Nexvyn OS can draw and play: a procedural island, a city at night, a spiral galaxy, a physics
playground, 2D effects and a logo made of particles. All models, textures and music are generated from code while it
runs.

- A / right arrow: next scene · B / left arrow: previous · +: pause · X: statistics panel (FPS, triangles, draw calls,
  render path) · Y: music · −: quality (Automatic, Low, Medium, High).
- A free camera with the sticks or by dragging.
- At automatic quality, if the frame rate drops, the quality goes down one step. 58–60 FPS was measured in Ryujinx on
  the graphics-card path; values on a real console may differ.

### Office

| App | What it does |
|---|---|
| **Word Processor** | Documents with formatting and templates. |
| **Spreadsheet** | Formulas, charts, CSV. |
| **Presentation** | Themes, transitions and presentation mode. |

Notes, Calendar, Reminders, Contacts, Stickies, Text Editor and Clock are productivity apps too.

### Nexvyn OS Studio

A development environment for writing Lua, JavaScript and Python apps on the console: a template gallery (including
"Empty Python app" and "Snake (Python)" for Python; `.py` files open with Python highlighting), live error checking,
autocompletion, running, console output, sprite, tilemap and scene editors and package export. The AI helper in the
side panel (it works with the keys from AI Chat) answers questions; it does not change files by itself. Details:
[DEVELOPER_GUIDE.en.md](DEVELOPER_GUIDE.en.md).

### App Market and installing apps

- The **App Market** lists, downloads and updates the apps in the community repository. The SHA-256 value of every
  downloaded package is checked. The Homebrew section shows the recommended homebrew programs.
- Opening a `.nxvapp` file in Files shows the install sheet: name, author, version, size, required SDK, verification
  status and **Permissions**.
  - **Run**: opens the app once without installing it.
  - **Install**: installs it into `sdmc:/NexvynOS/Applications`. A new version of the same app is written over the old
    one; its data is kept.
- The install sheet lists the permissions an app needs (network, files outside its own folder, launching other apps,
  notifications, games). **Install** allows them; **Customize** lets you turn single ones off. An app asks again only
  when it has no stored answer, or through its own "allow" request while running.
- To uninstall: right click > **Uninstall** on the Apps screen, System Settings > Apps, or the Store.

### Others

| Group | Apps |
|---|---|
| System | Files, System Settings, System Monitor, System Information, Disk Manager, Network Tools, App Market, Homebrew |
| Developer | Terminal, Code Editor, Console (system logs), Nexvyn OS Studio, Hello SDK, Hello JS, Hello Python |
| Internet | Weather, Maps (OpenStreetMap), News (RSS), Currency, Dictionary, FTP Client |
| Tools | Calculator, Screenshot, Controller Test, Archive Manager, Fonts, Color Meter, Unit Converter, QR Code, Password Generator, Morse Code, Graph Plotter, Periodic Table, Finance Calculator, Solar System, Globe, 3D Surface, Countdown, Connect to Computer, Automation |
| Productivity | Pomodoro, Habits, Budget, Flashcards, Typing Master, Breathe, Journal, Task Board |
| Media | Drawing, Piano, Metronome, Drum Machine, Melody Studio, 3D Viewer (OBJ/STL) |
| Games | Chess, Solitaire, Minesweeper, Racer (3D), Pixel Koşu, Uzay Arenası |

---

## 10. Troubleshooting and FAQ

### Nexvyn OS says it is "running with limited memory"

You opened Nexvyn OS from the Album (applet mode). In this mode the system gives it little memory: large apps, the
system browser and launching games are restricted, and heavy pages or videos may close. The fix:

- Hold **R** while starting a game and open the Homebrew menu from there (title mode), or
- install a forwarder: [FORWARDER.en.md](FORWARDER.en.md).

The real memory limit is shown on the **System Settings > About** screen.

### Nexvyn OS crashed

- When it crashes, Nexvyn OS writes a note to `sdmc:/NexvynOS/System/Logs/crash.txt`. The first line names the app
  that was running at the moment of the crash.
- In the next session that app is not opened once at login. This way an app that crashes at startup does not bring
  Nexvyn OS down every time. The note is then kept as `crash.prev.txt`.
- When reporting a bug, attach `crash.txt` (or `crash.prev.txt`) and `system.prev.log`.

### An app showed an error

If a Lua or JavaScript app hits an error, the window shows an error screen with line numbers. **Reload** starts the app
from the beginning. The error is also written to the app's log.

### Where are the logs?

| File | Contents |
|---|---|
| `sdmc:/NexvynOS/System/Logs/system.log` | The system log of this session |
| `sdmc:/NexvynOS/System/Logs/system.prev.log` | The log of the previous session (look at this after a crash) |
| `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` | Output and errors of Lua / JavaScript apps |
| `sdmc:/NexvynOS/System/Logs/setup.log` | The setup assistant's log |
| `sdmc:/NexvynOS/System/Logs/crash.txt` | The note of the last crash |

You can read the logs on the console with the **Console** app or in **System Settings > Developer > System logs**.

### Resetting the Overlay folder

Files in `sdmc:/NexvynOS/System/Overlay/` are used instead of Nexvyn OS's built-in system files (language files,
wallpapers, system apps…). If a system change causes problems:

- **System Settings > About > System folder > Reset system updates.** The folder is moved aside as `Overlay.off` (it
  is not deleted). When Nexvyn OS restarts, the built-in files are used.
- If Nexvyn OS does not start, put the SD card in a computer and rename the `NexvynOS/System/Overlay` folder.

### Resetting the settings

**System Settings > About > Reset > Reset Settings** (the same as **Developer > Reset all settings**). Every system
setting goes back to its default and, after a restart, the setup assistant runs again with your name and language
filled in. Your files, apps and users are kept; the setup assistant keeps your home folder even if you change the name.

**Erase Nexvyn OS** (in the same place) deletes the whole `sdmc:/NexvynOS` folder, as if Nexvyn OS had just been
downloaded, and Nexvyn OS restarts into the setup assistant. Games, save data, Atmosphère, other homebrew and the
`NexvynOS.nro` file are not touched.

### The desktop looks slower when idle

This is on purpose. When nothing moves, the desktop drops to 20 frames per second and uses less CPU. On the first touch
or button press it returns to full speed at once. To turn this off, set `perf.idleThrottle` to `false` in
`System/Config/settings.json`.

### The controller is stuck in a game and the cursor does not move

**Hold L+R for one second.** Touching the screen also lets you use the cursor.

### I cannot get back to Nexvyn OS after a PC game

This is expected: CorkDeck and Autorun show their own libraries when you exit. Start Nexvyn OS again from the
Homebrew menu.

### Retro says "Emulator cores are not installed"

The `NexvynOS.nro` you are using was built without cores. The cores are built with `tools/build_retro_cores.sh` and
Nexvyn OS is rebuilt. The details are on the app's own screen.

### A website does not open or looks broken

Nexvyn OS's browser is a lightweight engine. For heavy sites use **Open in System Browser** (in full-memory mode) or
open the site's light version. For videos, try Tube.

### Software Update cannot find a version

The update check looks at the latest **public** release of the GitHub repository in the settings. If the repository is
private or no release has been published yet, no update is found. You can also copy the new `NexvynOS.nro` into
`sdmc:/switch/` by hand.
