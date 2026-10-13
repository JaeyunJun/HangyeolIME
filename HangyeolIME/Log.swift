//
//  Log.swift
//  HangyeolIME
//

import Foundation
import os.log

enum Log {
    private static let logger = OSLog(subsystem: "com.jaeyunjun.HangyeolIME", category: "ime")

    // 입력기는 사용자가 친 글자를 다루므로, 입력 내용이 시스템 로그에 평문으로
    // 남지 않도록 Release 빌드에서는 남기지 않는다. (디버깅은 Debug 빌드에서)
    static func debug(_ message: @autoclosure () -> String) {
#if DEBUG
        os_log("%{public}@", log: logger, type: .debug, message())
#endif
    }
}
