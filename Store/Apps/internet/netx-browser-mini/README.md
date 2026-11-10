# NetX-Browser Mini

A lightweight Nexvyn OS browser with tabs, bookmarks and a system keyboard. It displays desktop-oriented HTML with a subset of CSS and links to the publishers of web standards. YouTube links and searches open in the separate YousTube app. Public Netflix trailers offered by the title page play in the Nexvyn SDK player. Netflix subscription playback and arbitrary website JavaScript are unsupported.

| Field | Value |
| --- | --- |
| App ID | `com.sonerx7.nxbrowser` |
| Runtime | JavaScript |
| SDK | 1.9 minimum, 1.13 target |
| Network permission | Load web pages, styles, images and public media |
| Launch permission | Open YousTube and the Nexvyn system browser |

Select the address bar or the YouTube search shortcut to open the system keyboard. Open **Menu** for language, bookmarks and the system browser. Select **Netflix** to open the public Stranger Things title page. The trailer button appears when the page offers a compatible public stream.

| Version | Changes |
| --- | --- |
| 0.10.0 | NetX-Browser Mini name, direct YouTube handoff and public Netflix trailers with native playback controls |

The package contains the application, its own icon, and a list of web standards links. Third-party pages, covers and media are fetched from their publishers at runtime.
