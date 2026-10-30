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
    /// Whether the carry is large enough to be worth showing.
    public var hasCarry: Bool { abs(carry) >= WeekSummary.negligible }
    /// The day's allowance is spent (also true once the whole weekly pool is gone).
    public var isFull: Bool {
        guard let used else { return false }
        return allowance <= WeekSummary.negligible || used >= allowance
    }
    /// Used share of the allowance; 1 when there is no allowance left.
    public var fillRatio: Double {
        allowance > WeekSummary.negligible ? (used ?? 0) / allowance : 1
    }
    /// A date that falls inside the calendar day this slice is named after. Slices start at local
    /// midnight, or within 12h of it for the first one, so 12h in names the day.
    public var labelDate: Date { start.addingTimeInterval(WeekModel.labelOffset) }
}

public struct WeekSummary: Equatable, Sendable {
    public static let dailyShare = 100.0 / 7.0
    /// Percentage points below which an amount counts as zero.
    public static let negligible = 0.05

    public let weekStart: Date
    public let weekEnd: Date
    public let weeklyPercent: Double
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
    /// Snapshots whose reset time differs from the week's by more than this belong to another week.
    static let resetTolerance: TimeInterval = 3600
    static let labelOffset: TimeInterval = 12 * 3600

    /// Builds the 7 day slices of the current weekly window.
    ///
    /// The week runs from `resets_at - 7d` to `resets_at`; days change at local midnight
    /// (see `boundaries`). Usage before the first snapshot of a week is counted as 0, so
    /// the day of the first observation takes any usage that happened before tracking started.
    public static func summary(snapshots: [Snapshot], now: Date, calendar: Calendar = .current) -> WeekSummary {
        let nowTime = now.timeIntervalSince1970
        let latest = snapshots.last(where: { $0.sevenDay != nil })

        guard let latest, let latestWeek = latest.sevenDay else {
            // No data at all: show an empty week ending a week from now.
            return empty(weekEnd: nowTime + week)
        }

        var weekEnd = latestWeek.resetsAt
        var rolledOver = false
        // The known week is over and no new data arrived: the limit has reset.
        while weekEnd <= nowTime {
            weekEnd += week
            rolledOver = true
        }
        let weekStart = weekEnd - week

        let inWeek = rolledOver ? [] : snapshots.filter { snapshot in
            guard let window = snapshot.sevenDay else { return false }
            return snapshot.timestamp >= weekStart && snapshot.timestamp < weekEnd
                && abs(window.resetsAt - weekEnd) < resetTolerance
        }

        func percent(at time: TimeInterval) -> Double {
            inWeek.last(where: { $0.timestamp <= time })?.sevenDay?.percent ?? 0
        }

        let edges = boundaries(weekStart: weekStart, weekEnd: weekEnd, calendar: calendar)
        let todayIndex = min(edges.lastIndex(where: { $0 <= nowTime }) ?? 0, 6)
        // Pool split: day i may use (100 - used before day i) / (7 - i); future days share what is left after today.
        let nowPercent = percent(at: nowTime)
        let projected = max(0, 100 - nowPercent) / Double(max(1, 6 - todayIndex))
        let days = (0..<7).map { index -> DayUsage in
            let dayStart = edges[index]
            let dayEnd = edges[index + 1]
            let used: Double? = index > todayIndex ? nil : max(0, percent(at: min(dayEnd, nowTime)) - percent(at: dayStart))
            let allowance = index > todayIndex ? projected : max(0, 100 - percent(at: dayStart)) / Double(7 - index)
            return DayUsage(index: index, start: Date(timeIntervalSince1970: dayStart), end: Date(timeIntervalSince1970: dayEnd),
                            used: used, isToday: index == todayIndex, allowance: allowance,
                            weekTotal: index > todayIndex ? nil : percent(at: min(dayEnd, nowTime)))
        }

        return WeekSummary(
            weekStart: Date(timeIntervalSince1970: weekStart),
            weekEnd: Date(timeIntervalSince1970: weekEnd),
            weeklyPercent: nowPercent,
            days: days,
            fiveHour: rolledOver ? nil : latest.fiveHour.flatMap { $0.resetsAt > nowTime ? $0 : nil },
            hasData: true
        )
    }

    /// The 8 edges of the week's days: the reset, six local midnights, the next reset.
    /// The reset rarely falls on midnight, so day 0 starts at the reset and is named after the
    /// nearest midnight; the first and last days absorb the difference (e.g. a Sat 23:00 reset
    /// gives a 25h Sunday and a 23h Saturday).
    static func boundaries(weekStart: TimeInterval, weekEnd: TimeInterval, calendar: Calendar) -> [TimeInterval] {
        let start = Date(timeIntervalSince1970: weekStart)
        let midnight = calendar.startOfDay(for: start)
        let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight.addingTimeInterval(day)
        let first = start.timeIntervalSince(midnight) < nextMidnight.timeIntervalSince(start) ? midnight : nextMidnight
        let middle = (1...6).map { offset in
            (calendar.date(byAdding: .day, value: offset, to: first) ?? first.addingTimeInterval(Double(offset) * day)).timeIntervalSince1970
        }
        return [weekStart] + middle + [weekEnd]
    }

    private static func empty(weekEnd: TimeInterval) -> WeekSummary {
        let weekStart = weekEnd - week
        let days = (0..<7).map { index -> DayUsage in
            let dayStart = weekStart + Double(index) * day
            return DayUsage(index: index, start: Date(timeIntervalSince1970: dayStart), end: Date(timeIntervalSince1970: dayStart + day),
                            used: index == 6 ? 0 : nil, isToday: index == 6, allowance: WeekSummary.dailyShare)
        }
        return WeekSummary(weekStart: Date(timeIntervalSince1970: weekStart), weekEnd: Date(timeIntervalSince1970: weekEnd),
                           weeklyPercent: 0, days: days, fiveHour: nil, hasData: false)
    }
}
