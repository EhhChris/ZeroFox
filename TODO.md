# ZeroFox — TODO

## Patches

- [x] **000-fix-bindgen-basic-string-view** — Applied; revisit if broken again after an ESR version bump (bindgen/libc++ compatibility issue)
- [x] **001-disable-screenshots** — macOS (`NSWindowSharingNone`), Windows (`WDA_EXCLUDEFROMCAPTURE`), JS entry points blocked; Linux GTK layer still missing
- [ ] **001-disable-screenshots (Linux)** — Add GTK-layer screenshot prevention if Linux support is added

## Patches (stubs)

- [ ] **002-disable-screenshare** — Add hard rejection in `MediaManager.cpp` for `screen`/`window`/`browser` source types; add IPC boundary check in the content → parent process path
- [ ] **003-restrict-clipboard** — Block `Clipboard::ReadText`/`WriteText` and `Document::ExecCommand` cut/copy/paste for web content in `dom/events/Clipboard.cpp` and `dom/base/Document.cpp`; add `StaticPref` for runtime control
- [ ] **004-restrict-downloads** — Block all download paths in `nsExternalHelperAppService::DoContent`, `DownloadCore.jsm`, `saveURL()`/`saveDocument()` in `browser.js`, and blob URL anchor downloads in `HTMLAnchorElement.cpp`
- [ ] **005-disable-printing** — Block `window.print()` in `nsGlobalWindowOuter::Print` and print job initiation in `nsPrintJob::Initialize`; catches print-to-PDF as a side effect
- [ ] **006-enforce-vpn** — Implement `ZeroFoxVPNCheck.cpp` with platform-specific interface detection (macOS: `getifaddrs`, Linux: `/proc/net/dev`, Windows: `GetAdaptersInfo`); hook into `nsIOService::NewChannelFromURIWithProxyFlags2`; add `about:zerofox-novpn` error page; wire network change listener to invalidate cache
- [ ] **007-ramdisk-profile** — Implement `ZeroFoxRamDisk.cpp`; hook into `XRE_main()` to create RAM disk before profile service initializes; embed `user.js` as a raw string literal in the binary; register shutdown observer and `atexit` handler for teardown

## VPN enforcement

- [ ] **Make VPN requirement configurable at build time** — Add a `mozconfig`/build flag (e.g. `--with-zerofox-vpn-interface=utun`) that bakes the expected VPN interface name or type into the binary at compile time via a `#define`. The runtime check in `ZeroFoxVPNCheck.cpp` should match against the baked-in value rather than a generic list of prefixes. This allows targeting a specific corporate VPN, WireGuard profile, etc.
- [ ] **Allow VPN requirement to be disabled at build time** — Add a flag (e.g. `--disable-zerofox-vpn-enforcement`) so the binary can be built without the VPN gate for testing/dev builds, without needing to comment out code

## Cleanup

- [ ] **Remove `zerofox-launch.sh`** — Once patch 007 is implemented, the launch script is redundant; delete it and remove all references to it in `README.md`, `patches/README.md`, and any other docs
- [ ] **Remove launch script references from README** — The "no-disk design" section and quick-start instructions currently describe the launch script approach; update to reflect that the binary handles this itself

## Platform support

- [ ] **Windows build** — Test `build.sh` on Windows (likely needs a WSL or MSYS2 adaptation); verify `fetch-esr.sh` SHA-512 check works (`certutil` instead of `shasum`); test all patches compile and link on MSVC/clang-cl
- [ ] **Make build instructions OS-agnostic** — `README.md` prerequisites and quick-start are currently macOS-centric; add a per-OS section covering macOS, Linux, and Windows (prerequisites, bootstrap commands, RAM disk mechanism, VPN interface naming conventions)
- [ ] **Linux RAM disk** — Verify the `mount` syscall approach in patch 007 works without root (user namespaces); document the `newuidmap`/`newgidmap` requirement if needed

## Branding

- [ ] **Custom icons** — Create 16/32/48/64/128/256px PNGs + `.icns` (macOS) + `.ico` (Windows); see `branding/README.md` for dimensions and `iconutil` commands
- [ ] **Brand strings** — Fill in `brand.dtd` and `brand.properties` under `browser/branding/zerofox/locales/en-US/`
- [ ] **Uncomment branding line in `mozconfig`** — Switch from nightly placeholder to `--with-branding=browser/branding/zerofox` once assets are in place
