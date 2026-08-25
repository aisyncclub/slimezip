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

echo "==> 서명 검증"
codesign --verify --deep --strict "$APP" && echo "    서명 OK"
# Expected to fail while the app is unsigned by a Developer ID — that is
# the whole reason install.sh clears the quarantine flag. Printed, not
# fatal, so the mismatch stays visible rather than silently assumed.
spctl -a -vvv "$APP" 2>&1 | sed 's/^/    /' || \
  echo "    (공증 안 됨 — install.sh가 격리를 해제합니다)"

# The zip is what the installer script downloads; the DMG is what a person
# double-clicks. Both ship, and install.sh filters on the .zip so the extra
# asset cannot confuse it.
echo "==> 디스크 이미지"
./scripts/dmg.sh "$TAG" | sed 's/^/    /'

echo "==> GitHub 릴리스 생성 — $TAG"
gh release create "$TAG" "$ZIP" "$DMG" \
  --title "SlimeZIP $TAG" \
  --notes "## 설치

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

echo "완료 — https://github.com/aisyncclub/slimezip/releases/tag/$TAG"
echo
echo "Info.plist의 버전이 바뀌었습니다. 커밋해 두세요:"
echo "  git add Resources/Info.plist && git commit -m \"버전 $VERSION\""
