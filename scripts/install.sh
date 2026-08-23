#!/bin/bash
# One-line installer for SlimeZIP.
#
#   curl -fsSL https://raw.githubusercontent.com/aisyncclub/zipbar/master/scripts/install.sh | bash
#
# Downloads the latest released build, puts it in /Applications, and clears
# the download quarantine so the app opens on the first double-click.
#
# Why the quarantine step exists
# ------------------------------
# ZipBar is not notarised (that needs a paid Developer ID). macOS marks every
# downloaded file with com.apple.quarantine, and Gatekeeper refuses to launch
# an un-notarised app that carries it — the dialog claims the app is
# "damaged", which it is not. Since macOS Sequoia the old Control-click →
# Open escape hatch is gone; the only manual route left is System Settings →
# Privacy & Security → Open Anyway, with a password prompt. Clearing the
# attribute here is the same decision, made once, at the moment the user
# already chose to run this script.
#
# The trade is real and worth stating plainly: quarantine is a genuine safety
# check. Run this only because you decided to trust this project. Anyone who
# would rather not can use the manual route in docs/INSTALL.md instead.
set -euo pipefail

REPO="aisyncclub/zipbar"
APP="/Applications/SlimeZIP.app"
LEGACY="/Applications/ZipBar.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say() { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31m오류:\033[0m %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "macOS 전용입니다."

# 14.0 is the deployment target; below it the binary will not load at all.
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge 14 ] || die "macOS 14 이상이 필요합니다 (현재 $(sw_vers -productVersion))."

say "최신 릴리스 확인"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' \
  | head -1 | cut -d'"' -f4)"
[ -n "$URL" ] || die "릴리스를 찾지 못했습니다. https://github.com/$REPO/releases 를 확인해 주세요."

say "내려받는 중 — $(basename "$URL")"
curl -fL# "$URL" -o "$TMP/ZipBar.zip"

say "압축 해제"
ditto -x -k "$TMP/ZipBar.zip" "$TMP/unpacked"
# ditto's --sequesterRsrc puts a mirrored __MACOSX tree beside the bundle,
# so an unqualified find can return the wrong bundle. Take the expected
# path first and only fall back to a search that skips that tree.
SRC="$TMP/unpacked/SlimeZIP.app"
[ -d "$SRC" ] || SRC="$(find "$TMP/unpacked" -maxdepth 3 -name '*.app' \
  -not -path '*/__MACOSX/*' -print -quit)"
[ -n "$SRC" ] || die "압축 안에 앱이 없습니다."

# A running copy cannot be replaced cleanly, and the old process would keep
# drawing its status items next to the new one's.
# The executable inside the bundle is still named ZipBar, so pgrep keeps
# working across the rename. Quitting goes by bundle id rather than by
# name — AppleScript resolves names against the display name, which just
# changed, and the id is the one thing that did not.
if pgrep -x ZipBar >/dev/null 2>&1; then
  say "실행 중인 SlimeZIP 종료"
  osascript -e 'quit app id "com.zipbar.ZipBar"' 2>/dev/null || pkill -x ZipBar || true
  sleep 1
fi

say "설치 — $APP"
rm -rf "$APP"
# Installs from before the rename left a second copy under the old name;
# both would draw their own status item.
[ -d "$LEGACY" ] && rm -rf "$LEGACY" && say "이전 이름의 앱 제거 — $LEGACY"
ditto "$SRC" "$APP"

say "다운로드 격리 해제"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

say "실행"
open "$APP"

cat <<'DONE'

설치 끝. 메뉴바 오른쪽에 슬라임이 하나 생깁니다.

  다음 한 가지만 더:
  시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 SlimeZIP을 켜 주세요.
  이 권한이 없으면 어느 아이콘이 어느 앱 것인지 읽을 수 없어 목록이 비어 보입니다.

DONE
