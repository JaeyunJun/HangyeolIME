//
//  InputSession.swift
//  HangyeolIME
//
//  입력 세션 상태: 지금 입력을 받고 있는 컨트롤러와, 끊긴 세션 복구.
//
//  [현재 컨트롤러] SpecialKeyTap(탭 스레드)이 "한글 입력기가 켜져 있나"를 판단하고 특수키를
//  넘기는 데 쓴다. 탭 스레드와 메인 스레드가 함께 만지므로 잠금으로 보호한다.
//
//  [끊긴 세션] 메뉴 막대는 HangyeolIME인데 키가 입력기를 거치지 않고 앱으로 바로 가서 영문이
//  나오는 상태. 앱이 입력기를 켰다가 곧바로 끄고 다시 켜지 않으면 생긴다. 입력기는 키를 받지
//  못하므로 모든 키를 보는 탭이 알아채고, 입력 소스를 ABC로 갔다가 HangyeolIME로 되돌려 다시
//  붙인다. 입력창이 없는 화면에서 깜빡이지 않게, 입력기가 꺼질 때마다 한 번만 시도한다.
//  복구 상태는 메인 스레드에서만 만진다.
//

import Foundation

final class InputSession {
    static let shared = InputSession()

    private let lock = NSLock()
    private weak var activeController: HangyeolInputController?

    private var recoveryArmed = false
    private var deactivatedAt: TimeInterval = 0

    // 앱이 입력창을 다시 만들 때(예: Orca에서 Enter) 입력기가 꺼졌다 약 100ms 뒤 다시 켜진다.
    // 그 사이의 키는 끊긴 게 아니므로, 꺼진 뒤 이만큼 지나도 안 켜졌을 때만 끊긴 것으로 본다.
    private static let detachGrace: TimeInterval = 0.3

    private init() {}

    // 지금 입력을 받고 있는 컨트롤러. 어느 스레드에서든 읽을 수 있다.
    var current: HangyeolInputController? {
        lock.lock()
        defer { lock.unlock() }
        return activeController
    }

    // 메인 스레드. activateServer, 그리고 activateServer 없이 handle이 불리는 경우(입력기 프로세스가
    // 새로 뜬 직후)에도 부른다.
    func activated(_ controller: HangyeolInputController) {
        setCurrent(controller)
        recoveryArmed = false
    }

    // 메인 스레드. 다른 컨트롤러가 이미 활성화됐다면(deactivate가 늦게 오는 경우) 그쪽을 지우지 않는다.
    func deactivated(_ controller: HangyeolInputController) {
        lock.lock()
        if activeController === controller {
            activeController = nil
        }
        lock.unlock()
        recoveryArmed = true
        deactivatedAt = ProcessInfo.processInfo.systemUptime
    }

    // 메인 스레드. 탭이 "켜진 입력창 없이 글자 키가 눌림"을 알릴 때.
    func keyPressedWithoutSession() {
        guard recoveryArmed,
              ProcessInfo.processInfo.systemUptime - deactivatedAt > Self.detachGrace else { return }
        recoveryArmed = false
        // ABC 등 다른 입력 소스면 입력기가 꺼진 게 정상이다.
        guard InputSource.isHangyeolSelected(),
              let hangyeol = InputSource.hangyeol(), let ascii = InputSource.asciiLayout() else { return }

        Log.debug("Session detached while HangyeolIME selected, reattaching")
        InputSource.select(ascii)
        // 같은 순간에 되돌리면 전환이 합쳐져 아무 일도 안 일어날 수 있어 잠깐 띄운다.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
            InputSource.select(hangyeol)
        }
    }

    private func setCurrent(_ controller: HangyeolInputController) {
        lock.lock()
        activeController = controller
        lock.unlock()
    }
}
