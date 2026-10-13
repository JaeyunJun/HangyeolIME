#!/bin/sh
# GitHub 릴리스를 만든다. 릴리스 노트는 CHANGELOG.md의 "## [버전]" 절이다.
#
#   Tools/release.sh 2.1.0-alpha.1          # 지금 커밋(HEAD)에 태그·릴리스
#   Tools/release.sh 2.1.0 <커밋>           # 지정한 커밋에 (써 보고 문제없던 alpha를 정식으로 올릴 때)
#
# 버전에 '-'가 있으면(2.1.0-alpha.1) pre-release, 없으면 정식이자 최신 릴리스가 된다.
# 규칙은 README의 "버전과 릴리스" 참고.
set -e
VERSION="$1"
COMMIT="${2:-HEAD}"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

[ -n "$VERSION" ] || { echo "사용: Tools/release.sh <버전> [커밋]"; exit 1; }
echo "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-alpha\.[0-9]+)?$' || {
  echo "버전 형식: X.Y.Z 또는 X.Y.Z-alpha.N"; exit 1; }
TAG="v$VERSION"
git rev-parse -q --verify "refs/tags/$TAG" > /dev/null && { echo "이미 있는 태그: $TAG"; exit 1; }

SHA=$(git rev-parse --verify "$COMMIT^{commit}")
git fetch -q origin main
git merge-base --is-ancestor "$SHA" origin/main || { echo "origin/main에 push되지 않은 커밋입니다."; exit 1; }

# 앱 버전(MARKETING_VERSION)은 alpha를 뗀 목표 버전이다. 지정 커밋의 값과 맞는지 본다.
# 앱 버전을 넣기 전 커밋(7.0 그대로)에 소급해 붙일 때만 SKIP_APP_VERSION=1.
STABLE="${VERSION%%-*}"
[ "$SKIP_APP_VERSION" = 1 ] || {
APP_VERSION=$(git show "$SHA:HangyeolIME.xcodeproj/project.pbxproj" | sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' | head -1)
[ "$APP_VERSION" = "$STABLE" ] || {
  echo "커밋의 MARKETING_VERSION($APP_VERSION)이 $STABLE이 아닙니다."; exit 1; }
}

# 노트는 지금 작업 트리의 CHANGELOG.md에서 읽는다(지정 커밋의 것이 아니다).
NOTES=$(mktemp)
trap 'rm -f "$NOTES"' EXIT
awk -v h="## [$VERSION]" 'index($0, h) == 1 { on = 1; next } on && /^## \[/ { exit } on' CHANGELOG.md > "$NOTES"
grep -q '[^[:space:]]' "$NOTES" || { echo "CHANGELOG.md에 '## [$VERSION]' 절이 없습니다."; exit 1; }

DATE=$(git show -s --format=%cs "$SHA")
case "$VERSION" in
  *-*) FLAGS="--prerelease" ;;
  *)   FLAGS="--latest" ;;
esac

git tag -a "$TAG" "$SHA" -m "$TAG"
git push -q origin "$TAG"
gh release create "$TAG" --verify-tag $FLAGS --title "$TAG ($DATE)" --notes-file "$NOTES"
