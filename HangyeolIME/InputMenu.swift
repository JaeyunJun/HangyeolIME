//
//  InputMenu.swift
//  HangyeolIME
//
//  메뉴 막대 입력기 메뉴. IMK가 menu()로 가져가 그린다.
//
//  [주의] 이 메뉴는 만든 뒤 절대 바꾸지 않는다(항목, 제목, 활성 상태 모두).
//  IMK는 menu()를 키마다 부르고(실측: 키 34번에 35번), 메뉴가 바뀌면 앱이 입력 세션을 껐다 켠다.
//  키마다 자모가 따로 확정됐고, 암호 입력으로 보안 입력이 켜지는 순간 메뉴를 바꾸자
//  카카오톡 채팅창이 앱을 다시 켤 때까지 영문으로 고정됐다. 상태는 창(PermissionWindow)에서 보여준다.
//

import Cocoa

enum InputMenu {
    static let menu: NSMenu = {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let item = NSMenuItem(title: "한결 상태 · 특수키 조합…",
                              action: #selector(HangyeolInputController.showPermissionWindow(_:)),
                              keyEquivalent: "")
        menu.addItem(item)
        return menu
    }()
}
