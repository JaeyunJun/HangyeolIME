//
//  PermissionWindow.swift
//  NavilIME
//
//  특수키 전역 입력(손쉬운 사용) 권한 상태 창. 시스템 설정 목록의 표시가 아니라 프로세스가
//  실제로 받은 권한(AXIsProcessTrusted)과 탭이 실제로 도는지를 보여준다(서명이 바뀌면 둘이
//  어긋난다). 떠 있는 동안 1초마다 다시 조회하고, 권한이 잡히는 순간 탭을 켠다.
//

import Cocoa

final class PermissionWindow: NSObject, NSWindowDelegate {
    static let shared = PermissionWindow()

    private var window: NSWindow?
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let openButton = NSButton(title: "손쉬운 사용 설정 열기", target: nil, action: nil)
    private var timer: Timer?
    private var previousPolicy: NSApplication.ActivationPolicy = .prohibited

    private override init() {
        super.init()
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }

        // LSBackgroundOnly 앱은 창이 앞으로 오지 않으므로, 떠 있는 동안만 accessory로 올린다.
        // 이미 떠 있는 창을 다시 부르면 accessory를 원래 값으로 잘못 기억하므로 처음에만 저장한다.
        if window?.isVisible != true {
            previousPolicy = NSApp.activationPolicy()
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        refresh()
        window?.center()
        window?.makeKeyAndOrderFront(nil)

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "NavilIME 특수키 권한"
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.delegate = self

        statusLabel.font = NSFont.boldSystemFont(ofSize: 15)
        detailLabel.font = NSFont.systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.preferredMaxLayoutWidth = 380

        openButton.target = self
        openButton.action = #selector(openSettings)
        let checkButton = NSButton(title: "다시 확인", target: self, action: #selector(checkNow))
        let closeButton = NSButton(title: "닫기", target: self, action: #selector(close))
        closeButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [openButton, checkButton, NSView(), closeButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [statusLabel, detailLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        w.contentView = stack
        return w
    }

    // 실제 권한과 탭 상태를 다시 조회해 표시한다. 권한이 방금 잡혔으면 탭을 켠다.
    private func refresh() {
        let tap = SpecialKeyTap.shared
        if tap.isTrusted {
            tap.startIfTrusted()
        }

        if !tap.isTrusted {
            statusLabel.stringValue = "❌ 권한 없음 — 특수키 조합이 동작하지 않습니다"
            detailLabel.stringValue = "‘손쉬운 사용 설정 열기’를 눌러 목록에서 NavilIME를 켜세요. "
                + "켜면 이 창이 자동으로 갱신됩니다.\n\n"
                + "목록에 NavilIME가 이미 켜져 있는데도 계속 ‘권한 없음’이면, 재빌드로 서명이 "
                + "바뀐 것입니다. 목록에서 NavilIME를 선택해 −로 지운 뒤 다시 추가하세요."
            openButton.isEnabled = true
        } else if !tap.isActive {
            // 권한 직후에는 탭 스레드가 뜨는 동안 잠깐 이 상태일 수 있다. 다음 조회에서 갱신된다.
            statusLabel.stringValue = "⚠️ 권한 있음 — 특수키 탭이 아직 꺼져 있습니다"
            detailLabel.stringValue = "잠시 뒤에도 그대로면 입력기를 한 번 전환하거나 다시 로그인하세요."
            openButton.isEnabled = true
        } else {
            statusLabel.stringValue = "✅ 권한 있음 — 특수키 조합 동작 중"
            detailLabel.stringValue = "Shift+ESC → ~,  Cmd+ESC → `,  Cmd+\\ → ₩\n"
                + "한글·영문 어느 입력 소스에서든 동작합니다."
            openButton.isEnabled = false
        }
        InputMenu.shared.refreshPermissionState()
    }

    @objc private func openSettings() {
        // 시스템 권한 창을 띄우면 목록에 NavilIME가 (꺼진 채로) 올라온다. 설정 창도 함께 연다.
        SpecialKeyTap.shared.requestPermissionPrompt()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func checkNow() {
        refresh()
    }

    @objc private func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        NSApp.setActivationPolicy(previousPolicy)
    }
}
