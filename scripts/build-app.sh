#!/bin/bash
# Assemble SlimeZIP.app from the SwiftPM binary.
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
APP="$ROOT/dist/SlimeZIP.app"

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

cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$ROOT/Resources/Slime" "$APP/Contents/Resources/Slime"
cp -R "$ROOT/Resources/Brand" "$APP/Contents/Resources/Brand"

# Sign with the stable "ZipBar Dev" identity when the keychain has it.
#
# TCC ties an Accessibility grant to the signature's designated requirement.
# An ad-hoc signature has a new fingerprint every build, so each rebuild
# turned the existing grant into a dead entry: System Settings still showed
# the toggle on while AXIsProcessTrusted() read false. (This was measured
# wrongly once — running the binary from a shell attributes the check to the
# terminal host, which masked the breakage.) A certificate keeps the
# designated requirement stable, so one grant survives every rebuild.
# Ad-hoc remains the fallback so the build still works on a machine without
# the identity; distribution later needs Developer ID plus notarization.
IDENTITY="ZipBar Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
  echo "==> codesign ($IDENTITY)"
  codesign --force --sign "$IDENTITY" \
    --entitlements "$ROOT/Resources/ZipBar.entitlements" \
    --options runtime \
    "$APP" 2>&1 | sed 's/^/    /'
else
  echo "==> codesign (ad-hoc — '$IDENTITY' 인증서 없음, 권한이 리빌드마다 풀립니다)"
  codesign --force --sign - \
    --entitlements "$ROOT/Resources/ZipBar.entitlements" \
    --options runtime \
    "$APP" 2>&1 | sed 's/^/    /'
fi

echo
echo "빌드 완료: $APP"
echo "실행:      open '$APP'"
echo "진단:      '$APP/Contents/MacOS/zipbar-probe' capabilities"
