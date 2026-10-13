//
//  NavilIMEInputController.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/4/22.
//

import InputMethodKit
import Carbon

@objc(NavilIMEInputController)
open class NavilIMEInputController: IMKInputController {
    // keycode → ASCII. 인덱스가 keycode다. 범위를 넘는 keycode(ESC, 화살표 등)는 그대로 흘려보낸다.
    // 빈칸(nil)은 문자가 아닌 키다: 10 ISO 배열의 §, 36 Return, 48 Tab.
    private static let keyMap = charMap("asdfhgzxcv bqweryt123465=97-80]ou[ip lj'k;\\,/nm. ␣`")
    private static let shiftKeyMap = charMap("ASDFHGZXCV BQWERYT!@#$^%+(&_*)}OU{IP LJ\"K:|<?NM> ␣~")

    // 표를 한눈에 보려고 공백을 '문자 없음', ␣를 스페이스 바로 적었다.
    private static func charMap(_ layout: String) -> [Character?] {
        return layout.map { $0 == " " ? nil : ($0 == "␣" ? " " : $0) }
    }

    private enum KeyCode {
        static let enter: UInt16 = 0x24
        static let tab: UInt16 = 0x30
        static let backspace: UInt16 = 0x33
    }

    private var hangul = Hangul()

    // 지금 입력을 받고 있는 컨트롤러. SpecialKeyTap(탭 스레드)이 "한글 입력기가 켜져 있나"를
    // 판단하고 특수키를 넘겨주는 데 쓴다. 탭 스레드와 메인 스레드가 함께 만지므로 잠금으로 보호한다.
    private static let activeLock = NSLock()
    private static weak var activeController: NavilIMEInputController?

    static var active: NavilIMEInputController? {
        activeLock.lock()
        defer { activeLock.unlock() }
        return activeController
    }

    // onlyIf를 주면, 지금 활성 컨트롤러가 그것일 때만 바꾼다.
    private static func setActive(_ controller: NavilIMEInputController?, onlyIf current: NavilIMEInputController? = nil) {
        activeLock.lock()
        defer { activeLock.unlock() }
        if current == nil || activeController === current {
            activeController = controller
        }
    }

    override open func activateServer(_ sender: Any!) {
        super.activateServer(sender)

        Log.debug("Activated: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        Self.setActive(self)
        InputSource.disarmRecovery()
        hangul = Hangul()
    }

    override open func deactivateServer(_ sender: Any!) {
        Log.debug("Deactivated: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")

        // 세션을 정리(super)하기 전에 조합 중이던 글자를 이전 client로 먼저 확정한다.
        // super를 먼저 부르면 포커스가 새 앱으로 넘어간 뒤 commit돼, 그 글자가
        // 새 창(예: Raycast)으로 새어 "이전 입력기 것과 섞이는" 현상이 생길 수 있다.
        hangul.flush()
        updateDisplay(client: sender)

        // 다른 컨트롤러가 이미 활성화됐다면(deactivate가 늦게 오는 경우) 그쪽을 지우지 않는다.
        Self.setActive(nil, onlyIf: self)
        InputSource.armRecovery()
        super.deactivateServer(sender)
    }

    override open func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        switch event.type {
        case .keyDown:
            // 입력기 프로세스가 새로 뜨면(재설치 등) macOS가 activateServer 없이 바로 handle을
            // 부르기도 한다. 그러면 SpecialKeyTap이 한글 상태를 몰라 특수키가 깨지므로 여기서도 표시한다.
            Self.setActive(self)
            let eaten = handleKeyDown(event, client: sender)
            if !eaten {
                commitComposition(sender)
            }
            return eaten
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
            commitComposition(sender)
        default:
            Log.debug("unhandled event keycode=\(event.keyCode) modifiers=\(event.modifierFlags.rawValue)")
        }
        return false
    }

