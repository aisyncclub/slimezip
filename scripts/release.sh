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

echo "==> GitHub 릴리스 생성 — $TAG"
gh release create "$TAG" "$ZIP" \
  --title "SlimeZIP $TAG" \
  --notes "설치:

\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/aisyncclub/slimezip/master/scripts/install.sh | bash
\`\`\`

또는 아래 zip을 내려받아 응용 프로그램으로 옮긴 뒤,
시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 '확인 없이 열기'를 눌러 주세요."

echo "완료 — https://github.com/aisyncclub/slimezip/releases/tag/$TAG"
echo
echo "Info.plist의 버전이 바뀌었습니다. 커밋해 두세요:"
echo "  git add Resources/Info.plist && git commit -m \"버전 $VERSION\""
