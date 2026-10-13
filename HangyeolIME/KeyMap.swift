//
//  KeyMap.swift
//  HangyeolIME
//
//  macOS 가상 키코드 → 문자. 물리 키 위치(US 배열) 기준이라 두벌식 자판 배치와 맞는다.
//

import Foundation

enum KeyMap {
    static let enter: UInt16 = 0x24
    static let tab: UInt16 = 0x30
    static let backspace: UInt16 = 0x33

    // 인덱스가 keycode다. 공백은 '문자 없음'(10 ISO 배열의 §, 36 Return, 48 Tab), ␣는 스페이스 바.
    // 범위를 넘는 keycode(ESC, 화살표 등)도 문자가 없다.
    private static let plain = table("asdfhgzxcv bqweryt123465=97-80]ou[ip lj'k;\\,/nm. ␣`")
    private static let shifted = table("ASDFHGZXCV BQWERYT!@#$^%+(&_*)}OU{IP LJ\"K:|<?NM> ␣~")

    // 문자가 없는 키면 nil.
    static func character(for keyCode: UInt16, shift: Bool) -> Character? {
        let index = Int(keyCode)
        guard index < plain.count else { return nil }
        return shift ? shifted[index] : plain[index]
    }

    private static func table(_ layout: String) -> [Character?] {
        return layout.map { $0 == " " ? nil : ($0 == "␣" ? " " : $0) }
    }
}
