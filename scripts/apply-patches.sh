#!/usr/bin/env bash
# apply-patches.sh — Apply all ZeroFox patches to the Firefox ESR source tree
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$ROOT_DIR/src"
PATCHES_DIR="$ROOT_DIR/patches"

VERSION_FILE="$SRC_DIR/.esr_version"
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "[apply-patches] ERROR: Run fetch-esr.sh first." >&2
    exit 1
fi

ESR_VERSION=$(cat "$VERSION_FILE")
FIREFOX_SRC="$SRC_DIR/firefox-${ESR_VERSION%esr}"

if [[ ! -d "$FIREFOX_SRC" ]]; then
    echo "[apply-patches] ERROR: Firefox source not found at $FIREFOX_SRC" >&2
    exit 1
fi

echo "[apply-patches] Applying patches to $FIREFOX_SRC"
echo "[apply-patches] Patch directory: $PATCHES_DIR"

APPLIED=0
FAILED=0

for patch_file in "$PATCHES_DIR"/*.patch; do
    [[ -f "$patch_file" ]] || continue
    patch_name="$(basename "$patch_file")"

    # Skip placeholder-only patches (marked with STUB header)
    if head -5 "$patch_file" | grep -q "^# STUB"; then
        echo "[apply-patches] SKIP (stub not yet implemented): $patch_name"
        continue
    fi

    echo "[apply-patches] Applying: $patch_name"
    if (cd "$FIREFOX_SRC" && git apply --no-index -p1 --check "$patch_file") 2>/dev/null; then
        (cd "$FIREFOX_SRC" && git apply --no-index -p1 "$patch_file")
        echo "[apply-patches]   OK: $patch_name"
        APPLIED=$((APPLIED + 1))
    else
        echo "[apply-patches]   FAILED: $patch_name" >&2
        echo "[apply-patches]   Run manually: (cd $FIREFOX_SRC && git apply --no-index -p1 $patch_file)" >&2
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "[apply-patches] Applied: $APPLIED  Failed: $FAILED"
[[ $FAILED -eq 0 ]] || exit 1
