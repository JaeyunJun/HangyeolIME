#!/bin/sh
# 한글 엔진 회귀 테스트. 엔진(HangyeolIME/Hangul)을 고친 뒤 돌린다.
# 기준 해시는 정리 전 원작자 엔진의 출력에서 얻었다. 엔진 동작을 일부러 바꿨다면
# 바뀐 이유를 확인한 뒤 EXPECTED를 새 값으로 갱신한다.
set -e
# 2.0.1: 초성 없는 모음 뒤 자음을 초성·받침으로 받지 않음(ㅣ+ㄹ → ㅣㄹ). 고정 문장 출력은 그대로.
EXPECTED=80f28c367bea4993a38cdaf4091b8a17
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/hangul-test" \
  "$ROOT"/HangyeolIME/Hangul/*.swift "$ROOT/HangyeolIME/Log.swift" "$ROOT/Tools/hangul-test/main.swift"
"$WORK/hangul-test" "$WORK/out.txt"
ACTUAL=$(md5 -q "$WORK/out.txt")

if [ "$ACTUAL" = "$EXPECTED" ]; then
  echo "통과: 한글 엔진 출력이 기준과 같습니다 ($(wc -l < "$WORK/out.txt" | tr -d ' ')단계)"
else
  echo "실패: 출력 해시 $ACTUAL (기준 $EXPECTED)"
  exit 1
fi
