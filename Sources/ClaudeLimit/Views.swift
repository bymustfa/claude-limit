import SwiftUI
import ServiceManagement
import ClaudeLimitCore

private let ok = Color(red: 1.0, green: 0.66, blue: 0.2)
private let over = Color(red: 0.95, green: 0.27, blue: 0.18)
private let carryUp = Color(red: 0.3, green: 0.8, blue: 0.75)
private let carryDown = Color(red: 1.0, green: 0.55, blue: 0.2)

struct PanelView: View {
    @ObservedObject var store: SnapshotStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var appeared = false
    @State private var visible = false
    @State private var hovered: Int?
    @State private var mouse = CGPoint.zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let w = store.summary
        VStack(alignment: .leading, spacing: 14) {
            header(w)
            if w.hasData {
                dayBars(w)
            } else {
                Text("Henüz veri yok. Claude Code'da bir mesaj gönder.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer(w)
        }
        .padding(16)
        .frame(width: 380)
    }

    private func header(_ w: WeekSummary) -> some View {
        let share = w.today.allowance
        let carry = w.today.carry
        let used = w.todayUsed
        let (label, color): (String, Color) = !w.hasData ? ("", .secondary)
            : used > share ? ("Payı aştın", over)
            : used >= share * 0.7 ? ("Paya yaklaştın", ok)
            : ("Rahatsın", .green)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Bugün").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("≈\(Fmt.pct(used))").font(.system(size: 30, weight: .bold)).monospacedDigit()
                Text("/ \(Fmt.pct(share))").font(.title3).foregroundStyle(.secondary).monospacedDigit()
                if w.hasData, abs(carry) >= 0.05 {
                    Text("Devir \(Fmt.carry(carry))").font(.caption.weight(.medium)).monospacedDigit()
                        .foregroundStyle(carry > 0 ? carryUp : carryDown)
                }
                Spacer()
                if w.hasData {
                    Text(label).font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .glassCapsule(tint: color.opacity(0.35))
                        .foregroundStyle(color)
                }
            }
        }
    }

    /// Blue when far from the daily share, orange near it, dark red once it is reached or passed.
    private func liquidColor(_ ratio: Double) -> Color {
        let stops: [(at: Double, rgb: (Double, Double, Double))] = [
            (0, (0.25, 0.58, 1.0)), (0.45, (0.55, 0.80, 0.75)), (0.8, (1.0, 0.66, 0.2)), (1.0, (0.62, 0.07, 0.10)),
        ]
        let x = min(max(ratio, 0), 1)
        for i in 1..<stops.count where x <= stops[i].at {
            let (a, b) = (stops[i - 1], stops[i])
            let f = (x - a.at) / (b.at - a.at)
            return Color(red: a.rgb.0 + (b.rgb.0 - a.rgb.0) * f,
                         green: a.rgb.1 + (b.rgb.1 - a.rgb.1) * f,
                         blue: a.rgb.2 + (b.rgb.2 - a.rgb.2) * f)
        }
        return Color(red: 0.62, green: 0.07, blue: 0.10)
    }

    private func dayBars(_ w: WeekSummary) -> some View {
        let share = WeekSummary.dailyShare
        let maxAllowance = w.days.map(\.allowance).max() ?? share
        let scale = max(maxAllowance * 1.6, share * 1.6, w.days.compactMap(\.used).max() ?? 0)
        let height: CGFloat = 110
        let numberRow: CGFloat = 16
        let shareFrac = share / scale
        let neonRed = Color(red: 1.0, green: 0.2, blue: 0.2)
        let neonToday = Color(red: 0.6, green: 0.85, blue: 1.0)
        return HStack(alignment: .top, spacing: 6) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !visible || reduceMotion)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                // Slow blink between 35% and 100% for tubes whose share is used up.
                let pulse = reduceMotion ? 1 : 0.675 + 0.325 * sin(t * 2.6)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(w.days, id: \.index) { d in
                        let used = d.used ?? 0
                        let full = d.isFull
                        let allowFrac = d.allowance / scale
                        let showCarry = abs(d.carry) >= 0.05
                        let carryColor = d.carry > 0 ? carryUp : carryDown
                        // A sliver of liquid stays visible for any non-zero usage.
                        let frac: CGFloat = used > 0 ? max(min(used, scale) / scale, 0.07) : 0
                        let shown = appeared ? frac : 0
                        let phase = t * 1.8 + Double(d.index) * 0.9
                        let amp: CGFloat = d.isToday ? 2.8 : 1.8
                        VStack(spacing: 5) {
                            Text(d.used.map { "%\(Int($0.rounded()))" } ?? "")
                                .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(full ? Color(red: 1.0, green: 0.45, blue: 0.42) : .primary)
                                .frame(height: numberRow)
                            ZStack(alignment: .bottom) {
                                Color.clear.glassCapsule()
                                liquid(shown, phase, amp, color: liquidColor(d.allowance > 0.05 ? used / d.allowance : 1), height: height)
                            }
                            .frame(height: height)
                            .clipShape(Capsule())
                            .overlay {
                                // Dashed daily-share line, labelled in the gutter on the right.
                                Path { p in
                                    let y = height * (1 - shareFrac)
                                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 60, y: y))
                                }
                                .stroke(.primary.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                .clipShape(Capsule())
                            }
                            .overlay {
                                // Fainter dotted line: the share this day really has after carry-over.
                                if showCarry {
                                    Path { p in
                                        let y = height * (1 - allowFrac)
                                        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 60, y: y))
                                    }
                                    .stroke(carryColor.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 3]))
                                    .clipShape(Capsule())
                                }
                            }
                            .overlay {
                                if d.isToday {
                                    Capsule().strokeBorder(neonToday, lineWidth: 1.5)
                                        .shadow(color: neonToday.opacity(0.9), radius: 4)
                                        .shadow(color: neonToday.opacity(0.5), radius: 9)
                                }
                            }
                            .overlay {
                                if full {
                                    Capsule().strokeBorder(neonRed, lineWidth: 1.5)
                                        .shadow(color: neonRed.opacity(0.95), radius: 4)
                                        .shadow(color: neonRed.opacity(0.6), radius: 9)
                                        .opacity(pulse)
                                }
                            }
                            Text(Fmt.dayName(d))
                                .font(.caption2.weight(d.isToday ? .bold : .regular))
                                .foregroundStyle(d.isToday ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .background {
                            if hovered == d.index {
                                Capsule().fill(liquidColor(d.allowance > 0.05 ? used / d.allowance : 1).opacity(0.45))
                                    .padding(.vertical, 14).blur(radius: 14)
                            }
                        }
                        .scaleEffect(hovered == d.index ? 1.05 : 1)
                        .opacity((d.isFuture ? 0.45 : 1) * (hovered != nil && hovered != d.index ? 0.55 : 1))
                        .contentShape(Rectangle())
                        .onHover { inside in
                            if inside { hovered = d.index } else if hovered == d.index { hovered = nil }
                        }
                        .animation(.spring(duration: 0.9, bounce: 0.2), value: shown)
                    }
                }
            }
            // Gutter labels sitting on the lines: the carried share goes on the far side of the daily share.
            let top = numberRow + 5
            let yShare = top + height * (1 - shareFrac)
            let yAllow = top + height * (1 - w.today.allowance / scale)
            let carried = abs(w.today.carry) >= 0.05
            let up = w.today.carry > 0
            ZStack(alignment: .topLeading) {
                Color.clear.frame(width: 58, height: 1)
                gutterLabel("günlük pay", Fmt.pct(share), .primary.opacity(0.8))
                    .offset(y: carried ? (up ? yShare + 1 : yShare - 25) : yShare - 12)
                if carried {
                    gutterLabel("bugünkü pay", Fmt.pct(w.today.allowance), (up ? carryUp : carryDown).opacity(0.9))
                        .offset(y: up ? yAllow - 25 : yAllow + 1)
                }
            }
            .frame(width: 58)
        }
        .padding(.bottom, 4)
        .coordinateSpace(name: "bars")
        .onContinuousHover(coordinateSpace: .named("bars")) { phase in
            if case .active(let p) = phase { mouse = p }
        }
        .overlay(alignment: .topLeading) {
            // Own hover card: the system .help tooltip never shows under the 30 fps TimelineView.
            if let i = hovered, let d = w.days.first(where: { $0.index == i }) {
                Text(tip(d))
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

    private func tip(_ d: DayUsage) -> String {
        var lines = [Fmt.dayLong(d)]
        if let used = d.used {
            lines.append("Kullanılan: ≈\(Fmt.pct(used))")
            lines.append("Pay: \(Fmt.pct(d.allowance)) (sabit \(Fmt.pct(WeekSummary.dailyShare)))")
            if abs(d.carry) >= 0.05 { lines.append("Devir: \(Fmt.carry(d.carry))") }
            let left = d.allowance - used
            if let total = d.weekTotal { lines.append("Haftalık toplam: ≈\(Fmt.pct(total))") }
            lines.append(d.isFull ? "Pay doldu" : (d.isToday ? "Bugün kalan: \(Fmt.pct(left))" : "Artan: \(Fmt.pct(left))"))
        } else {
            lines.append("Tahmini pay: \(Fmt.pct(d.allowance))")
            lines.append("Bugünden sonra hiç kullanmazsan düşen pay")
        }
        return lines.joined(separator: "\n")
    }

    private func gutterLabel(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.system(size: 9, weight: .medium))
            Text(value).font(.system(size: 11, weight: .bold)).monospacedDigit()
        }
        .lineLimit(1).fixedSize()
        .foregroundStyle(color)
    }

    /// Back wave (paler, other phase) behind the front wave gives the liquid some depth.
    private func liquid(_ level: CGFloat, _ phase: Double, _ amp: CGFloat, color: Color, height: CGFloat) -> some View {
        ZStack {
            LiquidShape(level: level, phase: phase + 2.2, amplitude: amp)
                .fill(color.opacity(0.45))
            LiquidShape(level: level, phase: phase, amplitude: amp)
                .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .top, endPoint: .bottom))
        }
    }

    private func footer(_ w: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Hafta ≈\(Fmt.pct(w.weeklyPct)) · sıfırlanma \(Fmt.resetText(w.weekEnd)) (\(Fmt.countdown(to: w.weekEnd, from: store.now)))")
                    .font(.caption)
                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .help(info(w))
            }
            Text(pollStatus)
                .font(.caption2)
                .foregroundStyle(store.pollError == nil ? Color.secondary : Color.orange)
            HStack {
                Toggle("Girişte aç", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox).font(.caption)
                    .onChange(of: launchAtLogin) { _, on in
                        do { on ? try SMAppService.mainApp.register() : try SMAppService.mainApp.unregister() }
                        catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
                    }
                Spacer()
                Button(store.isPolling ? "Güncelleniyor…" : "Yenile") { Task { await store.poll() } }
                    .glassButton().disabled(store.isPolling)
                Button("Çık") { NSApplication.shared.terminate(nil) }.glassButton()
            }
        }
    }

    private var pollStatus: String {
        if store.isPolling { return "Claude'dan veri alınıyor…" }
        if let e = store.pollError { return "Güncellenemedi: \(e.message)" }
        guard let t = store.lastPoll else { return "Henüz güncellenmedi" }
        let mins = Int(store.now.timeIntervalSince(t) / 60)
        return mins < 1 ? "Güncellendi ✓ (az önce)" : "Son güncelleme: \(mins) dk önce"
    }

    private func info(_ w: WeekSummary) -> String {
        var t = "Günler \(Fmt.hourText(w.weekEnd)) itibarıyla 24 saatlik dilimlerdir. Claude Code yüzdeyi tam sayı verdiği için ±1 puan sapabilir."
        if let f = w.fiveHour {
            t += "\n5 saatlik limit: \(Fmt.pct(f.pct)), \(Fmt.countdown(to: Date(timeIntervalSince1970: f.resetsAt), from: store.now)) sonra sıfırlanır."
        }
        return t
    }
}
