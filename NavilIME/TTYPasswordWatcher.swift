//
//  TTYPasswordWatcher.swift
//  NavilIME
//
//  터미널의 암호 프롬프트를 감지해, 그동안 입력기가 조합을 멈추게 한다.
//
//  왜 필요한가: macOS는 암호 필드(잠금 화면, 키체인 등)에서 secure input을 켜주지만,
//  터미널의 sudo/ssh/git 프롬프트에서는 켜주지 않는다. 터미널 앱이 pty의 상태를
//  보지 않기 때문이다. 그래서 한글 상태로 비밀번호를 치면 한글이 들어간다.
//
//  판별법: 비밀번호를 읽는 프로그램은 tty를 "정규 모드(ICANON) + 에코 끔(ECHO off)"
//  으로 만든다. vim·top 같은 전체화면 TUI는 raw 모드(ICANON off)라 구분된다.
//  실측으로 확인했다:
//
//      cat      정규 + 에코 on    → 평범한 입력
//      getpass  정규 + 에코 OFF   → 암호 프롬프트   ← 이것만 잡는다
//      vi       raw  + 에코 OFF   → TUI (오탐 아님)
//      top      raw  + 에코 OFF   → TUI (오탐 아님)
//
//  덕분에 sudo뿐 아니라 ssh, git 자격증명, passwd, su, python getpass 등
//  "에코를 끄고 비밀번호를 읽는 모든 것"이 한 번에 커버된다.
//
//  [어느 tty를 보나] 지금 사용자가 입력하고 있는 곳만 본다. 예전에는 모든 tty를 봐서,
//  뒤쪽 탭에 떠 있는 암호 프롬프트나 에코를 끈 채 남은 tty 하나 때문에 모든 앱에서
//  한글이 막혔다. 지금은:
//    1. 맨 앞 앱 소유의 tty만 본다. 프로세스 부모를 따라가 그 앱에 닿는 tty다.
//       tmux 서버처럼 어느 앱에도 속하지 않는 tty도 같이 본다(맨 앞 터미널 안에서
//       돌고 있을 수 있으므로).
//    2. 그중 가장 최근에 키 입력을 받은 tty(접근 시각, `w`의 유휴 시간과 같은 값)와,
//       그보다 recentWindow 이내에 입력을 받은 tty만 본다. tmux는 바깥 tty와 안쪽 tty가
//       거의 동시에 입력을 받으므로 둘 다 잡힌다. 오래 손대지 않은 뒤쪽 탭은 빠진다.
//
//  감지하면 EnableSecureEventInput()을 켠다. 조합을 멈추는 것은 물론, 그동안
//  다른 앱의 이벤트 탭까지 차단되어 실제 키로거 방어가 된다.
//
//  [스레딩] 타이머도 조회도 전부 메인 큐에서 돈다. IMK 입력 경로가 메인 스레드이므로
//  락 없이 안전하다.
//
//  [비용] tty 소유 관계(프로세스 전체 조회)는 1초마다 다시 만든다(실측 ~1.3ms). 키 입력 경로는
//  100ms TTL 캐시로 확인하고, 프로세스가 붙어 있는 tty만 stat한 뒤 후보 1~2개만 연다.
//

import Cocoa
import Carbon

final class TTYPasswordWatcher {
    static let shared = TTYPasswordWatcher()

    // 프롬프트가 떠 있는 동안 secure input을 우리가 쥐고 있는지.
    // Enable/Disable은 프로세스별 참조 카운트라, 우리가 켠 만큼만 꺼야 한다.
    private(set) var holdingSecureInput = false

    private var timer: DispatchSourceTimer?

    // 키 입력 경로에서 매번 tty를 훑지 않도록 짧게 캐시한다.
    private var cachedActive = false
    private var cachedAt = DispatchTime.now()
    private static let cacheTTL: UInt64 = 100_000_000   // 100ms

    // 프롬프트가 뜨자마자(타이핑 전에) secure input을 켜기 위한 주기.
    // 조합 차단 자체는 키 입력 경로가 즉시 처리하므로, 이 타이머는 느려도 된다.
    private static let pollInterval: DispatchTimeInterval = .seconds(1)

    // tty 경로 → 그 tty를 쓰는 프로세스가 속한 앱의 pid. 어느 앱에도 속하지 않으면 nil(tmux 서버 등).
    // 목록에 없는 tty는 아직 모르는 것이라 보지 않는다(다음 갱신 때 들어온다).
    private var ttyOwners: [String: pid_t?] = [:]
    private var ownersBuiltAt = DispatchTime(uptimeNanoseconds: 0)
    private static let ownersTTL: UInt64 = 1_000_000_000  // 1s

