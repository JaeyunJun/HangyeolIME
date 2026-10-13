//
//  PermissionWindow.swift
//  HangyeolIME
//
//  한결 상태 창(입력기 메뉴의 유일한 항목). 위에는 한글 조합을 일부러 멈춘 이유(터미널 암호,
//  다른 앱의 보안 입력)를, 아래에는 특수키 조합(선택 기능)의 손쉬운 사용 권한을 보여준다.
//  상태를 메뉴에 띄우지 않는 이유는 InputMenu 참조.
//
//  권한: 왜 필요한지 설명하고, 버튼 하나로 macOS 권한 요청을 띄운다. 시스템 설정 목록의 표시가 아니라 프로세스가 실제로 받은 권한(AXIsProcessTrusted)과
//  탭이 실제로 도는지를 보여준다(서명이 바뀌면 둘이 어긋난다).
//
//  떠 있는 동안 1초마다 다시 조회하고, 권한이 잡히는 순간 탭을 켠 뒤 잠시 후 스스로 닫힌다.
//  macOS 권한 요청 창이 이 창에 가리지 않도록 일반 창 레벨을 쓰고, 설정 창을 따로 열지 않는다
//  (요청 창의 "시스템 설정 열기"가 그 일을 한다).
//

import Cocoa
import Carbon
import IOKit

final class PermissionWindow: NSObject, NSWindowDelegate {
    static let shared = PermissionWindow()

    private static let autoCloseDelay: TimeInterval = 3

    private var window: NSWindow?
    private let inputLabel = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(wrappingLabelWithString: "")
    private let requestButton = NSButton(title: "권한 허용하기", target: nil, action: nil)
    private let settingsButton = NSButton(title: "시스템 설정 열기", target: nil, action: nil)
    private var timer: Timer?
    private var previousPolicy: NSApplication.ActivationPolicy = .prohibited

