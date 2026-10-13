//
//  InputSource.swift
//  HangyeolIME
//
//  시스템 입력 소스 조회와 전환. 상태를 갖지 않는다.
//

import Carbon
import Foundation

enum InputSource {
    // 시스템의 현재 입력 소스가 HangyeolIME인가. 다른 프로세스가 바꿔도 바로 반영된다.
    // 입력 소스 ID는 입력 모드 ID(...HangyeolIME.Dubeolsik)라 번들 ID로 비교한다.
    static func isHangyeolSelected() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        return isHangyeol(source)
    }

    // 선택할 수 있는 HangyeolIME 입력 모드.
    static func hangyeol() -> TISInputSource? {
        return enabledKeyboardSources(asciiOnly: false).first(where: isHangyeol)
    }

    // ASCII 가능한 '키보드 레이아웃'만 고른다. 입력 모드까지 포함하면 다른 언어 입력기가
    // 걸릴 수 있다. 보통 ABC가 잡힌다.
    static func asciiLayout() -> TISInputSource? {
        return enabledKeyboardSources(asciiOnly: true).first { source in
            guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else { return false }
            return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String == kTISTypeKeyboardLayout as String
        }
    }

    static func select(_ source: TISInputSource) {
        TISSelectInputSource(source)
    }

    private static func isHangyeol(_ source: TISInputSource) -> Bool {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyBundleID) else { return false }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String == Bundle.main.bundleIdentifier
    }

    private static func enabledKeyboardSources(asciiOnly: Bool) -> [TISInputSource] {
        var filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsSelectCapable as String: true,
            kTISPropertyInputSourceIsEnabled as String: true,
        ]
        if asciiOnly {
            filter[kTISPropertyInputSourceIsASCIICapable as String] = true
        }
        return TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue()
            as? [TISInputSource] ?? []
    }
}