    private func handleKeyDown(_ event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // secure input이 켜진 동안(sudo 암호 프롬프트, 잠금 해제, 암호 필드 등)에는
        // 조합하지 않고 키를 그대로 흘려보낸다. macOS는 이 상황에서 입력 소스를 영문으로
        // 갈아주지 않으므로(확인함), 입력기가 스스로 비켜야 암호가 제대로 들어간다.
        //
        // 입력 소스는 건드리지 않는다 — 프롬프트를 빠져나오면 원래 상태 그대로다.
        // 호출 비용은 ~4ns라 매 키 입력마다 확인해도 무방하다.
        //
        // [주의] secure input은 프로세스 전역 참조 카운트라, 어떤 앱이 켜놓고 끄지 않으면
        // 한글이 어디서도 조합되지 않는다. 그 증상이면 화면을 잠갔다 풀면 풀린다.
        if IsSecureEventInputEnabled() || TTYPasswordWatcher.shared.isPasswordPromptActive() {
            hangul.flush()
            updateDisplay(client: client)
            return false
        }

        // 입력 소스가 이미 다른 것(예: ABC)으로 바뀌었는데, 그 소식이 앱에 닿아 입력기가 꺼지기
        // 전에 들어온 키다. Raycast처럼 열리면서 영문으로 바꾸는 앱에 바로 타이핑하면 첫 글자가
        // 여기로 온다. 한글로 조합하지 않고 그대로 흘려보낸다. 누가 전환했든 같다.
        // 확인 비용은 키당 약 20~40µs(실측).
        if !InputSource.isNavilSelected() {
            Log.debug("Source already switched away, passing key \(keyCode)")
            hangul.flush()
            updateDisplay(client: client)
            return false
        }

        // ⌘·⌥·⌃ 조합은 단축키다. 입력기가 건드리지 않는다.
        // Hotfix 기록에도 넣지 않는다 — 섞으면 패턴이 잘못 걸린다.
        if !flags.intersection([.command, .option, .control]).isEmpty {
            Log.debug("Modifier key \(keyCode) with \(flags.rawValue)")
            return false
        }

        // 특정 패턴 직후의 키는 한글로 바꾸지 않는다. (Hotfix 참조)
        Hotfix.shared.add(keyCode)
        if Hotfix.shared.check() {
            return false
        }

        if keyCode == KeyCode.enter || keyCode == KeyCode.tab {
            Log.debug("Enter or Tab")
            hangul.flush()
            updateDisplay(client: client)
            return false
        }

        if keyCode == KeyCode.backspace {
            Log.debug("Backspace")
            let eaten = hangul.backspace()
            if eaten {
                updateDisplay(client: client, backspace: true)
            }
            return eaten
        }

        let index = Int(keyCode)
        guard index < Self.keyMap.count,
              let char = flags.contains(.shift) ? Self.shiftKeyMap[index] : Self.keyMap[index] else {
            Log.debug("Bypassed keycode: \(keyCode)")
            hangul.flush()
            updateDisplay(client: client)
            return false
        }

        let key = String(char)
        if hangul.process(key) {
            updateDisplay(client: client)
        } else {
            Log.debug("Not Hangul: \(key)")
            hangul.flush()
            updateDisplay(client: client, additional: key)
        }
        return true
    }

    // SpecialKeyTap이 메인 스레드에서 부른다. 탭은 한글 입력기가 켜져 있으면 특수키 이벤트를
    // 삼키고 여기로 넘긴다 — 탭이 문자를 바꿔 넣은 이벤트는 입력기의 handle까지 오지 않기
    // 때문이다(로그로 확인). 조합 중인 글자를 먼저 확정하고 그 뒤에 붙인다.
    //
    // 바로 insertText 하지 않고 marked text로 한 번 올렸다가 확정한다. xterm.js 계열 터미널
    // (예: Orca)은 키가 눌린 채(Shift·⌘) 들어오는 일반 텍스트 입력을 무시하지만, 조합 확정으로
    // 들어오는 글자는 받는다. 일반 앱에서는 결과가 같다.
    func insertSpecial(_ output: String) {
        guard let client = client() as? IMKTextInput else {
            Log.debug("insertSpecial: no client")
            return
        }
        hangul.flush()
        let commitUnits = hangul.takeCommit()
        _ = hangul.takePreedit()
        let text = String(utf16CodeUnits: commitUnits, count: commitUnits.count) + output
        Log.debug("Special: '\(text)'")

        let noReplacement = NSRange(location: NSNotFound, length: NSNotFound)
        let caret = NSRange(location: (text as NSString).length, length: 0)
        client.setMarkedText(text, selectionRange: caret, replacementRange: noReplacement)
        client.insertText(text, replacementRange: noReplacement)
    }

