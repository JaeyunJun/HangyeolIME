//
//  ComposeBypass.swift
//  HangyeolIME
//
//  특정 키 패턴 직후의 키는 한글로 조합하지 않고 그대로 흘려보낸다.
//

import Foundation

final class ComposeBypass {
    static let shared = ComposeBypass()

    // keycode 패턴. 마지막 키가 들어온 순간 패턴이 완성되면 그 키를 영문으로 둔다.
    private let patterns: [[UInt16]] = [
        [0x32, 0x32, 0x32, 0x08],   // ```c  마크다운 코드 블록 시작, ```ㅊ 방지
        [0x1D, 0x07],               // 0x    16진수 접두사, 0ㅌ 방지
    ]

    // 가장 긴 패턴보다 길면 충분하다.
    private static let historyLimit = 10
    private var history: [UInt16] = []

    private init() {}

    func add(_ keyCode: UInt16) {
        history.append(keyCode)
        if history.count > Self.historyLimit {
            history.removeFirst()
        }
    }

    // 최근 키가 패턴과 일치하면 true. 일치한 키들은 기록에서 지워 같은 키로 다시 걸리지 않게 한다.
    func matches() -> Bool {
        for pattern in patterns where history.suffix(pattern.count).elementsEqual(pattern) {
            history.removeLast(pattern.count)
            return true
        }
        return false
    }
}
