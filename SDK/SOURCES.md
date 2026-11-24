# SDK sources and version identity

This folder is the public app-developer kit for Nexvyn OS. It contains application-side headers,
helpers, compatibility libraries, templates, examples, fonts and tools. The system implementation,
internal test infrastructure and unreleased architecture plans are not included.

- General callable SDK: **1.16**; native SDK: **1.2**; frozen native ABI: **v1**.
- Language/reference declarations: `Reference/SDK.md` and `Reference/c/include`.
- Native application-side sources: `Languages/c/native-kit/sdk/native`.
- Native compiler/toolchain requirements: the kit's `tools/toolchain.json` and native guides.
- AI rules and product policy: `AI/` and `Guides/`.
- Canonical locale set: `en`, `tr`, `de`, `es`, `fr`, `ja`, `ko`, `zh`.
- Fonts and third-party notices: `Fonts/` license files and the repository notices.

Check capabilities against the running host. Build each target with its appropriate toolchain.
An SDK version is not a GPU performance guarantee, an OS ABI replacement or proof of console
testing. Existing binaries retain their identity; rebuilding adopts changed app-side helpers.

Use the repository commit/release and archive SHA-256 to identify an SDK snapshot. Keep the
whole directory layout when downloading. Follow `README.md` for standalone creation and checks.
