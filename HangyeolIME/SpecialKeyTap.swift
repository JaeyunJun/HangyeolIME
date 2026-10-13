//
//  SpecialKeyTap.swift
//  HangyeolIME
//
//  전역 키 가로채기(CGEventTap)로 특수키 조합(Shift+ESC → ~ 등)을 입력 소스와 상관없이 처리한다.
//
//  이 탭이 특수키의 유일한 처리 경로다. ⌘ 조합은 AppKit의 키 이퀴벌런트 단계에서 소비되어
//  입력기(IMK handle)까지 내려오지 않는다. 세션 레벨 탭은 AppKit보다 먼저 이벤트를 본다.
//
//  - 한글(HangyeolIME 활성): 이벤트를 삼키고 입력기에 넘긴다. 문자를 바꿔 넣은 이벤트는 입력기의
//    handle까지 오지 않아서(로그로 확인) 흘려보내면 아무것도 입력되지 않는다.
//    입력기가 조합 중인 글자를 확정하고 그 뒤에 기호를 붙인다(insertSpecial).
//  - 그 밖(영문 등): 모디파이어를 지우고 문자를 바꿔 넣어 앱으로 흘려보낸다.
//
//  모든 키를 보는 자리라, 끊긴 입력 세션을 알아채는 데도 쓴다(InputSession 참조).
//
//  동작하려면 App Sandbox가 꺼져 있고 손쉬운 사용(Accessibility) 권한이 있어야 한다.
//
//  [스레드] 탭은 전용 스레드의 런루프에서 돈다. 메인 런루프에 걸면 모든 키 입력이 메인
//  스레드(IMK 입력 경로)를 동기 통과해, 메인이 바쁜 순간 입력 지연이 생긴다.
//

import Cocoa
import ApplicationServices

struct SpecialKeyCombo {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let output: String
}

final class SpecialKeyTap {
    static let shared = SpecialKeyTap()

    // 매칭에 쓰는 모디파이어. 이 마스크로 걸러낸 뒤 '정확히 일치'를 요구하므로
    // Cmd+Shift+ESC 같은 확장 조합은 걸리지 않는다. Caps Lock과 fn은 일부러 뺐다 —
    // 켜져 있다고 조합이 깨지면 안 되기 때문이다.
    private static let matchedFlags: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

    private static let combos: [SpecialKeyCombo] = [
        SpecialKeyCombo(keyCode: 0x35, flags: .maskShift, output: "~"),     // Shift+ESC
        SpecialKeyCombo(keyCode: 0x35, flags: .maskCommand, output: "`"),   // Cmd+ESC
        SpecialKeyCombo(keyCode: 0x2A, flags: .maskCommand, output: "₩"),   // Cmd+\
    ]

    // 탭 스레드에서 만들어진다. 메인 스레드는 isActive로 읽기만 한다.
    private var eventTap: CFMachPort?
    private var tapThread: Thread?

    private init() {}

    var isTrusted: Bool {
        return AXIsProcessTrusted()
    }

    // 탭이 실제로 만들어져 켜져 있는지. 권한 상태 창과 메뉴가 쓴다.
    var isActive: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    // 시스템 권한 요청 창을 띄운다. 손쉬운 사용 목록에 HangyeolIME가 (꺼진 채로) 올라온다.
    func requestPermissionPrompt() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // 권한이 있고 아직 안 켜졌으면 탭을 켠다. 여러 번 불러도 된다.
    func startIfTrusted() {
        guard isTrusted, tapThread == nil else { return }

        let thread = Thread { [weak self] in
            guard let self = self else { return }
            guard self.createTap() else {
                // 비워 두면 다음 startIfTrusted()에서 다시 시도한다.
                DispatchQueue.main.async { self.tapThread = nil }
                return
            }
            Log.debug("SpecialKeyTap: started")
            CFRunLoopRun()
        }
        thread.name = "com.jaeyunjun.HangyeolIME.SpecialKeyTap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
    }

    // 탭 스레드에서 실행. 탭을 만들어 현재(전용) 런루프에 단다.
    private func createTap() -> Bool {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                return Unmanaged<SpecialKeyTap>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            Log.debug("SpecialKeyTap: tapCreate failed")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS가 부하/사용자 입력으로 탭을 끄면 다시 켠다.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // 입력기가 선택됐는데 켜진 입력창이 없는 상태에서 글자 키가 눌리면 세션이 끊긴 것일 수
        // 있다. 판단과 복구는 메인 스레드에서 한다. (InputSession 참조)
        if InputSession.shared.current == nil,
           event.flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            DispatchQueue.main.async { InputSession.shared.keyPressedWithoutSession() }
        }

        // 조합에 정확히 일치하지 않으면(거의 모든 키) 손대지 않고 즉시 통과한다.
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let matched = event.flags.intersection(Self.matchedFlags)
        guard let combo = Self.combos.first(where: { $0.keyCode == keyCode && $0.flags == matched }) else {
            return Unmanaged.passUnretained(event)
        }
        Log.debug("Special key \(keyCode) -> \(combo.output)")

        // 한글: 이벤트를 삼키고 입력기에 넘긴다. IMK 클라이언트 호출은 메인 스레드에서 해야 한다.
        if let controller = InputSession.shared.current {
            let output = combo.output
            DispatchQueue.main.async { controller.insertSpecial(output) }
            return nil
        }

        // 그 밖: 모디파이어를 지우고 문자를 갈아끼워 앱으로 흘려보낸다.
        event.flags = []
        let utf16 = Array(combo.output.utf16)
        event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        return Unmanaged.passUnretained(event)
    }
}
