# 개발

동작의 이유와 실측 근거는 각 파일 머리말 주석과 [CHANGELOG.md](CHANGELOG.md)에 있습니다.
작업 규칙(사람·에이전트 공통)은 [CLAUDE.md](CLAUDE.md).

## 빌드·설치

```
Tools/build-ime.sh          # Release 빌드 → ~/Library/Input Methods 설치 → 실행 확인
Tools/build-ime.sh Debug    # 진단용. os_log에 입력 내용이 남으니 끝나면 Release로 되돌릴 것
Tools/hangul-test.sh        # 한글 엔진 회귀 테스트(HangyeolIME/Hangul/을 고쳤을 때)
swift Tools/secure-test.swift   # secure input 상태에서 입력기가 비켜서는지 눈으로 확인
```

`build-ime.sh`는 설치 뒤 새 빌드가 실제로 뜨는지 확인하고, 안 뜨면 직전 설치본으로 되돌립니다.
Debug 로그: `log stream --predicate 'subsystem == "com.jaeyunjun.HangyeolIME"' --level debug`

## 코드 구조

| 파일 | 역할 |
|---|---|
| `HangyeolInputController` | 입력기 본체. 키 → 한글 엔진 → 조합 중/확정 글자 반영 |
| `Hangul/` | 한글 엔진(`Hangul`), 자모(`Jamo`), 두벌식 배치·조합 규칙(`Dubeolsik`) |
| `KeyMap` | 가상 키코드 → 문자 |
| `ComposeBypass` | 특정 키 패턴 뒤 조합 건너뛰기(```` ``` ````c, 0x) |
| `InputSource` / `InputSession` | 입력 소스 조회 / 지금 입력 중인 세션, 끊긴 세션 복구 |
| `SpecialKeyTap` | 특수키 조합 전역 탭(CGEventTap, 전용 스레드) |
| `TTYPasswordWatcher` | 터미널 암호 프롬프트 감지(tty가 정규 모드 + 에코 끔) |
| `InputMenu` / `PermissionWindow` | 입력기 메뉴 / 특수키 권한 창 |
| `Log` | Debug 전용 로그(Release에서는 컴파일 단계에서 사라짐) |

## 입력 모드 구조

Apple 입력기처럼 입력기(`com.jaeyunjun.inputmethod.HangyeolIME`) 아래 입력 모드 하나
(`…HangyeolIME.Dubeolsik`, 언어 ko)를 두고 사용자는 이 모드를 선택합니다(`Info.plist`의
`ComponentInputModeDict`). 그래서 현재 입력 소스 ID는 모드 ID이고, 코드는 번들 ID로 한결인지
판단합니다. 목록 이름과 앱 이름은 `*.lproj/InfoPlist.strings`(여기에 `CFBundleName`이 없으면 메뉴에
키 이름이 그대로 보입니다).

메뉴 막대의 '가'는 입력 모드의 `TISIconLabels`를 macOS가 그립니다. 그림 아이콘 `hangyeol.tiff`는
`swift Tools/make-icon.swift HangyeolIME/hangyeol.tiff`로 다시 만듭니다.

## 서명: 로컬 인증서

손쉬운 사용 권한은 코드 서명 신원에 묶입니다. ad-hoc 서명은 재빌드마다 신원이 바뀌어 권한이
날아가므로, 로그인 키체인의 자체 서명 인증서 `HangyeolIME Local Signing`으로 서명합니다
(`HangyeolIME/Signing.xcconfig`). 없으면 `Tools/setup-signing.sh`가 만듭니다(`build-ime.sh`가 자동 호출).

- 인증서를 새로 만들면(다른 Mac, 키체인 초기화) 권한을 한 번 다시 허용해야 합니다.
- Team ID가 없어 Debug의 `.debug.dylib` 분리를 끕니다(`ENABLE_DEBUG_DYLIB = NO`).
- Release는 `get-task-allow`를 넣지 않습니다(다른 프로세스가 디버거를 붙이지 못하게).
- 다른 신원을 쓰려면 `HangyeolIME/Local.xcconfig`로 덮어씁니다(`Local.xcconfig.example`, gitignore 대상).

## 버전과 릴리스

[유의적 버전](https://semver.org/lang/ko/) `주.부.수`. 원작자 버전(마지막 7.0)과 별개로 1부터 셉니다.

- **주**: 쓰던 방식이 바뀌는 변경(기능 제거, 입력 소스 재추가 필요 등). **부**: 기능 추가. **수**: 버그 수정.
- 새 버전은 먼저 pre-release `X.Y.Z-alpha.N`으로 내고, 써 보고 문제가 없으면 **같은 커밋**에 `X.Y.Z`를 붙입니다.
- 문제가 있던 버전은 지우지 않고 릴리스 노트 맨 위에 **알려진 문제**와 고친 버전을 적습니다.
- 릴리스 노트의 원본은 `CHANGELOG.md`의 `## [버전]` 절입니다. 작업 중 내용은 `## [Unreleased]`에 쌓습니다.

```
Tools/release.sh 2.1.0-alpha.1            # 지금 커밋으로 pre-release
Tools/release.sh 2.1.0 <alpha의 커밋>     # 문제없던 alpha를 정식으로 (CHANGELOG에 2.1.0 절 먼저)
```
앱 버전(`MARKETING_VERSION`)은 alpha를 뗀 목표 버전이고, 스크립트가 커밋의 값과 맞는지 확인합니다.
