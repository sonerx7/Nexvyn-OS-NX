# Security policy

## Supported versions

Security fixes go into the newest stable release of Nexvyn OS and the current SDK. Beta releases (pre-releases) are
for testing and get fixes through the next build. Please update with **System Settings > Software Update** before you
report.

| Version | Supported |
|---|---|
| Newest stable release (see [Releases](https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest)) | yes |
| Older releases | no; please update |
| Beta pre-releases | through the next beta or stable release |

## Reporting a vulnerability

Please **do not open a public issue, discussion or pull request** for a security problem.

1. Use GitHub's private vulnerability reporting: the **Security** tab of this repository, then **Report a
   vulnerability**. Only the maintainer sees the report.
2. If that button is not available to you, contact the maintainer through the
   [GitHub profile](https://github.com/sonerx7) and ask for a private channel. Do not include details in a public
   message.

Please include:

- the Nexvyn OS version (**System Settings > About**), the system version and the Atmosphère version;
- what an attacker can do, and what they need for it (a crafted package, a web page, a network position, access to
  the console);
- steps to reproduce, and a proof of concept if you have one;
- relevant lines from `sdmc:/NexvynOS/System/Logs/system.log`, with personal data removed.

## What is in scope

- Nexvyn OS itself (`NexvynOS.nro`): the permission system and app sandbox, App Guard, package installation and
  signature checks, the updater, the encrypted password and key stores, the browser, network and file handling.
- The App Market as served from this repository: `Store/catalog.json`, `Store/packages.json`, package hashes and
  signatures.
- The SDK tools in `SDK/Tools/` and `Tools/`.

Out of scope here: problems in apps or games published by other makers (use **Report This App** on the store page or
the [report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml)), in Atmosphère, in the
console's own system or in other homebrew.

## What happens next

The maintainer confirms the report, works on a fix in private and agrees with you on when the details are published,
normally together with the release that fixes it. Credit is given in the release notes if you want it. Please give
the fix time to reach users before you publish anything.

Research done in good faith, on your own console and data, within this policy, is welcome. Do not access other
people's data, do not degrade the App Market or update service for others, and do not publish packages that exploit
the problem.
