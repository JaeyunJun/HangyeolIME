//
//  InputMenu.swift
//  HangyeolIME
//
//  메뉴 막대 입력기 메뉴. IMK가 menu()로 가져가 그린다.
//
//  [주의] IMK는 menu()를 키를 칠 때마다 부른다(실측: 키 34번에 35번). 메뉴 구성이 평소와
//  달라지면 앱이 입력기를 껐다 켜서 조합 중이던 글자가 확정돼 버린다(키마다 자모가 따로
//  들어감). 숨긴 항목을 두는 것만으로도 그랬다. 그래서 평소 메뉴는 항목 하나로 고정하고,
//  일시 중지 상태가 생기거나 풀리는 순간에만 항목을 넣고 뺀다.
//

import Cocoa
import Carbon
import IOKit

final class InputMenu {
    static let shared = InputMenu()

    let menu = NSMenu()

    // 특수키(₩, ~, `) 권한 상태. 누르면 권한 상태 창이 열린다.
    // 이 권한이 없으면 특수키 조합은 한글/영문 어느 쪽에서도 동작하지 않는다.
    private let permissionItem = NSMenuItem()

    // 입력기가 일부러 조합을 멈춘 이유. 메뉴 막대는 한글인데 영문이 나올 때 바로 알 수 있게
    // 메뉴 맨 위에 보여준다. 멈추지 않았으면 메뉴에 넣지 않는다.
    private var pauseReason: String?

    private init() {
        permissionItem.action = #selector(HangyeolInputController.showPermissionWindow(_:))
        menu.addItem(permissionItem)
        menu.autoenablesItems = true
        refresh()
    }

    // menu()에서 부른다.
    func refresh() {
        refreshPauseState()
        refreshPermissionState()
    }

    // 실제 권한과 탭 상태를 제목에 보여준다. 어느 상태든 누르면 권한 상태 창이 열린다.
    func refreshPermissionState() {
        let tap = SpecialKeyTap.shared
        if !tap.isTrusted {
            permissionItem.title = "특수키 조합: 꺼짐 (선택 기능) — 자세히…"
        } else if !tap.isActive {
            permissionItem.title = "특수키 조합: 권한 있음, 탭 꺼짐 ⚠️…"
        } else {
            permissionItem.title = "특수키 조합: 켜짐 ✓…"
        }
        permissionItem.isEnabled = true
    }

    private func refreshPauseState() {
        let reason: String?
        if TTYPasswordWatcher.shared.holdingSecureInput {
            reason = "한글 일시 중지: 터미널 암호 입력 감지"
        } else if IsSecureEventInputEnabled() {
            reason = "한글 일시 중지: ‘\(secureInputOwnerName())’이(가) 보안 입력을 켜 둠 (화면 잠금 후 풀면 해제)"
        } else {
            reason = nil
        }
        guard reason != pauseReason else { return }
        pauseReason = reason

        menu.removeAllItems()
        if let reason = reason {
            menu.addItem(withTitle: reason, action: nil, keyEquivalent: "")
            menu.addItem(.separator())
        }
        menu.addItem(permissionItem)
    }

    // menu()가 키마다 불리므로, 이름은 secure input을 쥔 pid가 바뀔 때만 다시 묻는다
    // (NSRunningApplication은 LaunchServices에 XPC로 묻는다).
    private var ownerCache: (pid: pid_t?, name: String)?

    private func secureInputOwnerName() -> String {
        let pid = Self.secureInputOwnerPID()
        if let cache = ownerCache, cache.pid == pid {
            return cache.name
        }
        let name = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? "다른 앱"
        ownerCache = (pid, name)
        return name
    }

    // 지금 secure input을 켜 둔 프로세스. WindowServer가 IORegistry에 기록해 둔다.
    private static func secureInputOwnerPID() -> pid_t? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        guard let users = IORegistryEntryCreateCFProperty(root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [[String: Any]] else { return nil }
        return users.lazy.compactMap { $0["kCGSSessionSecureInputPID"] as? Int }.first.map(pid_t.init)
    }
}
