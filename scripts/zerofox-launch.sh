#!/usr/bin/env bash
# zerofox-launch.sh — Launch ZeroFox with a RAM-backed profile directory.
#
# This script mounts a RAM disk, creates a fresh Firefox profile on it,
# injects user.js, and launches ZeroFox. On exit the RAM disk is unmounted
# and all profile data vanishes — nothing persists to disk.
#
# Usage: ./scripts/zerofox-launch.sh [--app /path/to/ZeroFox.app] [firefox args...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$ROOT_DIR/config"
SRC_DIR="$ROOT_DIR/src"

# ── Configuration ─────────────────────────────────────────────────────────────
RAMDISK_SIZE_MB=512           # Should comfortably hold a Firefox profile in RAM
RAMDISK_LABEL="ZeroFoxProfile"
ZEROFOX_APP=""                # Set via --app, or auto-detected below

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) ZEROFOX_APP="$2"; shift ;;
        *)     break ;;
    esac
    shift
done

# Auto-detect the built app if not specified
if [[ -z "$ZEROFOX_APP" ]]; then
    ESR_VERSION=$(cat "$SRC_DIR/.esr_version" 2>/dev/null || true)
    if [[ -n "$ESR_VERSION" ]]; then
        OBJ_DIR="$SRC_DIR/../zerofox-obj"
        ZEROFOX_APP="$OBJ_DIR/dist/ZeroFox.app"
    fi
    if [[ ! -d "$ZEROFOX_APP" ]]; then
        echo "[launch] ERROR: Could not find ZeroFox.app. Run build.sh first, or pass --app." >&2
        exit 1
    fi
fi

# ── VPN preflight check ───────────────────────────────────────────────────────
# Quick sanity check before even launching (the C++ patch does the authoritative
# check per-connection, but catching it here gives a clearer error message).
check_vpn() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # Look for active utun or ipsec interfaces
        if ifconfig 2>/dev/null | grep -qE "^(utun|ipsec)[0-9]+:.*flags.*UP"; then
            return 0
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        if ip link show 2>/dev/null | grep -qE "(tun|wg|ipsec)[0-9]+.*UP"; then
            return 0
        fi
    fi
    return 1
}

if ! check_vpn; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ZeroFox: No VPN detected                                    ║"
    echo "║                                                              ║"
    echo "║  ZeroFox requires an active VPN connection.                  ║"
    echo "║  Connect to your VPN and try again.                          ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

echo "[launch] VPN detected. Continuing..."

# ── Mount RAM disk ────────────────────────────────────────────────────────────
cleanup() {
    echo "[launch] Unmounting RAM disk..."
    if [[ "$(uname)" == "Darwin" ]]; then
        diskutil quiet unmount force "$RAMDISK_MOUNT" 2>/dev/null || true
    else
        umount "$RAMDISK_MOUNT" 2>/dev/null || true
        rmdir "$RAMDISK_MOUNT" 2>/dev/null || true
    fi
    echo "[launch] Done. All profile data erased."
}
trap cleanup EXIT

if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: create a RAM disk using hdiutil
    SECTORS=$((RAMDISK_SIZE_MB * 2048))  # 512-byte sectors
    RAMDISK_DEV=$(hdiutil attach -nomount "ram://${SECTORS}" | tr -d ' ')
    RAMDISK_MOUNT="/Volumes/${RAMDISK_LABEL}"
    diskutil erasevolume HFS+ "$RAMDISK_LABEL" "$RAMDISK_DEV" > /dev/null
    echo "[launch] RAM disk mounted at $RAMDISK_MOUNT (${RAMDISK_SIZE_MB} MB)"
elif [[ "$(uname)" == "Linux" ]]; then
    RAMDISK_MOUNT="/tmp/${RAMDISK_LABEL}"
    mkdir -p "$RAMDISK_MOUNT"
    mount -t tmpfs -o size="${RAMDISK_SIZE_MB}m" tmpfs "$RAMDISK_MOUNT"
    echo "[launch] tmpfs mounted at $RAMDISK_MOUNT (${RAMDISK_SIZE_MB} MB)"
else
    echo "[launch] ERROR: Unsupported OS: $(uname)" >&2
    exit 1
fi

# ── Create a fresh profile on the RAM disk ────────────────────────────────────
PROFILE_DIR="$RAMDISK_MOUNT/profile"
mkdir -p "$PROFILE_DIR"

# Inject hardened preferences
cp "$CONFIG_DIR/user.js" "$PROFILE_DIR/user.js"

# Install enterprise policies adjacent to the binary
# (policies.json is baked into the build via build.sh, but this handles dev runs)
POLICIES_DIR="$ZEROFOX_APP/Contents/Resources/distribution"
if [[ -d "$(dirname "$POLICIES_DIR")" ]]; then
    mkdir -p "$POLICIES_DIR"
    cp "$CONFIG_DIR/policies.json" "$POLICIES_DIR/policies.json"
fi

# ── Launch ZeroFox ────────────────────────────────────────────────────────────
echo "[launch] Launching ZeroFox with ephemeral RAM profile..."
echo "[launch] Profile: $PROFILE_DIR"

if [[ -f "$ZEROFOX_APP/Contents/MacOS/zerofox" ]]; then
    BINARY="$ZEROFOX_APP/Contents/MacOS/zerofox"
elif [[ -f "$ZEROFOX_APP/Contents/MacOS/firefox" ]]; then
    BINARY="$ZEROFOX_APP/Contents/MacOS/firefox"
else
    echo "[launch] ERROR: Could not find browser binary in $ZEROFOX_APP" >&2
    exit 1
fi

"$BINARY" --profile "$PROFILE_DIR" --no-remote "$@"
# cleanup() runs on exit
