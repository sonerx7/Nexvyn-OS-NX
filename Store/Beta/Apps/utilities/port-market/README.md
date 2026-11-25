# Port Market

Port Market is a Nexvyn OS app store for ports and apps. It reads one public catalog from the Internet Archive (`https://archive.org/download/nexvyn-port-market/catalog.json`) and lists every app with its icon, description, screenshots and version.

- **Store tab:** browse, filter by games or software, open a detail page, download the `.nxvapp` package and open the Nexvyn OS install screen. A badge shows when a newer version than the downloaded one is in the catalog. The last good catalog is saved, so the list also works offline.
- **Archive items tab:** add the ID of any Internet Archive item to list its `.nxvapp` files (for items that are not in the catalog).
- **Local tab:** reads the personal `port-market.tsv` catalog from an SD-card folder.

| ID | Version | Runtime | SDK | Permissions |
| --- | --- | --- | --- | --- |
| `com.sonerx7.portmarket` | 0.3.0 beta | Nexvyn OS JavaScript | 1.15 | Network, user-selected folder |

Navigate with touch, pointer or gamepad (D-pad moves, A selects, B goes back, L and R switch tabs). Publishing to the catalog is a separate owner-only tool and is not part of this app. See [known issues](KNOWN_ISSUES.md).

## Development

Source of truth: this folder in the private Nexvyn OS repository.

- Tests: `node --test tools/test_port_market.mjs tools/test_catalog.mjs`
- Beta package: `python tools/build_port_market_beta.py --checkout <public staging checkout> --install-local`
