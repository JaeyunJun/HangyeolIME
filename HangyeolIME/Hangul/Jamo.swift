//
//  Jamo.swift
//  HangyeolIME
//
//  현대 한글 자모. rawValue는 첫가끝(조합형) 코드다.
//
//  완성된 글자(초성+중성)는 첫가끝 인덱스로 음절 코드를 계산하고, 미완성 글자(초성만 등)는
//  호환 자모(0x3131~)로 내보낸다. 첫가끝 자모를 그대로 내보내는 것보다 macOS가 호환 자모를
//  더 안정적으로 처리한다.
//

import Foundation

enum Choseong: unichar {
    case giyeok = 0x1100, ssangGiyeok, nieun, digeut, ssangDigeut, rieul, mieum, bieup,
         ssangBieup, siot, ssangSiot, ieung, jieut, ssangJieut, chieut, kieuk, tieut,
         pieup, hieut

    var index: Int { Int(rawValue - Choseong.giyeok.rawValue) }

    // ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ
    private static let compatibilityTable: [unichar] = [
        0x3131, 0x3132, 0x3134, 0x3137, 0x3138, 0x3139, 0x3141, 0x3142, 0x3143, 0x3145,
        0x3146, 0x3147, 0x3148, 0x3149, 0x314A, 0x314B, 0x314C, 0x314D, 0x314E,
    ]
    var compatibility: unichar { Self.compatibilityTable[index] }
}

enum Jungseong: unichar {
    case a = 0x1161, ae, ya, yae, eo, e, yeo, ye, o, wa, wae, oe, yo, u, wo, we, wi, yu,
         eu, ui, i

    var index: Int { Int(rawValue - Jungseong.a.rawValue) }

    // 호환 모음(ㅏ 0x314F ~ ㅣ 0x3163)은 첫가끝과 같은 순서로 이어져 있다.
    var compatibility: unichar { 0x314F + unichar(index) }
}

enum Jongseong: unichar {
    case giyeok = 0x11A8, ssangGiyeok, giyeokSiot, nieun, nieunJieut, nieunHieut, digeut,
         rieul, rieulGiyeok, rieulMieum, rieulBieup, rieulSiot, rieulTieut, rieulPieup,
         rieulHieut, mieum, bieup, bieupSiot, siot, ssangSiot, ieung, jieut, chieut, kieuk,
         tieut, pieup, hieut

    // 종성 인덱스는 1부터다. 0은 "종성 없음".
    var index: Int { Int(rawValue - Jongseong.giyeok.rawValue) + 1 }

    // ㄱ ㄲ ㄳ ㄴ ㄵ ㄶ ㄷ ㄹ ㄺ ㄻ ㄼ ㄽ ㄾ ㄿ ㅀ ㅁ ㅂ ㅄ ㅅ ㅆ ㅇ ㅈ ㅊ ㅋ ㅌ ㅍ ㅎ
    private static let compatibilityTable: [unichar] = [
        0x3131, 0x3132, 0x3133, 0x3134, 0x3135, 0x3136, 0x3137, 0x3139, 0x313A, 0x313B,
        0x313C, 0x313D, 0x313E, 0x313F, 0x3140, 0x3141, 0x3142, 0x3144, 0x3145, 0x3146,
        0x3147, 0x3148, 0x314A, 0x314B, 0x314C, 0x314D, 0x314E,
    ]
    var compatibility: unichar { Self.compatibilityTable[index - 1] }
}
