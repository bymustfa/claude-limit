import Foundation
import ClaudeLimitCore

/// Text formatting in the language the app resolved from its bundle (English or Turkish).
/// All formatters are created once; none are allocated per call.
enum Formatters {
    static let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

    private static func dateFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static func percentFormatter(fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .percent
        formatter.multiplier = 1 // values are already percentage points
        formatter.roundingMode = .halfUp
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    private static let percentOneDecimal = percentFormatter(fractionDigits: 1)
    private static let percentWhole = percentFormatter(fractionDigits: 0)
    private static let weekday = dateFormatter(template: "EEE")
    private static let longDay = dateFormatter(template: "dMMMMEEEE")
    private static let resetDay = dateFormatter(template: "EEEHHmm")

    /// Percentage points with up to one decimal, e.g. "1.8%" (en) / "%1,8" (tr).
    static func percent(_ value: Double) -> String {
        percentOneDecimal.string(from: value as NSNumber) ?? "\(value)%"
    }

    /// Rounded percentage points, e.g. "5%" (en) / "%5" (tr).
    static func wholePercent(_ value: Double) -> String {
        percentWhole.string(from: value as NSNumber) ?? "\(Int(value.rounded()))%"
    }

    /// Abbreviated weekday of the day a slice is named after, e.g. "Sat".
    static func dayName(_ day: DayUsage) -> String { weekday.string(from: day.labelDate) }

    /// Full date of the day a slice is named after, e.g. "25 October Sunday".
    static func dayLong(_ day: DayUsage) -> String { longDay.string(from: day.labelDate) }

    /// Weekday and time of a reset, e.g. "Sat 23:00".
    static func resetText(_ date: Date) -> String { resetDay.string(from: date) }

    /// Compact time remaining, at most two units, e.g. "2d 3h", "3h 5m", "12m" (en) / "2g 3sa", "12dk" (tr).
    static func countdown(to date: Date, from now: Date) -> String {
        let totalMinutes = max(0, Int(date.timeIntervalSince(now))) / 60
        let days = totalMinutes / 1440, hours = totalMinutes % 1440 / 60, minutes = totalMinutes % 60
        let dayText = String(localized: "\(days)d", comment: "Countdown days, abbreviated")
        let hourText = String(localized: "\(hours)h", comment: "Countdown hours, abbreviated")
        let minuteText = String(localized: "\(minutes)m", comment: "Countdown minutes, abbreviated")
        if days > 0 { return "\(dayText) \(hourText)" }
        if hours > 0 { return "\(hourText) \(minuteText)" }
        return minuteText
    }

    /// Signed carry-over, e.g. "+1.8%" / "−2%".
    static func carry(_ value: Double) -> String { (value < 0 ? "−" : "+") + percent(abs(value)) }

    /// Menu bar title, e.g. "3 / 16".
    static func menuBar(_ summary: WeekSummary) -> String {
        guard summary.hasData else { return "–" }
        let used = Int(summary.todayUsed.rounded())
        let share = Int(summary.today.allowance.rounded())
        return "\(used) / \(share)"
    }
}
