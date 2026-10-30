import SwiftUI
import ClaudeLimitCore

/// Today's usage against today's share, with the carry-over and a status pill.
struct HeaderView: View {
    let summary: WeekSummary

    /// Share of the allowance from which the status turns to "near".
    private static let nearThreshold = 0.7

    var body: some View {
        let today = summary.today
        let share = today.allowance
        let used = summary.todayUsed
        VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "≈\(Formatters.percent(used))").font(.system(size: 30, weight: .bold)).monospacedDigit()
                Text(verbatim: "/ \(Formatters.percent(share))").font(.title3).foregroundStyle(.secondary).monospacedDigit()
                if summary.hasData, today.hasCarry {
                    Text("Carry \(Formatters.carry(today.carry))").font(.caption.weight(.medium)).monospacedDigit()
                        .foregroundStyle(today.carry > 0 ? Theme.carryUp : Theme.carryDown)
                }
                Spacer()
                if summary.hasData {
                    let (label, color) = status(used: used, share: share, isOver: summary.isOver(today))
                    Text(label).font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .glassCapsule(tint: color.opacity(0.35))
                        .foregroundStyle(color)
                }
            }
        }
    }

    private func status(used: Double, share: Double, isOver: Bool) -> (LocalizedStringKey, Color) {
        if isOver { return ("Over your share", Theme.over) }
        if used >= share * Self.nearThreshold { return ("Near your share", Theme.warning) }
        return ("On track", .green)
    }
}

#Preview {
    HeaderView(summary: WeekModel.summary(snapshots: [], now: Date()))
        .padding()
        .frame(width: 380)
}
