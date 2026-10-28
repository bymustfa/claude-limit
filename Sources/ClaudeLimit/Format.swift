import Foundation
import ClaudeLimitCore

enum Fmt {
    private static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f
    }()

    private static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEE"
        return f
    }()

    private static let resetFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "EEE HH:mm"
        return f
    }()

    static func pct(_ v: Double) -> String { "%" + (number.string(from: v as NSNumber) ?? "\(v)") }

    /// Slices start at local midnight, or within 12h of it for the first one, so 12h in names the day.
    static func dayName(_ d: DayUsage) -> String {
        weekday.string(from: d.start.addingTimeInterval(43_200))
    }

    private static let longDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM EEEE"
        return f
    }()

    static func dayLong(_ d: DayUsage) -> String { longDay.string(from: d.start.addingTimeInterval(43_200)) }

    static func hourText(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    static func resetText(_ date: Date) -> String { resetFormat.string(from: date) }

    static func countdown(to date: Date, from now: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        let d = s / 86_400, h = (s % 86_400) / 3600, m = (s % 3600) / 60
        if d > 0 { return "\(d)g \(h)s" }
        if h > 0 { return "\(h)s \(m)dk" }
        return "\(m)dk"
    }

    /// Signed carry-over, e.g. "+%1,8" / "−%2,0".
    static func carry(_ v: Double) -> String { (v < 0 ? "−" : "+") + pct(abs(v)) }

    /// Menubar title, e.g. "3 / 16".
    static func menubar(_ w: WeekSummary) -> String {
        guard w.hasData else { return "–" }
        let used = Int(w.todayUsed.rounded())
        let share = Int(w.today.allowance.rounded())
        return "\(used) / \(share)"
    }
}
