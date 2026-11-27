import Foundation
import Combine
import AppKit
import ClaudeLimitCore

/// Keeps the sample history in SQLite, polls `claude -p "/usage"` and republishes the week summary
/// (plus a timer so "today" rolls over and the reset countdown stays fresh).
@MainActor
final class SnapshotStore: ObservableObject {
    /// The current week; drives the menu bar title.
    @Published private(set) var summary: WeekSummary
    /// The week shown in the panel: the current one, or a finished one picked with `showWeek`.
    @Published private(set) var viewed: WeekSummary
    /// 0 is the current week, -1 the last recorded finished week before it, and so on.
    @Published private(set) var weekOffset = 0
    @Published private(set) var now = Date()
    private var pastWeekEnds: [TimeInterval] = []

    var canGoBack: Bool { -weekOffset < pastWeekEnds.count }
    var canGoForward: Bool { weekOffset < 0 }
    var hasHistory: Bool { !pastWeekEnds.isEmpty }

    private let db: SampleDatabase?
    private let fetcher: UsageFetching
    private var snapshots: [Snapshot] = []
    private var timer: Timer?
    private var pollTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    /// Current and previous week are enough for the model; older rows stay in the database.
    private static let historyWindow: TimeInterval = 15 * 86_400

    @Published private(set) var isPolling = false
    @Published private(set) var lastPoll: Date?
    @Published private(set) var pollError: PollError?

    init(databaseURL: URL = SampleDatabase.defaultURL, fetcher: UsageFetching = ClaudeCLIUsageFetcher()) {
        self.db = SampleDatabase(url: databaseURL)
        self.fetcher = fetcher
        let empty = WeekModel.summary(snapshots: [], now: Date())
        self.summary = empty
        self.viewed = empty
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
        switch await fetcher.fetch() {
        case .success(let snapshot):
            pollError = nil
            lastPoll = Date()
            append(snapshot)
        case .failure(let error):
            pollError = error
        }
        reload()
    }

    private func append(_ snapshot: Snapshot) {
        let last = snapshots.last(where: { $0.sevenDay != nil })
        if let last, last.sevenDay == snapshot.sevenDay, last.fiveHour == snapshot.fiveHour { return }
        db?.insert(snapshot, source: "poll")
    }

    /// Moves the panel to the current week (offset 0) or back to an earlier finished one (negative).
    func showWeek(offset: Int) {
        weekOffset = offset
        reload()
    }

    func reload() {
        now = Date()
        snapshots = db?.load(since: now.timeIntervalSince1970 - Self.historyWindow) ?? []
        summary = WeekModel.summary(snapshots: snapshots, now: now)
        pastWeekEnds = WeekModel.pastWeekEnds(resets: db?.weekResets() ?? [], currentStart: summary.weekStart)
        weekOffset = min(0, max(weekOffset, -pastWeekEnds.count))
        if weekOffset == 0 {
            viewed = summary
        } else {
            let end = pastWeekEnds[pastWeekEnds.count + weekOffset]
            let samples = db?.load(since: end - 7 * 86_400, until: end) ?? []
            viewed = WeekModel.pastWeek(snapshots: samples, weekEnd: end)
        }
    }
}
