#!/usr/bin/env bash
# build.sh — Orchestrate a full ZeroFox build from scratch
# Usage: ./build.sh [--skip-fetch] [--skip-patches] [--jobs N]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
CONFIG_DIR="$ROOT_DIR/config"
SRC_DIR="$ROOT_DIR/src"

SKIP_FETCH=0
SKIP_PATCHES=0
JOBS=$(sysctl -n hw.logicalcpu 2>/dev/null || nproc 2>/dev/null || echo 4)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-fetch)   SKIP_FETCH=1 ;;
        --skip-patches) SKIP_PATCHES=1 ;;
        --jobs)         JOBS="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [--skip-fetch] [--skip-patches] [--jobs N]"
            exit 0 ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
    shift
done

# ── Step 1: Fetch Firefox ESR source ─────────────────────────────────────────
if [[ $SKIP_FETCH -eq 0 ]]; then
    bash "$SCRIPTS_DIR/fetch-esr.sh"
else
    echo "[build] Skipping fetch (--skip-fetch)"
fi

ESR_VERSION=$(cat "$SRC_DIR/.esr_version")
FIREFOX_SRC="$SRC_DIR/firefox-${ESR_VERSION%esr}"
echo "[build] Firefox source: $FIREFOX_SRC"

# ── Step 2: Apply ZeroFox patches ────────────────────────────────────────────
if [[ $SKIP_PATCHES -eq 0 ]]; then
    bash "$SCRIPTS_DIR/apply-patches.sh"
else
    echo "[build] Skipping patches (--skip-patches)"
fi

# ── Step 3: Install build configuration ──────────────────────────────────────
echo "[build] Installing mozconfig..."
cp "$CONFIG_DIR/mozconfig" "$FIREFOX_SRC/.mozconfig"

# Append job count to mozconfig
echo "mk_add_options MOZ_MAKE_FLAGS=\"-j${JOBS}\"" >> "$FIREFOX_SRC/.mozconfig"

# ── Step 4: Install enterprise policies ──────────────────────────────────────
# policies.json goes into distribution/ inside the build; install it into source
# so it gets picked up at build time.
DIST_DIR="$FIREFOX_SRC/browser/app/distribution"
mkdir -p "$DIST_DIR"
cp "$CONFIG_DIR/policies.json" "$DIST_DIR/policies.json"
echo "[build] Installed policies.json to $DIST_DIR"

# ── Step 5: Run the Firefox build ────────────────────────────────────────────
echo "[build] Starting Firefox build (this will take 30–90 minutes)..."
cd "$FIREFOX_SRC"
./mach build

echo ""
echo "[build] Build complete."
echo "[build] Run artifact: $(./mach run --dry-run 2>/dev/null | head -1 || true)"
echo "[build] To run: cd $FIREFOX_SRC && ./mach run"