    // 가장 최근 입력보다 이만큼 이내에 입력을 받은 tty까지 지금 쓰는 곳으로 본다.
    private static let recentWindow: TimeInterval = 2

    private init() {}

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: Self.pollInterval)
        t.setEventHandler { [weak self] in self?.refresh() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        setSecureInput(false)
    }

    /// 키 입력 경로에서 부르는 동기 확인. 캐시가 오래됐으면 즉시 다시 훑는다.
    /// (타이머 주기를 기다리면 프롬프트 직후 첫 글자를 놓칠 수 있다.)
    func isPasswordPromptActive() -> Bool {
        let elapsed = DispatchTime.now().uptimeNanoseconds &- cachedAt.uptimeNanoseconds
        if elapsed < Self.cacheTTL {
            return cachedActive
        }
        return refresh()
    }

    @discardableResult
    private func refresh() -> Bool {
        let active = frontTTYAwaitingPassword()
        cachedActive = active
        cachedAt = DispatchTime.now()
        setSecureInput(active)
        return active
    }

    private func setSecureInput(_ on: Bool) {
        if on != holdingSecureInput {
            Log.debug("TTY secure input -> \(on)")
        }
        if on && !holdingSecureInput {
            if EnableSecureEventInput() == noErr {
                holdingSecureInput = true
            }
        } else if !on && holdingSecureInput {
            DisableSecureEventInput()
            holdingSecureInput = false
        }
    }

    /// 지금 입력 중인 tty(맨 앞 앱 소유 + 최근 입력)가 "정규 모드 + 에코 꺼짐"인가.
    private func frontTTYAwaitingPassword() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        rebuildOwnersIfStale()

        let uid = getuid()
        var candidates: [(path: String, lastInput: TimeInterval)] = []
        for (path, owner) in ttyOwners where owner == nil || owner == front {
            var info = stat()
            guard stat(path, &info) == 0, info.st_uid == uid else { continue }
            let t = info.st_atimespec
            candidates.append((path, TimeInterval(t.tv_sec) + TimeInterval(t.tv_nsec) / 1e9))
        }
        guard let newest = candidates.map(\.lastInput).max() else { return false }

        for c in candidates where newest - c.lastInput <= Self.recentWindow {
            if Self.awaitingPassword(c.path) {
                return true
            }
        }
        return false
    }

    private static func awaitingPassword(_ path: String) -> Bool {
        // O_NOCTTY: 이 tty가 우리 controlling terminal이 되지 않게 한다.
        // O_NONBLOCK: 열기만 하고 절대 블록되지 않게 한다.
        let fd = open(path, O_RDONLY | O_NONBLOCK | O_NOCTTY)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var term = termios()
        guard tcgetattr(fd, &term) == 0 else { return false }
        let canonical = (term.c_lflag & tcflag_t(ICANON)) != 0
        let echoing = (term.c_lflag & tcflag_t(ECHO)) != 0
        return canonical && !echoing
    }

    // 프로세스 전체를 한 번 조회해 tty마다 소유 앱을 정한다.
    private func rebuildOwnersIfStale() {
        let now = DispatchTime.now()
        guard now.uptimeNanoseconds &- ownersBuiltAt.uptimeNanoseconds >= Self.ownersTTL else { return }
        ownersBuiltAt = now

        let appPIDs = Set(NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map(\.processIdentifier))

        var parent: [pid_t: pid_t] = [:]
        var processOnTTY: [dev_t: pid_t] = [:]
        for p in Self.allProcesses() {
            parent[p.kp_proc.p_pid] = p.kp_eproc.e_ppid
            let tty = p.kp_eproc.e_tdev
            if tty != 0 && tty != -1 && processOnTTY[tty] == nil {
                processOnTTY[tty] = p.kp_proc.p_pid
            }
        }

        var owners: [String: pid_t?] = [:]
        for (tty, pid) in processOnTTY {
            var owner: pid_t? = nil
            var cur = pid
            // 부모를 따라 올라가다 처음 만나는 앱이 소유자다. 순환 방지로 깊이를 제한한다.
            for _ in 0..<32 {
                guard let up = parent[cur], up > 1 else { break }
                if appPIDs.contains(up) {
                    owner = up
                    break
                }
                cur = up
            }
            guard let name = devname(tty, S_IFCHR) else { continue }
            owners["/dev/" + String(cString: name)] = .some(owner)
        }
        ttyOwners = owners
    }

    private static func allProcesses() -> [kinfo_proc] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }
        // 조회 사이에 프로세스가 늘 수 있어 여유를 둔다.
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 32)
        size = procs.count * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }
        return Array(procs.prefix(size / MemoryLayout<kinfo_proc>.stride))
    }
}
