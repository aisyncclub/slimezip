#!/bin/bash
# Build a drag-to-install disk image.
#
#   ./scripts/dmg.sh v0.2.1
#
# Why a DMG when a zip already works
# ----------------------------------
# The zip makes people do three things in a row: unzip, find the app, drag it
# somewhere they have to know about. A DMG opens as one window with the app on
# the left and an Applications alias on the right, which is the gesture every
# Mac user already knows — and the window's own background can carry the one
# instruction that trips everybody up, at the exact moment they need it.
#
# It does not remove the Gatekeeper prompt. Nothing but notarisation does.
# What it does is put the fix on screen next to the thing that will fail.
set -euo pipefail

TAG="${1:-}"
[ -n "$TAG" ] || { echo "사용법: ./scripts/dmg.sh v0.2.1" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/SlimeZIP.app"
DMG="$ROOT/dist/SlimeZIP-$TAG.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -d "$APP" ] || { echo "먼저 ./scripts/build-app.sh release 를 실행하세요" >&2; exit 1; }

echo "==> 스테이징"
ditto "$APP" "$STAGE/SlimeZIP.app"
ln -s /Applications "$STAGE/응용 프로그램"

# Read before the first double-click, which is the only moment it helps.
cat > "$STAGE/먼저 읽어주세요.txt" <<'TXT'
SlimeZIP 설치

1. 왼쪽의 SlimeZIP을 오른쪽 "응용 프로그램"으로 끌어다 놓습니다.
2. 응용 프로그램에서 SlimeZIP을 엽니다.

3. 여기서 macOS가 한 번 막습니다. 앱이 손상된 게 아닙니다.
   애플 공증을 아직 받지 않아서 나오는 화면입니다.

   시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 "확인 없이 열기"

   ※ 우클릭 → 열기는 macOS 세쿼이아부터 안 됩니다.

4. 시스템 설정 → 손쉬운 사용에서 SlimeZIP을 켭니다.
   이 권한이 없으면 어느 아이콘이 어느 앱 것인지 읽을 수 없습니다.

터미널이 익숙하다면 3번을 건너뛸 수 있습니다:
  curl -fsSL https://aisyncclub.github.io/slimezip/install.sh | bash

---

Installing SlimeZIP

1. Drag SlimeZIP onto the Applications alias.
2. Open it from Applications.
3. macOS blocks the first launch — the app is not damaged, it is simply
   not notarised yet. Go to System Settings > Privacy & Security, scroll
   to the bottom, and press "Open Anyway".
   (Right-click > Open stopped working in macOS Sequoia.)
4. Turn SlimeZIP on in System Settings > Accessibility.
TXT

echo "==> 이미지 생성"
rm -f "$DMG"
# UDZO is the compressed read-only format Finder expects for a downloaded
# installer; a read-write image would let people edit the contents in place.
hdiutil create -volname "SlimeZIP" -srcfolder "$STAGE" -ov -format UDZO "$DMG" \
  | sed 's/^/    /'

echo "==> 검증"
hdiutil verify "$DMG" >/dev/null && echo "    이미지 OK"
SIZE=$(du -h "$DMG" | cut -f1)
echo "완료 — $DMG ($SIZE)"
