import SwiftUI
import ClaudeLimitCore

/// Usage over a freely chosen date range: totals plus one bar per day.
struct HistoryView: View {
    @ObservedObject var store: SnapshotStore

    @State private var from = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var to = Date()

    private static let maxBarDays = 92

    var body: some View {
        let summary = store.rangeUsage(from: from, to: to)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                DatePicker("From", selection: $from, in: ...to, displayedComponents: .date)
                DatePicker("To", selection: $to, in: from...Date(), displayedComponents: .date)
            }
            .datePickerStyle(.field)
            .labelsHidden()
            HStack(spacing: 8) {
                preset("Last 7 days", days: 7)
                preset("Last 30 days", days: 30)
                Spacer()
            }
            totals(summary)
            DayTrendView(days: Array(summary.days.suffix(Self.maxBarDays)))
        }
    }

    private func preset(_ title: LocalizedStringKey, days: Int) -> some View {
        Button(title) {
            let today = Date()
            to = today
            from = Calendar.current.date(byAdding: .day, value: 1 - days, to: today) ?? today
        }
        .buttonStyle(.bordered).controlSize(.small)
    }

    private func totals(_ summary: RangeSummary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            stat("Total", "≈\(Formatters.percent(summary.total))")
            stat("Per day", "≈\(Formatters.percent(summary.average))")
            if let busiest = summary.busiest {
                stat("Busiest day", "\(Formatters.shortDate(busiest.start)) · ≈\(Formatters.wholePercent(busiest.used))")
            }
            Spacer(minLength: 0)
        }
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
    }
}

/// One thin bar per day, scaled to the busiest day; hover shows the day and its usage.
private struct DayTrendView: View {
    let days: [RangeDay]
    @State private var hovered: Int?

    private static let height: CGFloat = 90

    var body: some View {
        let peak = max(days.map(\.used).max() ?? 0, WeekSummary.dailyShare)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: days.count > 31 ? 1 : 3) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Capsule()
                        .fill(Theme.liquidColor(ratio: day.used / WeekSummary.dailyShare).opacity(hovered == index ? 1 : 0.8))
                        .frame(height: day.used > 0 ? max(3, Self.height * day.used / peak) : 1)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.height, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onHover { inside in
                            if inside { hovered = index } else if hovered == index { hovered = nil }
                        }
                }
            }
            Text(verbatim: caption)
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The hovered day, or the first and last day of the range.
    private var caption: String {
        if let index = hovered, days.indices.contains(index) {
            return "\(Formatters.shortDate(days[index].start)) · ≈\(Formatters.percent(days[index].used))"
        }
        guard let first = days.first, let last = days.last else { return "" }
        return "\(Formatters.shortDate(first.start)) – \(Formatters.shortDate(last.start))"
    }
}
