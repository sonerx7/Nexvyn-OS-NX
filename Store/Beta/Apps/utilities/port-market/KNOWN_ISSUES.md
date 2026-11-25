# Port Market known issues

## 0.3.0

- The SDK has no streaming hash API, so the SHA-256 of a download is verified in the app only for packages up to 8 MiB. Larger packages are checked by exact size, and Nexvyn OS checks the inner manifest hash when the install screen opens the package.
- The Store tab draws its own list and detail page (nxui cannot report widget rectangles for icons and screenshots). The Archive items and Local tabs use nxui, so the tab bar looks slightly different there.
- Real catalog data from the Internet Archive was not reachable when this version was built. The Store tab was exercised against a local copy of the catalog format. Re-test against the published catalog before promoting.
- Not tested on a real console yet. Emulator timing is not console timing.

## 0.2.1

- For Internet Archive items, the first 500 file records are read. The live download and install acceptance test on the device is pending.

## 0.2.0

- For selected Internet Archive items, the first 500 file records are read. A file may not appear immediately while an upload is being processed.
- The byte count of the downloaded file is checked. The Internet Archive SHA-1 value is used in the cache identifier. Nexvyn OS checks the inner manifest when unpacking the package.
- The SDK and desktop checks are not proof of the real network/install flow on the device.

## 0.1.0

- The package path or download address is copied to the clipboard. Use the Nexvyn OS Files app for inspection and installation.
- The app checks the size of the local file. The SHA-256 value can also be shown in the catalog; full file verification is done on the desktop when the catalog is generated.
- The SDK build and static checks do not count as proof of the on-device screen layout or install flow.
