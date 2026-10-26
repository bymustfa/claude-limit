import Foundation

public struct DayUsage: Equatable, Sendable {
    public let index: Int
    public let start: Date
    public let end: Date
    /// Percentage points of the weekly limit used in this slice; nil for future days.
    public let used: Double?
    public let isToday: Bool
    /// What this day may use: the weekly pool left at the start of the day split evenly over the
    /// remaining days. For future days it is the projection from today's usage.
    public let allowance: Double
    /// Weekly total at the end of this day (or now, for today); nil for future days.
    public var weekTotal: Double?

    public var isFuture: Bool { used == nil }
    /// Carried over from earlier days (positive) or borrowed by them (negative), vs. the fixed share.
    public var carry: Double { allowance - WeekSummary.dailyShare }
    /// The day's allowance is spent (also true once the whole weekly pool is gone).
    public var isFull: Bool {
        guard let used else { return false }
        return allowance <= 0.05 || used >= allowance
    }
}

public struct WeekSummary: Equatable, Sendable {
    public static let dailyShare = 100.0 / 7.0

    public let weekStart: Date
    public let weekEnd: Date
    public let weeklyPct: Double
    public let days: [DayUsage]
    public let fiveHour: LimitWindow?
    public let hasData: Bool

    public var today: DayUsage { days.first(where: \.isToday) ?? days[0] }
    public var todayUsed: Double { today.used ?? 0 }
    public func isOver(_ day: DayUsage) -> Bool { (day.used ?? 0) > day.allowance }
}

public enum WeekModel {
    static let day: TimeInterval = 86_400
    static let week: TimeInterval = 7 * day

    /// Builds the 7 equal 24h slices of the current weekly window.
    ///
    /// The week runs from `resets_at - 7d` to `resets_at`. Usage before the first
    /// snapshot of a week is counted as 0, so the day of the first observation
    /// takes any usage that happened before tracking started.
    public static func summary(snapshots: [Snapshot], now: Date) -> WeekSummary {
        let nowT = now.timeIntervalSince1970
        let latest = snapshots.last(where: { $0.sevenDay != nil })

        guard let latest, let seven = latest.sevenDay else {
            // No data at all: show an empty week ending a week from now.
            return empty(weekEnd: nowT + week, nowT: nowT, hasData: false)
        }

        var weekEnd = seven.resetsAt
        var rolledOver = false
        // The known week is over and no new data arrived: the limit has reset.
        while weekEnd <= nowT {
            weekEnd += week
            rolledOver = true
        }
        let weekStart = weekEnd - week

        let inWeek = rolledOver ? [] : snapshots.filter { snap in
            guard let w = snap.sevenDay else { return false }
            return snap.t >= weekStart && snap.t < weekEnd && abs(w.resetsAt - weekEnd) < 3600
        }

        func pct(at time: TimeInterval) -> Double {
            inWeek.last(where: { $0.t <= time })?.sevenDay?.pct ?? 0
        }

        let todayIndex = min(max(Int((nowT - weekStart) / day), 0), 6)
        // Pool split: day i may use (100 - used before day i) / (7 - i); future days share what is left after today.
        let nowPct = pct(at: nowT)
        let projected = max(0, 100 - nowPct) / Double(6 - todayIndex == 0 ? 1 : 6 - todayIndex)
        let days = (0..<7).map { i -> DayUsage in
            let s = weekStart + Double(i) * day
            let e = s + day
            let used: Double? = i > todayIndex ? nil : max(0, pct(at: min(e, nowT)) - pct(at: s))
            let allowance = i > todayIndex ? projected : max(0, 100 - pct(at: s)) / Double(7 - i)
            return DayUsage(index: i, start: Date(timeIntervalSince1970: s), end: Date(timeIntervalSince1970: e),
                            used: used, isToday: i == todayIndex, allowance: allowance,
                            weekTotal: i > todayIndex ? nil : pct(at: min(e, nowT)))
        }

        return WeekSummary(
            weekStart: Date(timeIntervalSince1970: weekStart),
            weekEnd: Date(timeIntervalSince1970: weekEnd),
            weeklyPct: nowPct,
            days: days,
            fiveHour: rolledOver ? nil : latest.fiveHour.flatMap { $0.resetsAt > nowT ? $0 : nil },
            hasData: true
        )
    }

    private static func empty(weekEnd: TimeInterval, nowT: TimeInterval, hasData: Bool) -> WeekSummary {
        let weekStart = weekEnd - week
        let days = (0..<7).map { i -> DayUsage in
            let s = weekStart + Double(i) * day
            return DayUsage(index: i, start: Date(timeIntervalSince1970: s), end: Date(timeIntervalSince1970: s + day),
                            used: i == 6 ? 0 : nil, isToday: i == 6, allowance: WeekSummary.dailyShare)
        }
        return WeekSummary(weekStart: Date(timeIntervalSince1970: weekStart), weekEnd: Date(timeIntervalSince1970: weekEnd),
                           weeklyPct: 0, days: days, fiveHour: nil, hasData: hasData)
    }
}