    // 오토마타 결과를 클라이언트에 반영한다. 확정분(+additional)은 insertText로, 조합 중인
    // 글자는 setMarkedText로 보낸다.
    private func updateDisplay(client: Any!, backspace: Bool = false, additional: String = "") {
        let commitUnits = hangul.takeCommit()
        let preeditUnits = hangul.takePreedit()

        // 출력할 내용이 전혀 없으면 IMKTextInput 호출을 건너뛴다.
        if commitUnits.isEmpty && preeditUnits.isEmpty && additional.isEmpty && !backspace {
            return
        }

        let preedit = String(utf16CodeUnits: preeditUnits, count: preeditUnits.count)
        let commit = String(utf16CodeUnits: commitUnits, count: commitUnits.count) + additional
        Log.debug("Commit: '\(commit)' Preedit: '\(preedit)'")

        guard let client = client as? IMKTextInput else { return }

        let noReplacement = NSRange(location: NSNotFound, length: NSNotFound)
        if !commit.isEmpty {
            client.insertText(commit, replacementRange: noReplacement)
        }

        // 백스페이스로 조합 중인 글자를 다 지운 경우에도 길이 0인 marked text를 명시적으로
        // 넘겨야 자연스럽게 지워진다. 길이는 UTF-16 단위라 NSString.length를 쓴다.
        if !preedit.isEmpty || backspace {
            let selection = NSRange(location: 0, length: (preedit as NSString).length)
            client.setMarkedText(preedit, selectionRange: selection, replacementRange: noReplacement)
        }
    }

    // 클라이언트가 조합을 즉시 끝내려 할 때 부른다. 조합 중인 글자를 확정한다.
    override open func commitComposition(_ sender: Any!) {
        Log.debug("Commit Composition")
        hangul.flush()
        updateDisplay(client: sender)
    }

    // 입력기가 받을 이벤트 종류.
    // 드래그는 프레임마다 들어와 매번 commit이 불리므로 뺐다.
    override open func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged,
            .leftMouseUp, .rightMouseUp, .leftMouseDown, .rightMouseDown,
            .appKitDefined, .applicationDefined, .systemDefined).rawValue)
    }

    // 텍스트를 클릭하면 조합을 끝내고 확정한다.
    override open func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint, withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!, client sender: Any!) -> Bool {
        Log.debug("Mouse Down")
        commitComposition(sender)
        return false
    }

    // 트레이 메뉴를 그릴 때마다 불린다.
    override open func menu() -> NSMenu! {
        // 권한이 방금 허용됐다면 탭을 켜고, 메뉴 표시 상태도 갱신한다.
        SpecialKeyTap.shared.startIfTrusted()
        HangulMenu.shared.refresh()
        return HangulMenu.shared.menu
    }

    // [IMK 메뉴 액션 주의]
    // 메뉴 항목의 action은 NSMenu가 어디 있든 반드시 이 컨트롤러에 있어야 한다.
    // sender도 NSMenuItem이 아니라 IMK가 만든 Dictionary이고, 항목은
    // sender["IMKCommandMenuItem"]에 들어 있다. (공식 문서에 없음, 원작자가 찾아낸 것)

    // 특수키(₩, ~, `)는 전역 이벤트 탭이 유일한 처리 경로라 손쉬운 사용 권한이 필요하다.
    // 실제 권한·탭 상태를 보여주고 설정으로 보내는 상태 창을 연다. (PermissionWindow 참조)
    @objc func showPermissionWindow(_ sender: Any?) {
        PermissionWindow.shared.show()
    }
}
