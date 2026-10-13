//
//  NavilIMEInputController.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/4/22.
//
//  입력기 본체. IMK가 입력창(클라이언트)마다 하나씩 만든다. 키를 받아 한글 엔진(Hangul)에
//  넣고, 결과를 클라이언트에 조합 중(marked text)/확정(insertText)으로 반영한다.
//

import InputMethodKit
import Carbon

@objc(NavilIMEInputController)
final class NavilIMEInputController: IMKInputController {
    private var hangul = Hangul()

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        Log.debug("Activated: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        InputSession.shared.activated(self)
        hangul = Hangul()
    }

    override func deactivateServer(_ sender: Any!) {
        Log.debug("Deactivated: \((sender as? IMKTextInput)?.bundleIdentifier() ?? "?")")
        // super보다 먼저 이전 클라이언트에 확정한다. super를 먼저 부르면 포커스가 새 앱으로
        // 넘어간 뒤 확정돼, 조합 중이던 글자가 새 창(예: Raycast)으로 샌다.
        hangul.flush()
        updateDisplay(client: sender)
        InputSession.shared.deactivated(self)
        super.deactivateServer(sender)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        switch event.type {
        case .keyDown:
            // 입력기 프로세스가 새로 뜬 직후에는 activateServer 없이 handle이 오기도 한다.
            InputSession.shared.activated(self)
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

    // 키를 먹었으면(입력기가 처리했으면) true, 앱이 처리하게 넘기면 false.
    private func handleKeyDown(_ event: NSEvent, client: Any!) -> Bool {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // 암호 입력 중(secure input, 또는 터미널 암호 프롬프트)에는 조합하지 않는다.
        // macOS는 이때 입력 소스를 영문으로 바꿔 주지 않으므로 입력기가 스스로 비켜야 한다.
        if IsSecureEventInputEnabled() || TTYPasswordWatcher.shared.isPasswordPromptActive() {
            return passThrough(client)
        }

        // 입력 소스가 이미 다른 것으로 바뀌었는데 그 소식이 앱에 닿기 전에 들어온 키다
        // (예: 열리면서 ABC로 바꾸는 Raycast에 바로 타이핑). 누가 바꿨든 조합하지 않는다.
        if !InputSource.isNavilSelected() {
            Log.debug("Source already switched away, passing key \(keyCode)")
            return passThrough(client)
        }

        // ⌘·⌥·⌃ 조합은 단축키다. ComposeBypass 기록에도 넣지 않는다(섞으면 패턴이 잘못 걸린다).
        if !flags.intersection([.command, .option, .control]).isEmpty {
            return false
        }

        ComposeBypass.shared.add(keyCode)
        if ComposeBypass.shared.matches() {
            return false
        }

        switch keyCode {
        case KeyMap.enter, KeyMap.tab:
            return passThrough(client)
        case KeyMap.backspace:
            let eaten = hangul.backspace()
            if eaten {
                updateDisplay(client: client, backspace: true)
            }
            return eaten
        default:
            break
        }

        guard let char = KeyMap.character(for: keyCode, shift: flags.contains(.shift)) else {
            return passThrough(client)
        }
        let key = String(char)
        if hangul.process(key) {
            updateDisplay(client: client)
        } else {
            hangul.flush()
            updateDisplay(client: client, additional: key)
        }
        return true
    }

    // 조합 중인 글자를 확정하고 키는 앱에 넘긴다.
    private func passThrough(_ client: Any!) -> Bool {
        hangul.flush()
        updateDisplay(client: client)
        return false
    }

    // SpecialKeyTap이 메인 스레드에서 부른다. 조합 중인 글자를 확정하고 그 뒤에 기호를 붙인다.
    //
    // marked text로 한 번 올렸다가 확정한다. xterm.js 계열 터미널(예: Orca)은 키가 눌린 채
    // (Shift·⌘) 들어오는 일반 텍스트 입력은 버리고 조합 확정으로 들어오는 글자만 받는다.
    // 일반 앱에서는 바로 넣는 것과 결과가 같다.
    func insertSpecial(_ output: String) {
        guard let client = client() else { return }
        hangul.flush()
        let commitUnits = hangul.takeCommit()
        _ = hangul.takePreedit()
        let text = String(utf16CodeUnits: commitUnits, count: commitUnits.count) + output

        let noReplacement = NSRange(location: NSNotFound, length: NSNotFound)
        let caret = NSRange(location: (text as NSString).length, length: 0)
        client.setMarkedText(text, selectionRange: caret, replacementRange: noReplacement)
        client.insertText(text, replacementRange: noReplacement)
    }

    // 엔진 결과를 클라이언트에 반영한다. 확정분(+additional)은 insertText, 조합 중인 글자는
    // setMarkedText.
    private func updateDisplay(client: Any!, backspace: Bool = false, additional: String = "") {
        let commitUnits = hangul.takeCommit()
        let preeditUnits = hangul.takePreedit()
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
        // 백스페이스로 조합 중인 글자를 다 지웠을 때도 길이 0인 marked text를 넘겨야 지워진다.
        // 길이는 UTF-16 단위라 NSString.length를 쓴다.
        if !preedit.isEmpty || backspace {
            let selection = NSRange(location: 0, length: (preedit as NSString).length)
            client.setMarkedText(preedit, selectionRange: selection, replacementRange: noReplacement)
        }
    }

    // 클라이언트가 조합을 끝내려 할 때. 조합 중인 글자를 확정한다.
    override func commitComposition(_ sender: Any!) {
        hangul.flush()
        updateDisplay(client: sender)
    }

    // 드래그는 프레임마다 들어와 매번 확정이 불리므로 뺐다.
    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask(arrayLiteral: .keyDown, .flagsChanged,
            .leftMouseUp, .rightMouseUp, .leftMouseDown, .rightMouseDown,
            .appKitDefined, .applicationDefined, .systemDefined).rawValue)
    }

    // 텍스트를 클릭하면 조합을 끝낸다.
    override func mouseDown(onCharacterIndex index: Int, coordinate point: NSPoint, withModifier flags: Int, continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>!, client sender: Any!) -> Bool {
        commitComposition(sender)
        return false
    }

    // IMK가 키마다 부른다. 메뉴 구성에 관한 제약은 InputMenu 참조.
    override func menu() -> NSMenu! {
        SpecialKeyTap.shared.startIfTrusted()   // 권한이 방금 허용됐으면 탭을 켠다
        InputMenu.shared.refresh()
        return InputMenu.shared.menu
    }

    // [IMK 메뉴 액션] 메뉴 항목의 action은 반드시 이 컨트롤러에 있어야 한다. sender는
    // NSMenuItem이 아니라 IMK가 만든 Dictionary다(항목은 sender["IMKCommandMenuItem"]).
    // 공식 문서에 없고 원작자가 찾아낸 것이다.
    @objc func showPermissionWindow(_ sender: Any?) {
        PermissionWindow.shared.show()
    }
}
