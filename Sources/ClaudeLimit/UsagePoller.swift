import Foundation
import ClaudeLimitCore

enum PollError: Error, Equatable {
    case claudeNotFound
    case unparsable
    case timeout
    case launchFailed

    var message: String {
        switch self {
        case .claudeNotFound: return String(localized: "claude not found")
        case .unparsable: return String(localized: "Could not read the output (are you signed in?)")
        case .timeout: return String(localized: "claude timed out")
        case .launchFailed: return String(localized: "claude could not be started")
        }
    }
}

/// Source of fresh usage numbers; lets the store be tested without spawning `claude`.
protocol UsageFetching: Sendable {
    func fetch() async -> Result<Snapshot, PollError>
}

/// Runs `claude -p "/usage"` and parses the account-wide limits from its output.
final class ClaudeCLIUsageFetcher: UsageFetching, @unchecked Sendable {
    private static let fetchTimeout: TimeInterval = 60
    private static let lookupTimeout: TimeInterval = 10

    private let lock = NSLock()
    private var cachedPath: String?

    func fetch() async -> Result<Snapshot, PollError> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: self.run())
            }
        }
    }

    /// Resolves the `claude` executable once; a failed lookup is retried on the next poll.
    private func claudePath() -> String? {
        lock.lock(); defer { lock.unlock() }
        if let cachedPath, FileManager.default.isExecutableFile(atPath: cachedPath) { return cachedPath }
        cachedPath = Self.resolveClaudePath()
        return cachedPath
    }

    private static func resolveClaudePath() -> String? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser.path
        let candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude",
                          "\(home)/.local/bin/claude", "\(home)/.claude/local/claude"]
        if let hit = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) { return hit }
        // GUI apps have a minimal PATH; ask a login shell.
        let output = try? runProcess("/bin/zsh", ["-lc", "command -v claude"], timeout: lookupTimeout).get()
        guard let path = output?.split(whereSeparator: \.isNewline).last.map(String.init),
              fileManager.isExecutableFile(atPath: path) else { return nil }
        return path
    }

    private func run() -> Result<Snapshot, PollError> {
        guard let claude = claudePath() else { return .failure(.claudeNotFound) }
        let output: String
        switch Self.runProcess(claude, ["-p", "/usage"], timeout: Self.fetchTimeout) {
        case .success(let text): output = text
        case .failure(let error): return .failure(error)
        }
        guard let snapshot = UsageParser.parse(output, now: Date()) else { return .failure(.unparsable) }
        return .success(snapshot)
    }

    /// Collects the child's stdout from a background thread; the lock makes the hand-over safe.
    private final class OutputBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func set(_ newData: Data) { lock.lock(); data = newData; lock.unlock() }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }

    /// Returns stdout, or why it could not be collected.
    private static func runProcess(_ executable: String, _ arguments: [String],
                                   timeout: TimeInterval) -> Result<String, PollError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return .failure(.launchFailed) }
        // Drain stdout concurrently so a full pipe can't block the child.
        let output = OutputBox()
        let readFinished = DispatchSemaphore(value: 0)
        DispatchQueue(label: "usage.read").async {
            output.set(pipe.fileHandleForReading.readDataToEndOfFile())
            readFinished.signal()
        }
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return .failure(.timeout)
        }
        readFinished.wait()
        return .success(String(decoding: output.get(), as: UTF8.self))
    }
}
