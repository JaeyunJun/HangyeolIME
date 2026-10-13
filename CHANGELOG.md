# 변경 기록

이 프로젝트는 **Manwoo Yi**([@navilera](https://github.com/navilera))님이 만든 macOS용 한글 입력기입니다.
세벌식 318Na 자판을 직접 디자인하고, 리눅스/윈도우/맥 전부 입력기를 직접 구현하신 분입니다.
아래는 개인 용도로 포크하여 수정한 내용입니다. 원본: [navilera/NavilIMEforMac](https://github.com/navilera/NavilIMEforMac)

버전마다 `## [버전]` 절이 GitHub 릴리스 노트가 된다(`Tools/release.sh`). 버전 규칙은
[README](README.md#버전과-릴리스) 참고. 그 안의 날짜별 항목은 작업 기록이다.

## [Unreleased]

## [9.0.0-alpha.4] - 2026-10-13 · pre-release

9.0.0 후보. 써 보고 문제가 없으면 같은 커밋이 9.0.0이 된다.

> **올릴 때 할 일**: 입력 소스가 입력 모드 구조로 바뀌었다. 시스템 설정 → 키보드 → 입력 소스에서
> 옛 NavilIME를 지우고 + → 한국어 → NavilIME를 다시 추가한다.

- 터미널 암호 감지를 지금 입력 중인 tty로 한정(9.0.0-alpha.1~3의 "모든 앱 한글 막힘" 해결),
  일시 중지 이유를 메뉴에 표시
- 메뉴 막대에 Apple 입력기처럼 '가' 글자 아이콘
- 역할별 구조 정리, 한글 엔진 회귀 테스트(`Tools/hangul-test.sh`)

### 2026-10-13 - 입력 모드 구조로 전환, 코드 점검

- Apple 입력기와 같은 구조로 바꿨다: 입력기 아래 입력 모드 `...NavilIME.Dubeolsik`(언어 ko,
  `smKorean`)를 두고 `TISIconLabels`(Primary = "가")를 모드에 둔다. 앱 수준의 `TISIconLabels`는
  macOS가 무시해 메뉴 막대에 '가' 글자 아이콘이 나오지 않았다. 목록 이름은
  `en/ko.lproj/InfoPlist.strings`.
- 현재 입력 소스 ID가 모드 ID가 되므로 `InputSource`는 번들 ID로 비교한다.
- 기존 사용자는 입력 소스에서 옛 NavilIME를 지우고 한국어 → NavilIME를 다시 추가해야 한다.
- 점검 수정: 맨 앞 앱이 터미널이 아닐 때(tty가 없을 때)는 orphan tty(tmux 창)의 암호
  프롬프트를 보지 않는다. tmux 창이 sudo 프롬프트에 멈춰 있으면 브라우저 등 다른 앱의 한글까지
  막혔다. 메뉴의 보안 입력 앱 이름은 pid가 바뀔 때만 다시 묻는다(menu()는 키마다 불린다).
  `insertSpecial`의 불필요한 캐스트 경고 제거.

### 2026-10-13 - 대기 중 CPU 낭비 제거, '가' 아이콘

- `TTYPasswordWatcher`가 입력기가 가만히 있을 때도 CPU를 약 2~3% 쓰고 있었다(`sample`로 확인).
  1초마다 소유 관계를 다시 만들며 (1) `devname()`이 호출마다 `/dev` 전체를 `lstat`했고,
  (2) 앱마다 `activationPolicy`, (3) pid만 읽어도 `NSRunningApplication`이 LaunchServices에 XPC로
  물었다. `/dev` 목록은 한 번만 읽고, 앱 pid는 시작할 때 한 번 받은 뒤 앱 실행·종료 알림으로만
  고친다. 대기 중 CPU 약 0.2%(실측).
- tty 소유 판단을 "가장 가까운 앱"에서 "조상 중에 맨 앞 앱이 있나"로 바꿨다. 앱 종류를 묻지
  않으면 Electron 도우미(Orca Helper)도 앱으로 잡혀, 가까운 앱 기준으로는 Orca 탭을 놓쳤다.
- 아이콘: 네모 박스 안 '나'(36px PNG) → 투명 배경의 '가' 템플릿 이미지(16pt @1x·@2x TIFF,
  `TISIconIsTemplate`)와 `TISIconLabels`(Primary = "가"). macOS가 다크·라이트 모드에 맞춰
  그린다. `Tools/make-icon.swift`로 다시 만든다.

### 2026-10-13 - 구조 정리 (동작 변화 없음)

- 입력 세션 상태를 `InputSession` 하나로 모았다: 지금 입력을 받는 컨트롤러(탭 스레드가 읽음,
  잠금 보호)와 끊긴 세션 복구. 전에는 컨트롤러의 static과 `InputSource`의 static var에 흩어져
  있었다. `InputSource`는 상태 없는 조회·전환만 한다.
- 키 위치표를 컨트롤러에서 `KeyMap`으로 뺐다. 컨트롤러의 반복되던 "확정하고 넘기기"는
  `passThrough`로 묶었다.
- 이름: `HangulMenu` → `InputMenu`(앱별 한/영 기능을 지운 뒤로 한글과 무관), `Hotfix` →
  `ComposeBypass`(특정 패턴 뒤 조합 건너뛰기), `check()` → `matches()`. 상속하지 않는
  `NavilIMEInputController`·`AppDelegate`는 `final`(원작자 코드의 `open` 제거).
- 주석: 파일 머리말은 무엇·왜·제약만 남기고 변경 이력은 여기로. `///`를 `//`로 통일.
- `Tools/tty-password-log.py` 삭제: "모든 tty"라는 예전 규칙으로 판단해 지금 입력기와 다른
  결과를 보였다. 진단은 Debug 빌드 로그로 한다.
- `Tools/hangul-test.sh` 추가: 고정 문장과 시드 고정 무작위 20만 타의 엔진 출력 해시를 기준과
  비교한다. 기준은 정리 전 원작자 엔진의 출력이다.
- 입력기 프로세스가 새로 뜬 직후 `handle`로 들어온 키도 세션 활성화로 본다(전과 같음). 이때
  끊긴 세션 복구 대기도 함께 풀린다. 키가 입력기에 왔다면 끊긴 게 아니기 때문이다.

### 2026-10-13 - 암호 프롬프트 감지를 지금 입력 중인 tty로 한정, 일시 중지 이유 표시

- `TTYPasswordWatcher`가 사용자의 모든 tty를 봐서, 뒤쪽 탭의 `sudo` 프롬프트나 에코를 끈 채
  남은 tty 하나 때문에 모든 앱에서 한글이 막힐 수 있었다(메뉴 막대는 한글인데 영문만 나옴).
- 이제 맨 앞 앱 소유의 tty(프로세스 부모를 따라가 그 앱에 닿는 것, 어느 앱에도 속하지 않는
  tmux 서버 등 포함)만 보고, 그중 가장 최근에 키 입력을 받은 tty(접근 시각, `w`의 유휴 시간과
  같은 값)와 그보다 2초 이내에 입력을 받은 tty만 확인한다. 실측: 앞 앱 아래 새 프롬프트는
  즉시 감지·해제, 다른 tty가 더 최근에 입력을 받은 상태의 프롬프트는 무시.
- 비용: 확인 1회 약 0.45ms(대부분 후보 tty를 여는 비용), 소유 관계 갱신(1초마다) 약 1.3ms.
  키 입력 경로는 100ms 캐시라 타이핑 중에도 1초에 최대 10회.
- 입력기 메뉴 맨 위에 조합을 멈춘 이유를 표시한다: 터미널 암호 감지, 또는 다른 앱이 켜 둔
  secure input(IORegistry의 `kCGSSessionSecureInputPID`로 앱 이름을 찾는다).
- [교훈] IMK는 `menu()`를 키를 칠 때마다 부른다(실측: 키 34번에 35번). 처음에는 숨긴 항목으로
  일시 중지 문구를 넣었는데, 메뉴 구성이 평소와 다르면 앱이 키마다 입력기를 껐다 켜서 자모가
  한 글자씩 따로 확정됐다(크롬·Orca 모두). 값이 바뀔 때만 건드려도, 숨긴 항목이 있기만 해도
  그랬다. 평소 메뉴는 항목 하나로 고정하고, 일시 중지가 생기거나 풀리는 순간에만 항목을 넣고 뺀다.

## [9.0.0-alpha.3] - 2026-10-08 · pre-release

> **알려진 문제** (9.0.0-alpha.4에서 고침)
> - 터미널 암호 감지가 사용자의 모든 tty를 봐서, 뒤쪽 탭에 떠 있는 `sudo` 프롬프트 하나 때문에
>   모든 앱에서 한글이 막힐 수 있었다(메뉴 막대는 한글인데 영문만 나옴).

- 한글 상태 특수키 복구(9.0.0-alpha.1에서 깨짐), xterm.js 계열 터미널(Orca) 대응
- 로컬 자체 서명 인증서로 서명해 재빌드해도 손쉬운 사용 권한 유지
- 입력 소스 전환 직후의 키가 한글로 조합되던 문제(Raycast 첫 글자) 수정
- 앱별 한/영 고정 제거(macOS "문서의 입력 소스로 자동 전환"으로 대신), 끊긴 입력 세션 복구

### 2026-10-08 - 끊긴 입력 세션 복구 (안전망)

- 메뉴 막대는 NavilIME인데 영문이 입력되는 상태를 복구한다. 실측: Raycast를 Option+Space로
  닫고 Orca로 돌아오면 macOS가 Orca 입력창에 입력기를 켰다가 1ms 만에 끄고 다시 켜지 않았다.
  입력기는 키를 받지 못하므로, 모든 키를 보는 전역 탭이 "NavilIME 선택 + 켜진 입력창 없음 +
  글자 키"를 알아채고 입력 소스를 ABC→NavilIME로 되돌려 다시 붙인다(`InputSource.swift`).
- 입력창이 없는 화면에서 깜빡이지 않게 입력기가 꺼질 때마다 한 번만 시도한다. Orca는 Enter마다
  입력창을 다시 만들어 입력기가 약 100ms 꺼졌다 켜지므로(실측), 꺼진 뒤 0.3초가 지나도 안 켜졌을
  때만 끊긴 것으로 본다.
- 효과는 아직 검증하지 못했다. 넣은 뒤로 증상이 재현되지 않았다(macOS "문서의 입력 소스로 자동
  전환"을 켜고 Raycast 자체 전환을 끈 뒤로 사라짐). 다시 생기면 Debug 빌드 로그로 확인한다.

### 2026-10-08 - 입력 소스 전환 직후 키 처리, 앱별 한/영 고정 제거

- 입력 소스가 바뀐 직후 들어온 키가 한글로 조합되던 문제를 고쳤다. Raycast 자체 설정처럼
  열리면서 ABC로 바꾸는 앱에 바로 타이핑하면 첫 글자가 한글이 됐다. 전환이 앱에 반영되어
  입력기가 꺼지기까지 100~200ms(실측)가 걸리고, 그 사이 키는 여전히 입력기로 온다.
  키마다 시스템의 현재 입력 소스가 NavilIME인지 확인하고, 아니면 조합하지 않고 흘려보낸다.
  확인 비용은 키당 약 20~40µs(실측).
- 앱별 한/영 고정(`AppLangHandler`, 메뉴 항목, 앱 전환 감시)을 제거했다. 쓰던 앱이 하나뿐이고,
  macOS의 "문서의 입력 소스로 자동 전환"으로 대신한다. 저장돼 있던 설정(`app_lang_map`)은
  더 이상 읽지 않는다.
- 참고: Raycast를 Option+Space로 닫고 Orca로 돌아왔을 때 메뉴 막대는 한글인데 영문이
  입력되던 현상은 입력기와 무관했다. 로그상 macOS가 Orca의 입력 세션을 켠 지 1ms 만에
  끄고, 그동안 키가 입력기로 오지 않았다. 입력기는 전환을 요청하지도, 키를 받지도 않았다.
- Debug 로그에 activate/deactivate 대상 앱을 남긴다.

### 2026-10-08 - 특수키: xterm.js 계열 터미널 대응, 재시작 직후 대응

- Orca 같은 xterm.js 계열 터미널에서 한글 상태 특수키가 깨졌다(`₩`→`|`, `` ` `` 없음,
  `~`는 조합 중 첫 번째만). 입력기는 매번 정확히 `insertText`했지만(로그로 확인), xterm.js는
  키가 눌린 채(Shift·⌘) 들어오는 일반 텍스트 입력을 무시하고, 조합 확정으로 들어오는 글자만
  받는다. 그래서 특수키는 marked text로 올렸다가 바로 확정한다. 일반 앱에서는 결과가 같다.
- 리팩터링 탓으로 보였지만 리팩터링 이전 빌드도 Orca에서 똑같이 깨졌다. 앞서 Orca에서
  잘 된다고 확인한 것은 Debug 빌드였다.
- 입력기 프로세스가 새로 뜬 직후(재설치 등) macOS가 `activateServer` 없이 `handle`을 부르면
  탭이 한글 상태를 몰랐다. `handle`의 keyDown에서도 활성 컨트롤러로 표시한다.

### 2026-10-08 - 코드·저장소 정리

- 한글 엔진 재구성. 세벌식 시절의 `Keyboard` 기반 클래스와 옛한글 자모 정의를 없애고
  `Hangul/`(`Hangul.swift` 엔진, `Jamo.swift` 자모, `Dubeolsik.swift` 배치·조합 규칙)로 정리.
  호환 자모는 별도 enum(`Hohan`) 대신 각 자모의 `compatibility`로 계산한다.
- `Hangul`이 키마다 디버그 문자열을 쌓기만 하고 비우지 않던 배열(`debug_commit`/`debug_preedit`)
  제거. Release에서도 입력 내용이 메모리에 무한히 쌓였다. 이를 쓰던 `Testcases.swift`도 제거
  (앱에 같이 빌드됐지만 호출하는 곳이 없었다).
- 재구성 전후 엔진 출력이 같은지 고정 문장과 무작위 20만 타로 비교해 확인했다(완전 일치).
- `Hangul.Start()/Stop()`과 `ensureHangulReady()` 제거. 엔진은 항상 준비 상태다.
- `Hotfix`의 원형 스택을 단순 배열로 교체(동작 동일).
- 이름 규칙을 Swift 표준으로 통일(snake_case 제거), 파일명을 타입과 맞춤
  (`SingletonMenu` → `HangulMenu`, `SingletonAppLang` → `AppLangHandler`,
  `SingletonHotfix` → `Hotfix`, `SingletonPrintLog` → `Log`).
- 저장소에서 제거: 원작자의 옛 배포본(`Release/`), 원본 README 이미지(`Stuff/`, `install.png`),
  옛 설치 스크립트(`install.sh`, `uninstall.sh`), `secure-run`과 셸 래퍼·설치 스크립트
  (암호 프롬프트는 앱이 자동 감지), 실수로 커밋된 `xcuserdata`·`__pycache__`.
  README에 통째로 들어 있던 원본 README는 원작자 저장소 링크로 대체.

### 2026-10-08 - 한글 상태 특수키 수정, 권한 상태 창

- 한글(NavilIME) 상태에서 `Shift+ESC`/`Cmd+ESC`/`Cmd+\`가 아무것도 입력하지 않던 문제를 고쳤다.
  탭이 문자를 바꿔 넣은 이벤트는 입력기의 `handle`까지 오지 않는다(Debug 로그로 확인: 탭은
  매칭했지만 IMK keyDown이 없음). 그래서 기존의 `event.characters` 판별 분기는 한 번도 타지 않았다.
- 이제 NavilIME가 활성이면 탭이 이벤트를 삼키고, 메인 스레드에서 활성 컨트롤러의
  `insert_special`을 부른다. 조합 중인 글자를 확정하고 그 뒤에 기호를 붙인다.
  활성 컨트롤러는 `activateServer`/`deactivateServer`로 추적한다(탭 스레드가 읽으므로 잠금).
- 권한 상태 창(`PermissionWindow.swift`) 추가. 실제 권한(`AXIsProcessTrusted`)과 탭 동작
  여부를 보여주고, 손쉬운 사용 설정으로 보내며, 떠 있는 동안 1초마다 다시 조회한다.
  메뉴 항목도 항상 실제 상태를 보여주고 누르면 이 창을 연다.
- `SpecialKeyTap.isActive` 추가, 탭 생성 실패 시 재시도 가능하게 함.
- README: 로컬 자체 서명 인증서로 권한 유지하는 방법, Debug 빌드 시 `ENABLE_DEBUG_DYLIB=NO` 주의.

## [9.0.0-alpha.2] - 2026-09-09 · pre-release

> **알려진 문제**
> - 9.0.0-alpha.1의 문제 그대로(한글 상태 특수키 없음, 모든 tty 감시).
> - 열리면서 ABC로 바꾸는 앱(Raycast)에 바로 치면 첫 글자가 한글로 들어감(9.0.0-alpha.3에서 고침).

- **호환되지 않는 변경**: 입력기 내부 한/영 모드와 전용 단축키 제거. 한/영은 macOS 입력 소스
  (NavilIME ↔ ABC)로만 바꾼다.
- 앱별 한/영 고정(9.0.0-alpha.3에서 다시 제거)

### 2026-09-09 - 내부 한/영 모드 제거, 입력 소스로 일원화

- `self_eng_mode`(입력기 내부 한/영 플래그)와 전용 단축키를 전부 제거했다.
  `ToggleSuspend`, `OptHandler`(`SingletonOpt.swift` 삭제), 트레이의 "한/영 전환" 섹션,
  `select_haneng_hotkey` 제거. 순 -62줄.
- 한/영은 macOS 입력 소스 선택으로만 결정된다. 한글 = NavilIME, 영문 = ASCII 레이아웃(ABC).
- 내부 모드는 macOS가 알 수 없는 상태였다. 어느 앱에서든 "NavilIME 선택됨"으로만 보여
  OS가 앱별 기억도 암호 필드 대응도 해줄 수 없었고, 이 세션에서 겪은 문제들의 공통 뿌리였다.
- 전환 비용은 2.5ns → 약 1.29ms(측정 중앙값)로 늘지만 인지 한계(~10ms) 아래다.
- 앱별 지정은 두 신호로 적용한다. `activateServer`(IMK가 새 클라이언트로 입력기를 켤 때)와
  `NSWorkspace.didActivateApplicationNotification`(입력기가 비활성이라 activateServer가
  오지 않을 때).
- Raycast 같은 런처는 '비활성화 패널'로 떠서 최전면 앱이 바뀌지 않는다. 실측 결과 워크스페이스
  알림이 아예 오지 않고 `activateServer`만 온다. 그래서 두 경로가 모두 필요하다.
- 적용은 앱이 바뀔 때만 한다(`last_applied` 가드). `activateServer`는 같은 앱 안에서도 자주
  불리므로, 매번 적용하면 ⌘Space로 직접 바꾼 것을 즉시 되돌려 그 앱에서 반대 언어를 못 쓰게
  된다. 전환 루프도 이 가드로 막힌다.
- '영문' 지정인데 이미 ABC면 아무것도 하지 않는다 — 결과가 같고 사용자의 소스 선택을
  뒤엎을 이유가 없다.

#### 검증 중 발견: 옛 샌드박스 컨테이너
- `~/Library/Containers/com.navilera.inputmethod.NavilIME/`가 남아 있다. 샌드박스를
  끄기 전 시절의 잔재로, `defaults` 명령은 이 컨테이너를 읽고 쓰는 반면 앱은
  `~/Library/Preferences/`를 쓴다. 옛 설정(`keyboard`, `002_sel_no_shift`)이 컨테이너에
  갇혀 있고 앱은 못 읽는다. 지금 코드에는 없는 설정이라 실사용 영향은 없다.

### 2026-09-09 - 앱별 한/영 고정

- 이 입력기의 한/영은 입력 소스 전환이 아니라 `self_eng_mode` 플래그를 뒤집는 방식이라,
  macOS 입장에선 어느 앱에서든 "NavilIME 선택됨"으로 동일하게 보인다. 그래서 OS의
  "문서의 입력 소스로 자동 전환"이 이 상태를 기억해줄 수 없다. 입력기가 직접 기억한다.
- `AppLangHandler`: 번들 ID → `지정 안 함`/`한글`/`영문`. 지정한 앱만 저장하고,
  해제하면 키 자체를 지운다. `UserDefaults`(`app_lang_map`)에 영속화.
- `activateServer`에서 클라이언트 번들 ID를 읽어 지정값이 있으면 모드를 맞춘다.
  지정 안 한 앱은 건드리지 않으므로 기존 동작 그대로다.
- 트레이 메뉴에 "‘앱이름’에서 항상" 섹션 추가. `menu()`에는 클라이언트가 넘어오지 않아
  마지막 클라이언트 번들 ID를 static으로 남겨 쓴다.
- 앱 안에서 수동 전환하면 그게 이기고, 다시 들어올 때 지정값으로 복귀한다.

#### 측정 정정
- 이전 회차에서 "비활성 로그가 이벤트당 21.5ns"라고 적었으나 오측이었다. 벤치마크
  하네스를 `-wmo` 없이 컴파일한 탓이고, 실제 Release는 `SWIFT_COMPILATION_MODE =
  wholemodule`이라 최적화기가 오토클로저를 완전히 제거한다. 실제 비용은 0ns다.
- 같은 조건에서 한영전환 전체 경로는 약 2.5ns(`Is_han_eng_changed` 1.44ns +
  `ToggleSuspend` 1.11ns). 비교로 macOS 입력 소스 전환은 중앙값 1.29ms.

## [9.0.0-alpha.1] - 2026-08-31 · pre-release

> **알려진 문제**
> - 한글 상태에서 특수키 세 조합이 아무것도 입력하지 않음. 경로를 탭 하나로 합치면서 생긴
>   회귀다(9.0.0-alpha.3에서 고침).
> - 터미널 암호 감지가 모든 tty를 봐서 뒤쪽 탭의 프롬프트가 모든 앱의 한글을 막을 수 있음
>   (9.0.0-alpha.4에서 고침).

- 암호 입력 중(secure input, 터미널 `sudo`·`ssh`·`git` 프롬프트) 자동으로 조합 멈춤
- Release 빌드에서 `get-task-allow` 제거

### 2026-08-31 - Release 빌드에서 get-task-allow 제거

- Xcode는 Apple Development 인증서로 서명할 때 `com.apple.security.get-task-allow`를
  자동 주입한다(`CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES`). 이건 "다른 프로세스가
  디버거를 붙여도 된다"는 뜻이라, Hardened Runtime(`flags=0x10000(runtime)`)이
  켜져 있어도 디버거 접근이 열린다.
- 입력기는 모든 키 입력을 지나보내고 손쉬운 사용 권한까지 갖고 있으므로, 사용자 권한으로
  도는 악성코드가 여기에 붙어 키 입력을 읽거나 이 앱의 TCC 권한에 편승할 수 있다.
- `Signing.xcconfig`에 `CODE_SIGN_INJECT_BASE_ENTITLEMENTS[config=Release] = NO`를
  추가해 Release에서만 주입을 끈다. Debug는 Xcode 디버깅을 위해 그대로 둔다.
- 확인: Release 빌드의 entitlements가 `app-sandbox = false` 하나만 남았다.

### 2026-08-31 - 터미널 암호 프롬프트 자동 감지 (TTYPasswordWatcher)

#### sudo 외에 ssh·git·passwd 등도 커버, 셸 설정 불필요
- 기존 방식(`secure-run` + `.zshrc` 래퍼)은 명령별로 감싸야 했고 `sudo`만 실용적이었다.
  `ssh`는 세션 전체를 감싸게 되어 원격 접속 내내 한글을 못 쓰게 되므로 쓸 수 없었다.
- 비밀번호를 읽는 프로그램은 tty를 **정규 모드(ICANON) + 에코 끔(ECHO off)** 으로 만들고,
  전체화면 TUI는 raw 모드(ICANON off)라 구분된다. 실측 확인:

  | 프로그램 | 모드 | 에코 | 판정 |
  |---|---|---|---|
  | `cat` | 정규 | on | — |
  | `getpass` | 정규 | OFF | 암호 프롬프트 |
  | `vi` | raw | OFF | TUI (오탐 아님) |
  | `top` | raw | OFF | TUI (오탐 아님) |

- `TTYPasswordWatcher`가 사용자 소유 `/dev/ttys*`를 훑어 이 상태를 찾으면
  `EnableSecureEventInput()`을 켠다. 조합이 멈추는 것은 물론, 그동안 다른 앱의
  이벤트 탭까지 차단되어 실제 키로거 방어가 된다. 조건이 풀리면 즉시 해제하고,
  앱 종료 시에도 해제한다(우리가 켠 만큼만 끄도록 보유 여부를 추적).
- tty는 `O_NOCTTY | O_NONBLOCK`으로 열어 controlling terminal이 되지 않게 한다.
- 비용: 1회 스캔 약 515µs(대부분 tty open 비용, 하나당 ~57µs — 목록을 캐시해도 줄지 않음).
  타이머는 1초 주기(약 0.05% CPU), 키 입력 경로는 100ms TTL 캐시로 확인해 프롬프트 직후
  첫 글자도 놓치지 않는다.
- 종단 검증: pty로 `getpass`를 띄우면 secure input이 켜지고 종료 시 해제, `top`(TUI)에는
  반응하지 않음을 확인.
- `Tools/secure-run`은 감지가 안 먹는 상황용 수동 탈출구로 남긴다.
- `Tools/tty-password-log.py`: 같은 조건을 독립적으로 감시해 언제 어떤 프로그램이
  암호 프롬프트 상태를 만들었는지 기록한다. 오탐 추적용.

### 2026-08-31 - 암호 프롬프트에서 입력기 자동 비켜서기

#### 한글 상태에서 sudo 비밀번호가 안 들어가던 문제
- macOS는 secure input이 켜져도 **입력 소스를 영문으로 갈아주지 않는다**(측정으로 확인:
  sudo 프롬프트 동안 `IsSecureEventInputEnabled() == true`인데 현재 입력 소스는
  `com.navilera.inputmethod.NavilIME` 그대로였다). 그래서 한글 상태면 암호가 한글로
  들어가고, 사용자가 매번 수동으로 영문 전환해야 했다.
- `keydown_event_handler` 진입부에서 `IsSecureEventInputEnabled()`를 확인해, 켜져 있으면
  조합 없이 키를 그대로 통과시킨다(`Flush()` 후 `return false`).
- 한/영 상태(`ToggleSuspend`)는 건드리지 않는다. 프롬프트를 빠져나오면 원래 한글 상태로
  자동 복귀한다.
- 호출 비용은 약 4ns(로컬 플래그 읽기)로 측정돼 매 키 입력 경로에 두어도 무방하다.
- 부작용: secure input은 프로세스 전역 참조 카운트라, 어떤 앱이 켜놓고 끄지 않으면 한글이
  어디서도 조합되지 않는다. 화면 잠갔다 풀면 해소된다.

#### 터미널 sudo용 보조 도구 `Tools/secure-run`
- 측정 결과 터미널의 sudo 프롬프트는 secure input을 켜지 않는다(터미널이 pty 에코 상태를
  보지 않음). 그래서 위 수정만으로는 sudo 자리가 메워지지 않는다.
- `secure-run <명령>`: 그 명령이 도는 동안만 secure input을 켠다. 어떤 시그널로 끝나든
  `atexit`/시그널 핸들러로 반드시 되돌린다(켠 채 죽으면 시스템 전역으로 남기 때문).
- `Tools/zshrc-snippet.sh`의 sudo 래퍼는 `sudo -v`(암호 확인만 하고 즉시 종료)를 감싸므로
  프롬프트 동안만 잡힌다. `sudo vim` 편집 중에는 한글이 정상 동작한다.
- `Tools/install.sh`로 `~/.local/bin`에 빌드·설치.
- 자식은 `posix_spawnp`를 attr 없이 직접 호출해 띄운다. Foundation의 `Process`는 자식을
  새 프로세스 그룹(세션)에 넣는데, 그러면 자식이 포그라운드 그룹이 아니게 되어 sudo가
  tty에서 암호를 읽으려는 순간 `SIGTTIN`으로 멈춘다 — 프롬프트만 찍히고 입력이 안 먹는
  증상이 된다. 부모의 프로세스 그룹과 controlling tty를 그대로 물려줘야 한다.
- 자식의 종료 상태(정상 종료 코드 / 시그널)를 그대로 전달한다.
- `Tools/secure-test`: secure input을 켠 채 에코를 남겨두고 한 줄을 받아, 비밀번호 없이
  입력기가 비켜서는지 눈으로 확인하는 회귀 테스트 도구.

### 2026-08-31 - 특수키 처리 경로 통합

#### 한글 입력 중 `` ` ``, `₩`가 나오지 않던 문제
- 원인: ⌘ 조합 키 이벤트는 AppKit의 키 이퀴벌런트 단계에서 소비되어
  `IMKInputController.handle`까지 내려오지 않는다. NavilIME 활성(한글) 상태에서는
  `SpecialKeyTap`이 IMK 경로에 처리를 양보했으므로 아무도 처리하지 않았다.
  (`Shift+ESC→~`는 키 이퀴벌런트가 아니라 IMK에 도달해 정상 동작했다.)
- 조치: `SpecialKeyTap`을 특수키 조합의 유일한 처리 경로로 통합. 탭이 세션 레벨에서
  모디파이어를 지우고 유니코드를 갈아끼우므로, 치환된 이벤트는 평범한 키가 되어
  입력기 상태와 무관하게 동작한다.
- `NavilIMEInputController.special_keys` 사본 테이블과 처리 루프 제거.
  `SpecialKeyTap.currentInputSourceIsNavil()`(TIS 조회)과 `import Carbon`도 함께 제거.
- 치환된 이벤트는 keycode가 아니라 `event.characters`가 진실이다. 탭은 모디파이어만
  지우므로 keycode는 원래 키로 남는데, `Cmd+\`(0x2A)는 `key_code` 테이블 범위 안이라
  IMK가 이를 `\`로 재해석해 `₩`를 덮어쓴다. IMK 경로가 `SpecialKeyTap.outputs`에
  속한 문자를 만나면 keycode 해석을 건너뛰도록 처리.
  (`~`, `` ` ``는 keycode 0x35로 테이블 범위 밖이라 원래 영향 없음)

#### 모디파이어 정확 일치
- 기존 `flags.contains(combo.flag)`는 추가 모디파이어를 허용해, `Cmd+Shift+ESC`가
  테이블 첫 항목(`Shift+ESC`)에 걸려 `~`를 냈다.
- `matchedFlags`(shift/control/option/command)로 걸러낸 뒤 등가 비교로 변경.
  Caps Lock과 fn은 마스크에서 제외 — 켜져 있다고 조합이 깨지면 안 되므로.

#### 문서/UI
- 권한이 없으면 특수키가 **어느 입력기에서도** 동작하지 않음을 README, 트레이 메뉴
  주석, 권한 안내 alert에 반영.

## [8.0.0] - 2026-06-18

8.0.0-alpha 시리즈의 문제를 고친 첫 정식 버전.

> **알려진 문제**: 한글 상태에서 `Cmd+ESC`, `Cmd+\`가 입력되지 않는다(⌘ 조합은 입력기까지
> 오지 않음). `Shift+ESC`는 된다.

### 2026-06-17~18 - 입력 지연, 포커스 전환 시 글자 섞임, 입력 내용 로깅

- 전역 키 탭을 메인 런루프에서 전용 스레드로 옮겼다. 모든 키가 메인 스레드(IMK 입력 경로)를
  동기로 지나가서 입력·전환이 늦어지고 탭이 타임아웃으로 꺼졌다 켜졌다.
- `deactivateServer`에서 조합 중인 글자를 `super` 호출 전에 확정한다. 포커스가 새 앱(예: Raycast)으로
  넘어간 뒤 확정돼 글자가 새 창으로 샜다.
- 탭은 특수키 후보 키(ESC, `\`)일 때만 입력 소스를 조회한다.
- Release 빌드에서 로그를 남기지 않는다. 입력한 글자(조합 중·확정)가 시스템 로그에 평문으로 남았다.

## [8.0.0-alpha.3] - 2026-05-27 · pre-release

> **알려진 문제** (8.0.0에서 고침)
> - 전역 키 탭이 메인 스레드에서 돌아 입력·전환이 늦어짐.
> - Release 빌드가 입력 내용을 시스템 로그에 평문으로 남김, 포커스 전환 때 조합 중 글자가 새 창으로 샘.
> - ad-hoc 서명이라 재빌드할 때마다 손쉬운 사용 권한을 다시 허용해야 함(9.0.0-alpha.3에서 고침).

- 특수키 조합을 입력 소스와 상관없이 전역 동작(손쉬운 사용 권한 필요)

### 2026-05-27 - 전역 특수키 입력 및 개인 빌드 서명

#### 특수키 조합을 다른 입력기 상태에서도 동작 (전역)
- `SpecialKeyTap`: 세션 레벨 `CGEventTap`으로 특수키 조합(`Shift+ESC→~`,
  `Cmd+ESC→\``, `Cmd+\→₩`)을 전역에서 가로채 치환.
- 현재 입력기가 NavilIME가 아닐 때만 가로채고, NavilIME 활성 시엔 기존 IMK
  경로가 처리하도록 분기 → 이중 처리 방지.
- 탭이 타임아웃/사용자 입력으로 비활성화되면 자동 재활성화.
- App Sandbox에서는 전역 이벤트 탭이 막히므로 entitlements에서 `app-sandbox`를
  끔. (App Store가 아닌 직접 설치 방식이라 무방)

#### 손쉬운 사용 권한 UI
- `CGEventTap`은 손쉬운 사용(Accessibility) 권한이 필요.
- 트레이 메뉴에 "특수키 전역 입력 권한 허용…" 항목 추가. 권한이 있으면
  "특수키 전역 입력: 켜짐 ✓"로 표시(비활성).
- 클릭 시 시스템 권한 요청 + 손쉬운 사용 설정 창 열기 + 안내 alert.
  LSBackgroundOnly 환경에서도 표시되도록 활성화 정책을 잠시 올림.
- 부팅 시 권한이 이미 있으면 탭 자동 시작.

#### 개인 빌드 서명 구조
- `Signing.xcconfig`(기본 ad-hoc) + `Local.xcconfig.example`(템플릿) 도입.
  실제 `Local.xcconfig`는 `.gitignore`로 커밋 제외 → 개인 Team ID 비공개.
- pbxproj에서 하드코딩된 `DEVELOPMENT_TEAM`/`CODE_SIGN_IDENTITY` 제거,
  `baseConfigurationReference`로 xcconfig 연결.
- `.gitignore` 신설, 추적되던 `.DS_Store` 추적 해제.

## [8.0.0-alpha.2] - 2026-05-23 · pre-release

> **알려진 문제** (8.0.0에서 고침): Release 빌드가 입력 내용을 시스템 로그에 평문으로 남김,
> 포커스 전환 때 조합 중 글자가 새 창으로 샘.

- 옵션 창 제거, 두벌식 ㄷㄷㄷ 옵션 제거

### 2026-05-23 - 옵션 창 제거 및 안정성 라운드

#### 옵션 창 제거, 한영전환 단축키를 트레이 메뉴로 통합
- 옵션 창과 관련 xib UI 전체 제거
- 한/영 전환 단축키 설정(시스템입력기 사용 / 왼쪽 Shift+Space / 오른쪽 Command / 오른쪽 Option)을 트레이 메뉴 라디오 항목으로 이동

#### 두벌식 ㄷㄷㄷ 옵션 제거
- 같은 자음 연속 입력을 쌍자음으로 합치는 옵션 제거
- `shift_cho`(분리 입력) 동작을 영구 기본으로 고정, 관련 테이블/영속화 코드 단순화

#### 안정성 개선
- 죽은 NSScrollView 출력을 `os_log` 래퍼로 교체 (Console.app에서 `subsystem=io.navilera.NavilIME`로 필터링)
- `setMarkedText` selectionRange를 grapheme count 대신 NSString.length(UTF-16)로 계산 (NFD 분해된 한글 잘림 방지)
- cmd/option/control이 눌린 keycode는 hotfix 순환버퍼에 넣지 않음 (false-positive 방지)
- 드래그 매 프레임 commit 호출 제거
- IBOutlet들을 옵셔널로 변경, xib에 위젯이 없어도 크래시 없이 진행

## [8.0.0-alpha.1] - 2026-04-14 · pre-release

원작자 7.0 이후 첫 포크 버전.

> **알려진 문제** (8.0.0에서 고침): Release 빌드가 입력 내용을 시스템 로그에 평문으로 남김
> (원작자 코드부터), 포커스 전환 때 조합 중 글자가 새 창으로 샘.

- **호환되지 않는 변경**: 세벌식 318·390 제거, 두벌식 전용
- 특수키 조합(`Shift+ESC` → `~` 등), 크래시 방어
- 일부 앱에서 macOS가 `activateServer` 없이 키를 보내 한글이 안 되던 문제 수정

### 2026-04-14 - 대규모 정리 및 개선

#### 세벌식 제거
- 세벌식 318, 390 키보드 코드 전부 삭제 (`Keyboard318.swift`, `Keyboard390.swift`)
- 두벌식(Keyboard002)만 남김
- Hangul, Keyboards, SingletonMenu, SingletonOpt, Testcases 등에서 관련 참조 모두 제거
- 트레이 메뉴에서 키보드 선택 항목 제거 (옵션 메뉴만 남김)

#### 옵션 창 개선
- 디버깅용 scrollView 제거
- 윈도우 크기 축소 (517px -> 210px)
- 타이틀 "NavilIME 옵션"으로 변경
- AppDelegate에서 디버그 로그 설정 코드 제거

#### 특수키 조합 추가
- `Shift + ESC` -> `~` (물결)
- `Cmd + ESC` -> `` ` `` (백틱)
- `Cmd + \` -> `₩` (원화 기호)
- 테이블 기반으로 구현되어 있어 `special_keys` 배열에 추가만 하면 확장 가능

#### 크래시 방어
- `Hangul!` (force unwrap) -> `Hangul?` (optional)로 변경
- `Automata` 접근 시 `guard let` 패턴 적용
- macOS가 비정상 순서로 생명주기 호출할 때 (화면 잠금, 슬립 복귀, 빠른 앱 전환) 크래시 방지

#### Hotfix 버퍼 오염 방지
- 특수키 조합을 Hotfix 패턴 체크 이전에 처리
- ESC 등의 keycode가 hotfix circular buffer에 들어가지 않음
