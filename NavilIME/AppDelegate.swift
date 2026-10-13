//
//  AppDelegate.swift
//  NavilIME
//
//  Created by Manwoo Yi on 9/3/22.
//

import Cocoa
import InputMethodKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    // IMK가 입력 세션을 연결하는 서버. 앱이 사는 동안 붙잡고 있어야 한다.
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        server = IMKServer(name: Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String,
                           bundleIdentifier: Bundle.main.bundleIdentifier)

        // 손쉬운 사용 권한이 이미 있으면 전역 특수키 탭을 켠다.
        // 권한이 없으면 입력기 메뉴의 권한 상태 창에서 허용한다.
        SpecialKeyTap.shared.startIfTrusted()

        // 터미널 암호 프롬프트(sudo/ssh/git 등) 감시 시작.
        // 권한이 필요 없고, tty의 termios만 읽는다.
        TTYPasswordWatcher.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 우리가 쥔 secure input을 반드시 되돌린다.
        TTYPasswordWatcher.shared.stop()
    }
}