    // 창을 열 때 권한이 없었으면, 권한이 잡히는 순간 자동으로 닫는다.
    private var waitingForGrant = false
    private var requested = false
    private var closeScheduled = false

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
            waitingForGrant = !SpecialKeyTap.shared.isTrusted
            requested = false
            closeScheduled = false
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
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 260),
                         styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "한결 상태"
        w.isReleasedWhenClosed = false
        w.delegate = self

        let explanation = NSTextField(wrappingLabelWithString:
            "Shift+ESC → ~,  ⌘ESC → `,  ⌘\\ → ₩ 세 조합을 위한 선택 기능입니다. "
            + "68배열처럼 ` 키가 따로 없는 키보드를 쓰는 제작자의 취향으로 넣었습니다.\n\n"
            + "조합을 가로채려면 모든 키 입력을 볼 수 있어야 해서 macOS가 ‘손쉬운 사용’ 권한을 요구합니다. "
            + "한결은 이 세 조합 말고는 키를 건드리지 않고, 아무것도 기록하거나 내보내지 않습니다.\n\n"
            + "한글 입력은 이 권한 없이도 그대로 됩니다. 필요 없으면 허용하지 않아도 됩니다.")
        explanation.font = NSFont.systemFont(ofSize: 12)
        explanation.preferredMaxLayoutWidth = 420

        inputLabel.font = NSFont.boldSystemFont(ofSize: 14)
        inputLabel.preferredMaxLayoutWidth = 420
        let keysTitle = NSTextField(labelWithString: "특수키 조합 (선택)")
        keysTitle.font = NSFont.boldSystemFont(ofSize: 13)
        let divider = NSBox()
        divider.boxType = .separator

        statusLabel.font = NSFont.boldSystemFont(ofSize: 14)
        detailLabel.font = NSFont.systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.preferredMaxLayoutWidth = 420

        requestButton.target = self
        requestButton.action = #selector(requestPermission)
        requestButton.keyEquivalent = "\r"
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        let closeButton = NSButton(title: "닫기", target: self, action: #selector(close))
        closeButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [requestButton, settingsButton, NSView(), closeButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [inputLabel, divider, keysTitle, explanation, statusLabel, detailLabel, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(18, after: explanation)
        divider.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        w.contentView = stack
        return w
    }

    // 실제 권한과 탭 상태를 다시 조회해 표시한다. 권한이 방금 잡혔으면 탭을 켜고 닫기를 예약한다.
    private func refresh() {
        inputLabel.stringValue = pauseReason() ?? "한글 입력: 정상"

        let tap = SpecialKeyTap.shared
        if tap.isTrusted {
            tap.startIfTrusted()
        }

        if !tap.isTrusted {
            statusLabel.stringValue = "꺼짐 — 권한 없음"
            if requested {
                detailLabel.stringValue = "macOS 창에서 ‘시스템 설정 열기’를 눌러 목록의 한결(HangyeolIME)을 켜세요. "
                    + "켜면 이 창이 알아서 확인하고 닫힙니다.\n"
                    + "창이 뜨지 않거나, 목록에 이미 켜져 있는데도 그대로면(재빌드로 서명이 바뀐 경우) "
                    + "목록에서 한결을 −로 지운 뒤 다시 켜세요."
            } else {
                detailLabel.stringValue = "‘권한 허용하기’를 누르면 macOS 권한 요청 창이 뜹니다."
            }
            requestButton.isHidden = false
            settingsButton.isHidden = !requested
        } else if !tap.isActive {
            // 권한 직후에는 탭 스레드가 뜨는 동안 잠깐 이 상태일 수 있다. 다음 조회에서 갱신된다.
            statusLabel.stringValue = "⚠️ 권한 있음 — 특수키 탭을 켜는 중"
            detailLabel.stringValue = "잠시 뒤에도 그대로면 입력기를 한 번 전환하거나 다시 로그인하세요."
            requestButton.isHidden = true
            settingsButton.isHidden = true
        } else {
            statusLabel.stringValue = "✅ 켜짐 — 특수키 조합 동작 중"
            requestButton.isHidden = true
            settingsButton.isHidden = true
            if waitingForGrant {
                waitingForGrant = false
                closeScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoCloseDelay) { [weak self] in
                    guard let self = self, self.closeScheduled else { return }
                    self.close()
                }
            }
            detailLabel.stringValue = closeScheduled
                ? "권한이 확인됐습니다. \(Int(Self.autoCloseDelay))초 뒤 이 창이 자동으로 닫힙니다."
                : "한글·영문 어느 입력 소스에서든 동작합니다."
        }
    }

    // 한글 조합을 일부러 멈춘 이유. 멈추지 않았으면 nil.
    private func pauseReason() -> String? {
        if TTYPasswordWatcher.shared.holdingSecureInput {
            return "한글 일시 중지: 터미널 암호 입력 감지"
        }
        if IsSecureEventInputEnabled() {
            let name = Self.secureInputOwnerPID()
                .flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? "다른 앱"
            return "한글 일시 중지: ‘\(name)’이(가) 보안 입력을 켜 둠\n"
                + "암호 입력이 끝났는데도 그대로면 화면을 잠갔다 풀면 해제됩니다."
        }
        return nil
    }

    // 지금 secure input을 켜 둔 프로세스. WindowServer가 IORegistry에 기록해 둔다.
    private static func secureInputOwnerPID() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard let users = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [[String: Any]] else { return nil }
        return users.lazy.compactMap { $0["kCGSSessionSecureInputPID"] as? Int }.first.map(pid_t.init)
    }

    // macOS 권한 요청 창을 띄운다. 이 창은 일반 레벨이라 요청 창이 위에 뜬다.
    @objc private func requestPermission() {
        requested = true
        SpecialKeyTap.shared.requestPermissionPrompt()
        refresh()
    }

    // 요청 창이 뜨지 않을 때(이미 목록에 있는 경우 등)를 위한 직접 경로.
    @objc private func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        closeScheduled = false
        NSApp.setActivationPolicy(previousPolicy)
    }
}
