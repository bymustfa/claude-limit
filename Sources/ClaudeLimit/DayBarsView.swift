import SwiftUI
import ClaudeLimitCore

private enum Layout {
    static let tubeHeight: CGFloat = 110
    static let numberRowHeight: CGFloat = 16
    static let tubeSpacing: CGFloat = 5
    static let gutterWidth: CGFloat = 58
    /// Dashed lines are drawn this wide and clipped to the tube capsule.
    static let lineLength: CGFloat = 60
    /// Chart scale: the tallest allowance (or daily share) takes 1/scaleHeadroom of the tube.
    static let scaleHeadroom = 1.6
    /// A sliver of liquid stays visible for any non-zero usage.
    static let minimumFill: CGFloat = 0.07
}

/// The seven day tubes with gutter labels for the shares and a hover card.
struct DayBarsView: View {
    let summary: WeekSummary

    @State private var appeared = false
    @State private var visible = false
    @State private var hovered: Int?
    @State private var mouse = CGPoint.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let share = WeekSummary.dailyShare
        let maxAllowance = summary.days.map(\.allowance).max() ?? share
        let scale = max(maxAllowance * Layout.scaleHeadroom, share * Layout.scaleHeadroom,
                        summary.days.compactMap(\.used).max() ?? 0)
        HStack(alignment: .top, spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !visible || reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                // Slow blink between 35% and 100% for tubes whose share is used up.
                let pulse = reduceMotion ? 1 : 0.675 + 0.325 * sin(time * 2.6)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(summary.days, id: \.index) { day in
                        DayTubeView(day: day, scale: scale, time: time, pulse: pulse, appeared: appeared,
                                    isHovered: hovered == day.index, isDimmed: hovered != nil && hovered != day.index) { inside in
                            if inside { hovered = day.index } else if hovered == day.index { hovered = nil }
                        }
                    }
                }
            }
            gutter(scale: scale)
        }
        .padding(.bottom, 4)
        .coordinateSpace(name: "bars")
        .onContinuousHover(coordinateSpace: .named("bars")) { phase in
            if case .active(let point) = phase { mouse = point }
        }
        .overlay(alignment: .topLeading) {
            // Own hover card: the system .help tooltip never shows under the 30 fps TimelineView.
            if let index = hovered, let day = summary.days.first(where: { $0.index == index }) {
                Text(tip(day))
                    .font(.caption).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.15)))
                    .shadow(radius: 8)
                    .fixedSize()
                    .offset(x: min(mouse.x + 14, 110), y: mouse.y + 18)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .onAppear {
            visible = true
            withAnimation(.spring(duration: 1.0, bounce: 0.25)) { appeared = true }
        }
        .onDisappear { visible = false; appeared = false }
    }

    /// Labels sitting on the lines: the carried share goes on the far side of the daily share.
    private func gutter(scale: Double) -> some View {
        let today = summary.today
        let top = Layout.numberRowHeight + Layout.tubeSpacing
        let yShare = top + Layout.tubeHeight * (1 - WeekSummary.dailyShare / scale)
        let yAllowance = top + Layout.tubeHeight * (1 - today.allowance / scale)
        let carried = today.hasCarry
        let up = today.carry > 0
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(width: Layout.gutterWidth, height: 1)
            GutterLabel(title: "daily share", value: Formatters.percent(WeekSummary.dailyShare), color: .primary.opacity(0.8))
                .offset(y: carried ? (up ? yShare + 1 : yShare - 25) : yShare - 12)
            if carried {
                GutterLabel(title: "today's share", value: Formatters.percent(today.allowance),
                            color: (up ? Theme.carryUp : Theme.carryDown).opacity(0.9))
                    .offset(y: up ? yAllowance - 25 : yAllowance + 1)
            }
        }
        .frame(width: Layout.gutterWidth)
    }

    private func tip(_ day: DayUsage) -> String {
        var lines = [Formatters.dayLong(day)]
        if let used = day.used {
            lines.append(String(localized: "Used: ≈\(Formatters.percent(used))"))
            lines.append(String(localized: "Share: \(Formatters.percent(day.allowance)) (fixed \(Formatters.percent(WeekSummary.dailyShare)))"))
            if day.hasCarry { lines.append(String(localized: "Carry: \(Formatters.carry(day.carry))")) }
            let left = Formatters.percent(day.allowance - used)
            if let total = day.weekTotal { lines.append(String(localized: "Weekly total: ≈\(Formatters.percent(total))")) }
            lines.append(day.isFull ? String(localized: "Share used up")
                : day.isToday ? String(localized: "Left today: \(left)") : String(localized: "Left: \(left)"))
        } else {
            lines.append(String(localized: "Estimated share: \(Formatters.percent(day.allowance))"))
            lines.append(String(localized: "Share you get if you use nothing more after today"))
        }
        return lines.joined(separator: "\n")
    }
}

