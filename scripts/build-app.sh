#!/bin/bash
# Assemble ZipBar.app from the SwiftPM binary.
#
# Works with plain Command Line Tools — no Xcode project required. Xcode is
# only needed later, for notarization (`xcrun notarytool`) and for building
# against a newer SDK than the CLT ships.
#
#   ./scripts/build-app.sh          debug build
#   ./scripts/build-app.sh release  release build
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/ZipBar.app"

cd "$ROOT"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --product ZipBar
swift build -c "$CONFIG" --product zipbar-probe

BIN_DIR="$ROOT/.build/$CONFIG"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/ZipBar" "$APP/Contents/MacOS/ZipBar"
cp "$BIN_DIR/zipbar-probe" "$APP/Contents/MacOS/zipbar-probe"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature. Enough for local runs; the Accessibility grant is tied to
# the signature, so an unsigned binary would re-prompt on every rebuild.
# Phase 5 replaces this with a Developer ID identity plus notarization.
echo "==> codesign (ad-hoc)"
codesign --force --sign - \
  --entitlements "$ROOT/Resources/ZipBar.entitlements" \
  --options runtime \
  "$APP" 2>&1 | sed 's/^/    /'

echo
echo "빌드 완료: $APP"
echo "실행:      open '$APP'"
echo "진단:      '$APP/Contents/MacOS/zipbar-probe' capabilities"
