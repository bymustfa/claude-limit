import Foundation
import Combine
import AppKit
import ClaudeLimitCore

/// Keeps the sample history in SQLite, polls `claude -p "/usage"` and republishes the week summary
/// (plus a timer so "today" rolls over and the reset countdown stays fresh).
@MainActor
final class SnapshotStore: ObservableObject {
    @Published private(set) var summary: WeekSummary
    @Published private(set) var now = Date()

    private let db: SampleDatabase?
    private var snapshots: [Snapshot] = []
    private var timer: Timer?
    private var pollTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    @Published private(set) var isPolling = false
    @Published private(set) var lastPoll: Date?
    @Published private(set) var pollError: PollError?

    /// Where the pre-SQLite versions kept their `snapshots*.jsonl` files (env override, iCloud Drive, else ~/.claude-limit).
    nonisolated static var legacyDirectory: URL {
        let fm = FileManager.default
        if let path = ProcessInfo.processInfo.environment["CLAUDE_LIMIT_DIR"] {
            return URL(fileURLWithPath: path)
        }
        let home = fm.homeDirectoryForCurrentUser
        let icloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if fm.fileExists(atPath: icloud.path) {
            return icloud.appendingPathComponent("claude-limit")
        }
        return home.appendingPathComponent(".claude-limit")
    }

    init(databaseURL: URL = SampleDatabase.defaultURL, legacyDirectory: URL = SnapshotStore.legacyDirectory) {
        self.db = SampleDatabase(url: databaseURL)
        self.summary = WeekModel.summary(snapshots: [], now: Date())
        db?.once("import-jsonl") { importLegacy(from: legacyDirectory) }
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        // The limit is account-wide, so ask Claude itself every 10 minutes (and on launch / wake).
        pollTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        Task { await poll() }
    }

    /// Fetches fresh numbers via `claude -p "/usage"` and stores them if they changed.
    func poll() async {
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }
        switch await UsagePoller.fetch() {
        case .success(let snap):
            pollError = nil
            lastPoll = Date()
            append(snap)
        case .failure(let err):
            pollError = err
        }
        reload()
    }

    private func append(_ snap: Snapshot) {
        let last = snapshots.last(where: { $0.sevenDay != nil })
        if let last, last.sevenDay == snap.sevenDay, last.fiveHour == snap.fiveHour { return }
        db?.insert(snap, source: "poll")
    }

    /// One-time copy of the old JSONL files (one per machine; the union sorted by time is the truth).
    private func importLegacy(from directory: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let text = files
            .filter { $0.lastPathComponent.hasPrefix("snapshots") && $0.pathExtension == "jsonl" }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
        for snap in SnapshotParser.parse(text) { db?.insert(snap, source: "jsonl") }
    }

    func reload() {
        now = Date()
        // Current and previous week are enough for the model; older rows stay in the database for history.
        snapshots = db?.load(since: now.timeIntervalSince1970 - 15 * 86_400) ?? []
        summary = WeekModel.summary(snapshots: snapshots, now: now)
    }
}