private struct GutterLabel: View {
    let title: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 9, weight: .medium))
            Text(verbatim: value).font(.system(size: 11, weight: .bold)).monospacedDigit()
        }
        .lineLimit(1).fixedSize()
        .foregroundStyle(color)
    }
}

/// One day: used-percent number, glass tube with liquid and share lines, weekday name.
private struct DayTubeView: View {
    let day: DayUsage
    let scale: Double
    let time: Double
    let pulse: Double
    let appeared: Bool
    let isHovered: Bool
    let isDimmed: Bool
    let onHover: (Bool) -> Void

    var body: some View {
        let used = day.used ?? 0
        let full = day.isFull
        let liquidColor = Theme.liquidColor(ratio: day.fillRatio)
        let shareFraction = WeekSummary.dailyShare / scale
        let allowanceFraction = day.allowance / scale
        let carryColor = day.carry > 0 ? Theme.carryUp : Theme.carryDown
        let fill: CGFloat = used > 0 ? max(min(used, scale) / scale, Layout.minimumFill) : 0
        let shown = appeared ? fill : 0
        let phase = time * 1.8 + Double(day.index) * 0.9
        let amplitude: CGFloat = day.isToday ? 2.8 : 1.8
        VStack(spacing: Layout.tubeSpacing) {
            Text(day.used.map { Formatters.wholePercent($0) } ?? "")
                .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                .foregroundStyle(full ? Theme.fullText : .primary)
                .frame(height: Layout.numberRowHeight)
            ZStack(alignment: .bottom) {
                Color.clear.glassCapsule()
                liquid(level: shown, phase: phase, amplitude: amplitude, color: liquidColor)
            }
            .frame(height: Layout.tubeHeight)
            .clipShape(Capsule())
            .overlay {
                // Dashed daily-share line, labelled in the gutter on the right.
                line(atFraction: shareFraction)
                    .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .clipShape(Capsule())
            }
            .overlay {
                // Fainter dotted line: the share this day really has after carry-over.
                if day.hasCarry {
                    line(atFraction: allowanceFraction)
                        .stroke(carryColor.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 3]))
                        .clipShape(Capsule())
                }
            }
            .overlay {
                if day.isToday { glow(Theme.todayGlow, strong: 0.9, soft: 0.5) }
            }
            .overlay {
                if full { glow(Theme.fullGlow, strong: 0.95, soft: 0.6).opacity(pulse) }
            }
            Text(Formatters.dayName(day))
                .font(.caption2.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .background {
            if isHovered {
                Capsule().fill(liquidColor.opacity(0.45))
                    .padding(.vertical, 14).blur(radius: 14)
            }
        }
        .scaleEffect(isHovered ? 1.05 : 1)
        .opacity((day.isFuture ? 0.45 : 1) * (isDimmed ? 0.55 : 1))
        .contentShape(Rectangle())
        .onHover(perform: onHover)
        .animation(.spring(duration: 0.9, bounce: 0.2), value: shown)
    }

    private func line(atFraction fraction: Double) -> Path {
        Path { path in
            let y = Layout.tubeHeight * (1 - fraction)
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: Layout.lineLength, y: y))
        }
    }

    private func glow(_ color: Color, strong: Double, soft: Double) -> some View {
        Capsule().strokeBorder(color, lineWidth: 1.5)
            .shadow(color: color.opacity(strong), radius: 4)
            .shadow(color: color.opacity(soft), radius: 9)
    }

    /// Back wave (paler, other phase) behind the front wave gives the liquid some depth.
    private func liquid(level: CGFloat, phase: Double, amplitude: CGFloat, color: Color) -> some View {
        ZStack {
            LiquidShape(level: level, phase: phase + 2.2, amplitude: amplitude)
                .fill(color.opacity(0.45))
            LiquidShape(level: level, phase: phase, amplitude: amplitude)
                .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
        }
    }
}
