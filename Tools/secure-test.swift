//
//  secure-test.swift
//  HangyeolIME 보조 도구 — 회귀 테스트
//
//  secure input을 직접 켜서 암호 프롬프트와 같은 조건을 만든 뒤, 에코는 켜둔 채로
//  한 줄을 받아 그대로 보여준다. 비밀번호 없이 "입력기가 제대로 비켜서는가"를
//  눈으로 확인하기 위한 도구다.
//
//  실제 암호 프롬프트는 입력을 감추기 때문에 무엇이 들어갔는지 알 수 없어서,
//  HangyeolInputController의 IsSecureEventInputEnabled() 분기가 깨졌는지
//  확인하려면 이런 대역이 필요하다.
//
//  사용:  swift Tools/secure-test.swift   → 한글 상태로 abcd 입력
//

import Carbon
import Foundation

// 켠 채로 죽으면 시스템 전역에 남는다. 어떤 경로로 끝나든 반드시 되돌린다.
for sig in [SIGINT, SIGTERM, SIGHUP, SIGQUIT] {
    signal(sig) { _ in DisableSecureEventInput(); exit(130) }
}
atexit { DisableSecureEventInput() }

print("""

  ── HangyeolIME secure input 회귀 테스트 ─────────────────────
  암호 프롬프트와 같은 조건(secure input ON)을 만들고,
  입력한 내용을 그대로 보여줍니다. 비밀번호는 필요 없습니다.

""")

let status = EnableSecureEventInput()
guard status == noErr, IsSecureEventInputEnabled() else {
    print("  ❌ secure input을 켜지 못했습니다 (status=\(status)).")
    exit(1)
}
print("  ✅ secure input ON — 지금이 암호 프롬프트와 같은 상태입니다.\n")
print("  한글 상태 그대로 abcd 치고 Enter > ", terminator: "")

let line = readLine(strippingNewline: true) ?? ""
DisableSecureEventInput()

print("""

  받은 것: [\(line)]

  ── 판정 ────────────────────────────────────────────────
    [abcd]  → ✅ 정상. 입력기가 조합을 멈추고 비켰습니다.
    [뮻ㅇ]  → ❌ 회귀. 입력기가 계속 조합하고 있습니다.
  ────────────────────────────────────────────────────────
  해제 확인: \(IsSecureEventInputEnabled() ? "❌ 아직 켜져 있음 — 화면 잠갔다 푸세요" : "✅ 정상 해제")

""")
