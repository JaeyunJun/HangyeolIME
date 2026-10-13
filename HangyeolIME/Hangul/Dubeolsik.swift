//
//  Dubeolsik.swift
//  HangyeolIME
//
//  두벌식 자판 배치와 조합 규칙. 키는 ASCII 문자(Shift 반영)이고, 여러 키를 이어 붙인
//  문자열(예: "hk" → ㅘ)이 겹자모를 뜻한다.
//

import Foundation

enum Dubeolsik {
    // 쌍자음은 Shift 조합으로만 입력한다. 같은 자음 연타(예: dd)는 ㅇㅇ으로 분리된다.
    static let choseong: [String: Choseong] = [
        "Q": .ssangBieup, "W": .ssangJieut, "E": .ssangDigeut, "R": .ssangGiyeok, "T": .ssangSiot,
        "q": .bieup, "w": .jieut, "e": .digeut, "r": .giyeok, "t": .siot,

        "a": .mieum, "A": .mieum,
        "s": .nieun, "S": .nieun,
        "d": .ieung, "D": .ieung,
        "f": .rieul, "F": .rieul,
        "g": .hieut, "G": .hieut,

        "z": .kieuk, "Z": .kieuk,
        "x": .tieut, "X": .tieut,
        "c": .chieut, "C": .chieut,
        "v": .pieup, "V": .pieup,
    ]

    static let jungseong: [String: Jungseong] = [
        "O": .yae, "oo": .yae,
        "P": .ye, "pp": .ye,

        // 아주 빠르게 치거나 쌍자음 뒤에 Shift를 늦게 떼면 모음이 대문자로 들어온다.
        // 그래서 대문자에도 모음을 매핑한다.
        "y": .yo, "Y": .yo,
        "u": .yeo, "U": .yeo,
        "i": .ya, "I": .ya,
        "o": .ae,   // O는 ㅒ라서 대문자 매핑 안 함
        "p": .e,    // P는 ㅖ라서 대문자 매핑 안 함

        "h": .o, "H": .o,
        "j": .eo, "J": .eo,
        "k": .a, "K": .a,
        "l": .i, "L": .i,

        "b": .yu, "B": .yu,
        "n": .u, "N": .u,
        "m": .eu, "M": .eu,

        // 이중 모음 (ㅘ ㅙ ㅝ ㅞ ㅚ ㅟ ㅢ)
        "hk": .wa, "Hk": .wa, "HK": .wa,
        "ho": .wae, "Ho": .wae, "HO": .wae,
        "nj": .wo, "Nj": .wo, "NJ": .wo,
        "np": .we, "Np": .we, "NP": .we,
        "hl": .oe, "Hl": .oe, "HL": .oe,
        "nl": .wi, "Nl": .wi, "NL": .wi,
        "ml": .ui, "Ml": .ui, "ML": .ui,
    ]

    static let jongseong: [String: Jongseong] = [
        "r": .giyeok,   // R은 ㄲ이라서 대문자 매핑 안 함
        "R": .ssangGiyeok,
        "rt": .giyeokSiot, "Rt": .giyeokSiot, "RT": .giyeokSiot,
        "s": .nieun, "S": .nieun,
        "sw": .nieunJieut, "Sw": .nieunJieut, "SW": .nieunJieut,
        "sg": .nieunHieut, "Sg": .nieunHieut, "SG": .nieunHieut,
        "e": .digeut, "E": .digeut,
        "f": .rieul, "F": .rieul,
        "fr": .rieulGiyeok, "Fr": .rieulGiyeok, "FR": .rieulGiyeok,
        "fa": .rieulMieum, "Fa": .rieulMieum, "FA": .rieulMieum,
        "fq": .rieulBieup, "Fq": .rieulBieup, "FQ": .rieulBieup,
        "ft": .rieulSiot, "Ft": .rieulSiot, "FT": .rieulSiot,
        "fx": .rieulTieut, "Fx": .rieulTieut, "FX": .rieulTieut,
        "fv": .rieulPieup, "Fv": .rieulPieup, "FV": .rieulPieup,
        "fg": .rieulHieut, "Fg": .rieulHieut, "FG": .rieulHieut,
        "a": .mieum, "A": .mieum,
        "q": .bieup, "Q": .bieup,
        "qt": .bieupSiot, "Qt": .bieupSiot, "QT": .bieupSiot,
        "t": .siot,     // T는 ㅆ이라서 대문자 매핑 안 함
        "T": .ssangSiot,
        "d": .ieung, "D": .ieung,
        "w": .jieut, "W": .jieut,
        "c": .chieut, "C": .chieut,
        "z": .kieuk, "Z": .kieuk,
        "x": .tieut, "X": .tieut,
        "v": .pieup, "V": .pieup,
        "g": .hieut, "G": .hieut,
    ]

    static func isHangul(_ key: String) -> Bool {
        return choseong[key] != nil || jungseong[key] != nil || jongseong[key] != nil
    }

    // 지금 조합에 이 키를 초성으로 더할 수 있는가.
    static func acceptsChoseong(_ comp: inout Composition, _ key: String) -> Bool {
        // 초성과 중성이 이미 있으면 더 이상 초성이 아니다.
        if !comp.choseong.isEmpty && !comp.jungseong.isEmpty {
            return false
        }
        return choseong[comp.choseong + key] != nil
    }

    // 지금 조합에 이 키를 중성으로 더할 수 있는가.
    // 종성 뒤에 모음이 오면 종성의 마지막 자음을 떼어 다음 글자의 초성으로 넘긴다(도깨비불).
    // 그때는 comp를 고치고 조합을 끝낸다.
    static func acceptsJungseong(_ comp: inout Composition, _ key: String) -> Bool {
        if jungseong[key] == nil {
            return false
        }
        if let last = comp.jongseong.last, choseong[String(last)] != nil {
            comp.jongseong.removeLast()
            comp.done = true
            return false
        }
        return jungseong[comp.jungseong + key] != nil
    }

    // 지금 조합에 이 키를 종성으로 더할 수 있는가. 중성이 없으면 종성도 없다.
    static func acceptsJongseong(_ comp: inout Composition, _ key: String) -> Bool {
        if comp.jungseong.isEmpty {
            return false
        }
        return jongseong[comp.jongseong + key] != nil
    }
}
