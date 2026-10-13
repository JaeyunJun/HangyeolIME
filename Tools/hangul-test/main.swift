//
//  hangul-test/main.swift
//  HangyeolIME 한글 엔진 회귀 테스트
//
//  고정 문장과 시드 고정 무작위 입력(20만 타)을 엔진에 넣고, 매 단계의 확정·조합 결과를 기록한다.
//  기록의 해시가 기준값과 같으면 엔진 동작이 바뀌지 않은 것이다. (Tools/hangul-test.sh)
//

import Foundation

let hangul = Hangul()
var out = ""

func record(_ tag: String, _ result: String) {
    out += "\(tag)\t\(result)\tC=\(hangul.takeCommit())\tP=\(hangul.takePreedit())\n"
}

func type(_ key: String) {
    let eaten = hangul.process(key)
    if !eaten {
        hangul.flush()
    }
    record("in \(key)", eaten ? "1" : "0")
}

let sentences = [
    "difq dms tk gkdl dis rhRkf dms", "qkfqkfl", "dkssudgktpdy", "rmfjsgksmsrjtdl",
    "QQQ WWW ttt TTT hk ho nj np hl nl ml", "dhkd ehoakwp", "akfr ekfr", "gksrmf",
]
for sentence in sentences {
    for ch in sentence {
        type(String(ch))
    }
    hangul.flush()
    record("flush", "-")
}

let keys = Array("qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1.,/ ")
var seed: UInt64 = 0x9E3779B97F4A7C15
func random(_ n: Int) -> Int {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return Int((seed >> 33) % UInt64(n))
}
for _ in 0..<200_000 {
    switch random(20) {
    case 0:
        record("bs", hangul.backspace() ? "1" : "0")
    case 1:
        hangul.flush()
        record("flush", "-")
    default:
        type(String(keys[random(keys.count)]))
    }
}

FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: out.data(using: .utf8))
