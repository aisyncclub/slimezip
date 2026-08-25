#!/bin/bash
# Cut a SlimeZIP release: build, zip, publish to GitHub Releases.
#
#   ./scripts/release.sh v0.1.0
#
# The zip this produces is what scripts/install.sh downloads, so the two
# have to agree on one thing: the archive must contain SlimeZIP.app at its
# top level.
set -euo pipefail

TAG="${1:-}"
[ -n "$TAG" ] || { echo "사용법: ./scripts/release.sh v0.1.0" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/dist/SlimeZIP.app"
ZIP="$ROOT/dist/SlimeZIP-$TAG.zip"
DMG="$ROOT/dist/SlimeZIP-$TAG.dmg"

# The tag is the version. Left to a hand-edited plist it drifts — three
# releases shipped while Info.plist still said 0.1.0, and the app's own
# welcome page reported that stale number to the user.
VERSION="${TAG#v}"
PLIST="$ROOT/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $((BUILD + 1))" "$PLIST"
echo "==> 버전 $VERSION (빌드 $((BUILD + 1)))"

echo "==> release 빌드"
./scripts/build-app.sh release

[ -d "$APP" ] || { echo "빌드 결과가 없습니다: $APP" >&2; exit 1; }

# ditto --keepParent, not `zip`: it preserves the bundle's symlinks,
# resource forks and the code signature. A plain `zip -r` mangles all
# three and the app fails its own signature check on the other side.
echo "==> 압축 — $(basename "$ZIP")"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# ── Notarisation ──────────────────────────────────────────────────────
#
# Apple has to see the build and say it found no malware. Only a Developer ID
# signature can be submitted, and only a stapled build opens without the
# "unidentified developer" stop — stapling writes the ticket into the bundle
# so the check works offline.
#
# Order matters and is easy to get wrong: notarise the zip, staple the .app,
# and only then build the zip and the DMG that ship. Stapling changes the
# bundle, so anything packaged before it carries no ticket.
#
# Skipped, loudly, when there is no Developer ID certificate or no stored
# credentials. A release that quietly ships unnotarised looks identical to one
# that was notarised until a stranger tries to open it.
NOTARY_PROFILE="${NOTARY_PROFILE:-slimezip}"
DEVID="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)"

if [ -z "$DEVID" ]; then
  echo "==> 공증 건너뜀 — Developer ID 인증서가 없습니다"
  echo "    준비 방법: docs/NOTARIZE.md"
elif ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "==> 공증 건너뜀 — '$NOTARY_PROFILE' 자격증명이 저장돼 있지 않습니다"
  echo "    준비 방법: docs/NOTARIZE.md"
else
  echo "==> 공증 제출 (보통 5분 이내)"
  xcrun notarytool submit "$ZIP" \
    --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | sed 's/^/    /'

  echo "==> 티켓 첨부"
  xcrun stapler staple "$APP" 2>&1 | sed 's/^/    /'

  # The zip made before stapling has no ticket in it.
  echo "==> 압축 다시"
  rm -f "$ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
  NOTARIZED=1
fi

echo "==> 서명 검증"
codesign --verify --deep --strict "$APP" && echo "    서명 OK"
# Expected to fail while the app is unsigned by a Developer ID — that is
# the whole reason install.sh clears the quarantine flag. Printed, not
# fatal, so the mismatch stays visible rather than silently assumed.
if spctl -a -vvv "$APP" 2>&1 | sed 's/^/    /' | grep -q "Notarized Developer ID"; then
  echo "    ✅ 공증됨 — 받아서 두 번 누르면 바로 열립니다"
else
  echo "    ⚠️  공증 안 됨 — 처음 열 때 시스템 설정을 한 번 거쳐야 합니다"
fi

# The zip is what the installer script downloads; the DMG is what a person
# double-clicks. Both ship, and install.sh filters on the .zip so the extra
# asset cannot confuse it.
echo "==> 디스크 이미지"
./scripts/dmg.sh "$TAG" | sed 's/^/    /'
if [ "${NOTARIZED:-0}" = "1" ]; then
  xcrun stapler staple "$DMG" 2>&1 | sed 's/^/    /'
fi

# What the notes say depends on what actually shipped.
if [ "${NOTARIZED:-0}" = "1" ]; then
  NOTES="## 설치

**\`.dmg\`를 받아 두 번 누르세요.** 창이 열리면 슬라임을 오른쪽 \"응용 프로그램\"으로
끌어다 놓으면 끝입니다.

애플 공증을 받았으므로 경고 없이 바로 열립니다.

마지막으로 **시스템 설정 → 손쉬운 사용**에서 SlimeZIP을 켜 주세요. 이 권한이 없으면
어느 아이콘이 어느 앱 것인지 읽을 수 없어 목록이 비어 보입니다.

터미널이 익숙하다면:

\`\`\`bash
curl -fsSL https://aisyncclub.github.io/slimezip/install.sh | bash
\`\`\`

---

## Install

Download the **\`.dmg\`**, open it, and drag the slime onto Applications.
Notarised by Apple, so it opens with no warning. Then turn SlimeZIP on in
**System Settings → Accessibility**."
else
  NOTES="## 설치

**\`.dmg\`를 받아 두 번 누르세요.** 창이 열리면 슬라임을 오른쪽 \"응용 프로그램\"으로
끌어다 놓으면 됩니다. 창 안의 안내문에 그다음 단계가 적혀 있습니다.

처음 열 때 macOS가 한 번 막습니다 — 앱이 손상된 게 아니라 공증을 아직 받지 않아서입니다.
**시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 '확인 없이 열기'**를 누르면 됩니다.
(우클릭 → 열기는 세쿼이아부터 안 됩니다.)

터미널이 익숙하다면 그 단계를 건너뜁니다:

\`\`\`bash
curl -fsSL https://aisyncclub.github.io/slimezip/install.sh | bash
\`\`\`

---

## Install

Download the **\`.dmg\`**, open it, and drag the slime onto Applications.
macOS blocks the first launch because the app is not notarised yet — go to
**System Settings → Privacy & Security → Open Anyway**. From a terminal you can
skip that step with the one-liner above."
fi

echo "==> GitHub 릴리스 생성 — $TAG"
gh release create "$TAG" "$ZIP" "$DMG" \
  --title "SlimeZIP $TAG" \
  --notes "$NOTES"

echo "완료 — https://github.com/aisyncclub/slimezip/releases/tag/$TAG"
echo
echo "Info.plist의 버전이 바뀌었습니다. 커밋해 두세요:"
echo "  git add Resources/Info.plist && git commit -m \"버전 $VERSION\""
