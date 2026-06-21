#!/usr/bin/env bash
# Builds PostureFix into a runnable, signed .app bundle.
#
# Usage:
#   ./build.sh [debug|release]
#
# Signing:
#   By default the app is ad-hoc signed (free, local use). Core Motion's
#   headphone-motion API works with just NSMotionUsageDescription + the TCC
#   prompt, so NO special entitlement is applied for ad-hoc builds — applying
#   the restricted `com.apple.developer.headphone-motion` entitlement with an
#   ad-hoc signature makes AMFI SIGKILL the app on launch.
#
#   For distribution, set a real Developer ID and the entitlement is applied:
#     SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="PostureFix"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
echo "› Compiling ($CONFIG)…"
swift build -c "$CONFIG"

APP_BUNDLE="$BIN_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
echo "› Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    echo "› Code signing with: $SIGN_IDENTITY (+ headphone-motion entitlement)"
    codesign --force --options runtime \
        --sign "$SIGN_IDENTITY" \
        --entitlements "$ROOT/PostureFix.entitlements" \
        "$APP_BUNDLE"
else
    echo "› Code signing (ad-hoc, no restricted entitlements)"
    codesign --force --sign - "$APP_BUNDLE"
fi

echo "✓ Built $APP_BUNDLE"
echo "  Run it with:  open \"$APP_BUNDLE\""
