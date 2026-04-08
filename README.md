> **Note:** This project and its scaffolding were built with AI assistance (Claude, Anthropic).
> Review all generated code and patches carefully before use in production.

# ZeroFox

A hardened Firefox ESR browser build that enforces:

- **No screenshots** — OS-level window capture prevention (macOS: `NSWindowSharingNone`, Windows: `WDA_EXCLUDEFROMCAPTURE`)
- **No screensharing** — `getDisplayMedia()` / WebRTC screen capture blocked at the C++ layer
- **No clipboard access** — Web Clipboard API and `execCommand` cut/copy/paste blocked for page content
- **No file downloads** — All download paths blocked; nothing written to persistent storage
- **No printing** — Print UI, `window.print()`, and print-to-PDF all disabled
- **VPN required** — All network connections gated on a live VPN interface; browser shows a warning and refuses to connect without one
- **RAM-only profile** — Profile directory lives on a RAM disk (`zerofox-launch.sh`); everything is erased on exit

---

## Prerequisites

- macOS (primary target) or Linux
- Xcode command line tools (macOS) or GCC/Clang (Linux)
- Python 3, Rust, Node.js (required by Firefox build system — see [Firefox build docs](https://firefox-source-docs.mozilla.org/setup/))
- ~20 GB free disk space for the source + build artifacts

Install Firefox build prerequisites:
```bash
# macOS
xcode-select --install
brew install mercurial python3 node

# The Firefox build system installs Rust automatically via mach bootstrap
```

---

## Quick start

```bash
# 1. Bootstrap the Firefox build system (first time only)
./scripts/fetch-esr.sh            # downloads & verifies Firefox ESR source
cd src/firefox-$(cat src/.esr_version)
./mach bootstrap                  # installs Rust, cbindgen, etc.
cd ../..

# 2. Implement the patch stubs in patches/ (see patches/README.md)
#    Then apply them:
./scripts/apply-patches.sh

# 3. Build
./build.sh --skip-fetch           # skip re-downloading if source is already present

# 4. Launch with ephemeral RAM profile
./scripts/zerofox-launch.sh
```

---

## Project structure

```
ZeroFox/
├── build.sh                    # Full build orchestration
├── config/
│   ├── mozconfig               # Firefox build flags & app identity
│   ├── policies.json           # Enterprise policy enforcement
│   └── user.js                 # Hardened preference overrides (injected at launch)
├── patches/
│   ├── README.md               # Patch development guide
│   ├── 001-disable-screenshots.patch
│   ├── 002-disable-screenshare.patch
│   ├── 003-restrict-clipboard.patch
│   ├── 004-restrict-downloads.patch
│   ├── 005-disable-printing.patch
│   └── 006-enforce-vpn.patch
├── scripts/
│   ├── fetch-esr.sh            # Download & verify latest Firefox ESR
│   ├── apply-patches.sh        # Apply patches with dry-run validation
│   └── zerofox-launch.sh       # Launch with RAM disk profile + VPN preflight
└── branding/
    └── README.md               # Custom icon/branding instructions
```

---

## Patch status

| Patch | Status | Notes |
|-------|--------|-------|
| 001-disable-screenshots | STUB | macOS/Windows/Linux approaches documented |
| 002-disable-screenshare | STUB | MediaManager.cpp hook approach documented |
| 003-restrict-clipboard | STUB | Clipboard.cpp + execCommand approach documented |
| 004-restrict-downloads | STUB | nsExternalHelperAppService + blob URL approach documented |
| 005-disable-printing | STUB | nsPrintJob + window.print() approach documented |
| 006-enforce-vpn | STUB | Full implementation plan: VPN detection module + nsIOService hook |
| 007-ramdisk-profile | STUB | XRE_main hook + platform RAM disk creation + embedded user.js; replaces launch script |

Each patch stub describes exactly which Firefox source files to modify and what the C++ implementation should look like. See `patches/README.md` for the workflow to convert a stub into a real patch.

---

## Defense-in-depth layers

Each restriction has multiple enforcement layers:

| Restriction | policies.json covers | C++ patch covers (policy does NOT) |
|-------------|----------------------|-------------------------------------|
| Screenshots | Firefox's own screenshot extension button | OS capture APIs (screencapture, OBS, Print Screen, etc.) seeing the window |
| Screensharing | Camera/mic permission prompts | `getDisplayMedia()` / WebRTC screen capture from JavaScript |
| Clipboard | — (prefs in user.js) | Clipboard API and `execCommand` from page JS |
| Downloads | — (no direct disable policy) | All download paths including blob URLs |
| Printing | Print menu item, Ctrl+P shortcut | `window.print()` from JavaScript, print-to-PDF |
| VPN | — | All network connections; pre-launch preflight |

All six C++ patches are required. The policies and prefs handle the surface-level UI; they do not block programmatic or OS-level bypass paths.

---

## No-disk design

Page content (images, scripts, stylesheets) never touches persistent storage:

1. `browser.cache.disk.enable = false` — HTTP cache lives in RAM only
2. `browser.privatebrowsing.autostart = true` — history/cookies/sessions in memory
3. `zerofox-launch.sh` mounts a RAM disk and points the Firefox profile at it
4. On browser exit the RAM disk is unmounted; the kernel reclaims all memory

The only data written to real disk is the ZeroFox application bundle itself.
