//
//  Hangul.swift
//  HangyeolIME
//
//  한글 오토마타. 키를 하나씩 받아 조합을 끝낸 글자(commit)와 조합 중인 글자(preedit)를
//  만든다. 입력기는 키마다 process()를 부르고 takeCommit()/takePreedit()로 결과를 가져간다.
//

import Foundation

// 한 글자의 조합 상태. 각 자리는 그 자모를 만든 키들이다(예: 종성 "fq" → ㄼ).
struct Composition {
    var choseong = ""
    var jungseong = ""
    var jongseong = ""
    // 이 글자의 조합이 끝났는지. 끝나면 소비한 키를 버퍼에서 뺀다.
    var done = false

    var keyCount: Int { choseong.count + jungseong.count + jongseong.count }
}

// 아직 확정되지 않은 키 버퍼에서 앞쪽부터 한 글자를 조립한다.
private struct Automata {
    var keys: [String] = []

    mutating func run() -> Composition {
        var comp = Composition()

        for key in keys {
            if Dubeolsik.acceptsChoseong(&comp, key) {
                addChoseong(&comp, key)
            } else if Dubeolsik.acceptsJungseong(&comp, key) {
                addJungseong(&comp, key)
            } else if Dubeolsik.acceptsJongseong(&comp, key) {
                addJongseong(&comp, key)
            } else {
                // 이 글자에 붙일 수 없는 키다. 글자를 끝내고 다음 글자에서 조합한다.
                comp.done = true
            }
            if comp.done {
                break
            }
        }
        if comp.done {
            keys.removeFirst(comp.keyCount)
        }
        return comp
    }

    private func addChoseong(_ comp: inout Composition, _ key: String) {
        if comp.choseong.isEmpty {
            comp.choseong = key
        } else if !comp.jungseong.isEmpty {
            // 초성·중성이 다 있는데 또 초성이 오면 다음 글자다.
            comp.done = true
        } else if Dubeolsik.acceptsChoseong(&comp, key) {
            comp.choseong += key
        } else {
            comp.done = true
        }
    }

    private func addJungseong(_ comp: inout Composition, _ key: String) {
        if comp.jungseong.isEmpty {
            comp.jungseong = key
        } else if Dubeolsik.acceptsJungseong(&comp, key) {
            // 이중 모음
            comp.jungseong += key
        } else {
            comp.done = true
        }
    }

    private func addJongseong(_ comp: inout Composition, _ key: String) {
        if comp.jongseong.isEmpty {
            comp.jongseong = key
        } else if Dubeolsik.acceptsJongseong(&comp, key) {
            // 겹받침
            comp.jongseong += key
        } else {
            comp.done = true
        }
    }
}

final class Hangul {
    private var automata = Automata()
    private var committed: [unichar] = []
    private var preedit: [unichar] = []

    // 키 하나를 넣는다. 한글 키가 아니면 false를 돌려주고 아무것도 하지 않는다.
    func process(_ key: String) -> Bool {
        guard Dubeolsik.isHangul(key) else { return false }

        automata.keys.append(key)
        var comp = automata.run()
        while comp.done {
            committed += Self.text(of: comp)
            comp = automata.run()
        }
        preedit += Self.text(of: comp)
        return true
    }

    // 조합 중인 글자에서 키 하나를 지운다. 지울 것이 없으면 false.
    func backspace() -> Bool {
        guard !automata.keys.isEmpty else { return false }

        automata.keys.removeLast()
        preedit += Self.text(of: automata.run())
        return true
    }

    // 조합 중인 글자를 완성 여부와 상관없이 확정한다.
    func flush() {
        committed += Self.text(of: automata.run())
        automata.keys = []
    }

    func takeCommit() -> [unichar] {
        defer { committed = [] }
        return committed
    }

    func takePreedit() -> [unichar] {
        defer { preedit = [] }
        return preedit
    }

    // 초성+중성이 있으면 완성형 음절 하나, 아니면 있는 자모를 호환 자모로 내보낸다.
    private static func text(of comp: Composition) -> [unichar] {
        let cho = Dubeolsik.choseong[comp.choseong]
        let jung = Dubeolsik.jungseong[comp.jungseong]
        let jong = Dubeolsik.jongseong[comp.jongseong]

        if let cho = cho, let jung = jung {
            // 0xAC00 + (초성 × 588) + (중성 × 28) + 종성
            let syllable = 0xAC00 + cho.index * 588 + jung.index * 28 + (jong?.index ?? 0)
            Log.debug("NFC: \(syllable)")
            return [unichar(syllable)]
        }

        let jamo = [cho?.compatibility, jung?.compatibility, jong?.compatibility].compactMap { $0 }
        if !jamo.isEmpty {
            Log.debug("NFD: \(jamo)")
        }
        return jamo
    }
}
