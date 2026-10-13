#!/bin/sh
# HangyeolIME를 빌드해 ~/Library/Input Methods 에 설치한다.
#
#   Tools/build-ime.sh            # Release (평소 쓰는 빌드)
#   Tools/build-ime.sh Debug      # Debug (os_log 진단 로그가 남는다 — 입력 내용 포함)
#
# 서명은 항상 로컬 인증서(Signing.xcconfig)로 해서 손쉬운 사용 권한이 유지된다.
# 설치 뒤 실제로 뜨는지 확인하고, 안 뜨면 직전 설치본으로 되돌린다 — 입력기가 죽으면
# 그 입력 소스로는 아무것도 칠 수 없기 때문이다.
set -e
CONFIG="${1:-Release}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$HOME/Library/Input Methods/HangyeolIME.app"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

"$ROOT/Tools/setup-signing.sh"

echo "빌드: $CONFIG"
xcodebuild -project "$ROOT/HangyeolIME.xcodeproj" -scheme HangyeolIME -configuration "$CONFIG" \
  -derivedDataPath "$WORK/dd" build > "$WORK/build.log" 2>&1 || {
  grep -E 'error:' "$WORK/build.log" || tail -20 "$WORK/build.log"
  echo "빌드 실패"; exit 1
}
APP="$WORK/dd/Build/Products/$CONFIG/HangyeolIME.app"
codesign -dr - "$APP" 2>&1 | grep -q 'certificate leaf' || {
  echo "로컬 인증서로 서명되지 않았습니다(ad-hoc?). 설치하지 않습니다."; exit 1
}

if [ -d "$DEST" ]; then
  ditto "$DEST" "$WORK/backup/HangyeolIME.app"
fi
rm -rf "$DEST"
ditto "$APP" "$DEST"
pkill -x HangyeolIME || true
sleep 0.5
open -g "$DEST"
sleep 3

if pgrep -x HangyeolIME > /dev/null; then
  VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist")
  echo "설치 완료: $VERSION ($CONFIG, $(git -C "$ROOT" describe --tags --always --dirty)) — 실행 확인됨"
else
  echo "새 빌드가 실행되지 않습니다. 직전 설치본으로 되돌립니다."
  rm -rf "$DEST"
  [ -d "$WORK/backup/HangyeolIME.app" ] && ditto "$WORK/backup/HangyeolIME.app" "$DEST" && open -g "$DEST"
  exit 1
fi
