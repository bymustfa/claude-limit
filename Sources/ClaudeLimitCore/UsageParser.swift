import Foundation

/// Parses the human-readable output of `claude -p "/usage"` into a `Snapshot`.
///
///     Current session: 1% used · resets Oct 26 at 2:40pm (Europe/Istanbul)
///     Current week (all models): 6% used · resets Oct 31 at 11pm (Europe/Istanbul)
///
/// Reset times carry no year and are sometimes a minute off (10:59pm vs 11pm), so they are
/// rounded to the nearest 5 minutes, which keeps consecutive polls identical.
public enum UsageParser {
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    public static func parse(_ text: String, now: Date) -> Snapshot? {
        guard let week = window(prefix: "Current week (all models)", in: text, now: now) else { return nil }
        let session = window(prefix: "Current session", in: text, now: now)
        return Snapshot(t: now.timeIntervalSince1970, fiveHour: session, sevenDay: week)
    }

    private static func window(prefix: String, in text: String, now: Date) -> LimitWindow? {
        let pattern = #"(\d+(?:\.\d+)?)%\s*used.*?resets\s+([A-Za-z]{3})[a-z]*\s+(\d{1,2})\s+at\s+(\d{1,2})(?::(\d{2}))?\s*([ap]m)\s*\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let s = String(line).trimmingCharacters(in: .whitespaces)
            guard s.hasPrefix(prefix) else { continue }
            let range = NSRange(s.startIndex..., in: s)
            guard let m = regex.firstMatch(in: s, range: range) else { continue }
            func group(_ i: Int) -> String? {
                Range(m.range(at: i), in: s).map { String(s[$0]) }
            }
            guard let pct = group(1).flatMap(Double.init),
                  let mon = group(2).flatMap({ months.firstIndex(of: $0.lowercased()) }),
                  let day = group(3).flatMap(Int.init),
                  var hour = group(4).flatMap(Int.init),
                  let ampm = group(6)?.lowercased(),
                  let tz = group(7).flatMap({ TimeZone(identifier: $0) }) else { continue }
            let minute = group(5).flatMap(Int.init) ?? 0
            hour = hour % 12 + (ampm == "pm" ? 12 : 0)
            guard let epoch = resolve(month: mon + 1, day: day, hour: hour, minute: minute, tz: tz, now: now) else { continue }
            return LimitWindow(pct: pct, resetsAt: (epoch / 300).rounded() * 300)
        }
        return nil
    }

    /// Picks the year that puts the date closest to `now` (resets are always upcoming).
    private static func resolve(month: Int, day: Int, hour: Int, minute: Int, tz: TimeZone, now: Date) -> TimeInterval? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let year = cal.component(.year, from: now)
        let candidates = [year - 1, year, year + 1].compactMap { y -> TimeInterval? in
            cal.date(from: DateComponents(year: y, month: month, day: day, hour: hour, minute: minute))?.timeIntervalSince1970
        }
        return candidates.min { abs($0 - now.timeIntervalSince1970) < abs($1 - now.timeIntervalSince1970) }
    }
}
