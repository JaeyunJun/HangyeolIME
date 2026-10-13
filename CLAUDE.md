# NavilIME (개인 포크) — 작업 규칙

## 빌드·설치
- 빌드해서 쓸 때는 항상 `Tools/build-ime.sh` (Release) 를 쓴다. 진단이 필요할 때만 `Tools/build-ime.sh Debug`.
  - 로컬 인증서 확인/생성 → 빌드 → `~/Library/Input Methods` 설치 → 실행 확인 → 실패 시 직전 설치본으로 롤백.
  - 입력기가 죽으면 사용자가 한글을 못 친다. 설치 후 실행 확인 없이 끝내지 않는다.
- 한글 엔진(`NavilIME/Hangul/`)을 고쳤으면 `Tools/hangul-test.sh`로 출력이 기준과 같은지 확인한다.
- Debug 빌드는 os_log에 입력 내용이 평문으로 남는다. 진단이 끝나면 Release로 되돌려 설치한다.

## 서명 원칙: 로컬 인증서
- 서명은 로그인 키체인의 자체 서명 인증서 `NavilIME Local Signing`이 기본이다(`NavilIME/Signing.xcconfig`).
  손쉬운 사용 권한이 서명 신원에 묶이므로, 신원을 고정해야 재빌드해도 권한이 유지된다.
- ad-hoc 서명이나 키체인의 다른 사람 인증서로 서명하지 않는다.
- 인증서가 없으면 `Tools/setup-signing.sh`로 만든다(이미 있으면 건너뜀). 새로 만들면 사용자가 권한을 한 번 다시 허용해야 한다고 알린다.
- 이 인증서는 Team ID가 없어 Debug의 `.debug.dylib` 분리를 막아 둠(`ENABLE_DEBUG_DYLIB = NO`). 되돌리지 않는다.

## 사용자 화면
- 재현·테스트를 위해 사용자 앱을 활성화하거나 키 입력을 주입하거나 입력 소스를 바꾸지 않는다.
  필요한 정보는 Debug 로그(`/usr/bin/log stream --predicate 'subsystem == "io.navilera.NavilIME"' --level debug`)로 얻고,
  키 입력은 사용자에게 부탁한다.

## 입력기 메뉴
- IMK는 `menu()`를 키마다 부른다. 메뉴 구성을 평소와 다르게 두면(숨긴 항목 포함) 키마다 입력 세션이 끊겨
  한글이 자모 단위로 확정된다. 평소 메뉴는 고정하고, 상태가 실제로 바뀔 때만 항목을 넣고 뺀다(`InputMenu`).
