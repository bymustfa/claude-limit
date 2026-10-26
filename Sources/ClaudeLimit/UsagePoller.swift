import Foundation
import ClaudeLimitCore

enum PollError: Error, Equatable {
    case claudeNotFound
    case failed(String)
    case unparsable
    case timeout

    var message: String {
        switch self {
        case .claudeNotFound: return "claude bulunamadı"
        case .failed(let s): return s.isEmpty ? "claude çalışmadı" : "claude: \(s)"
        case .unparsable: return "Çıktı okunamadı (giriş yapılmış mı?)"
        case .timeout: return "claude zaman aşımına uğradı"
        }
    }
}

/// Runs `claude -p "/usage"` and parses the account-wide limits from its output.
enum UsagePoller {
    static func fetch() async -> Result<Snapshot, PollError> {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                cont.resume(returning: run())
            }
        }
    }

    private static func claudePath() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude",
                          "\(home)/.local/bin/claude", "\(home)/.claude/local/claude"]
        if let hit = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) { return hit }
        // GUI apps have a minimal PATH; ask a login shell.
        let out = shell("/bin/zsh", ["-lc", "command -v claude"], timeout: 10)
        guard let path = out?.split(whereSeparator: \.isNewline).last.map(String.init),
              fm.isExecutableFile(atPath: path) else { return nil }
        return path
    }

    private static func run() -> Result<Snapshot, PollError> {
        guard let claude = claudePath() else { return .failure(.claudeNotFound) }
        guard let out = shell(claude, ["-p", "/usage"], timeout: 60) else { return .failure(.timeout) }
        guard let snap = UsageParser.parse(out, now: Date()) else { return .failure(.unparsable) }
        return .success(snap)
    }

    /// Returns stdout, or nil on timeout / launch failure.
    private static func shell(_ exe: String, _ args: [String], timeout: TimeInterval) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }
        do { try p.run() } catch { return nil }
        // Drain stdout concurrently so a full pipe can't block the child.
        var data = Data()
        let reader = DispatchQueue(label: "usage.read")
        let readDone = DispatchSemaphore(value: 0)
        reader.async {
            data = pipe.fileHandleForReading.readDataToEndOfFile()
            readDone.signal()
        }
        if done.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            return nil
        }
        readDone.wait()
        return String(data: data, encoding: .utf8)
    }
}
