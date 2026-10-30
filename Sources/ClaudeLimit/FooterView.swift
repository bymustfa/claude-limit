import SwiftUI
import ServiceManagement
import ClaudeLimitCore

/// Thin wrapper over `SMAppService` for the "Launch at login" toggle.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

/// Week line, poll status and the buttons.
struct FooterView: View {
    @ObservedObject var store: SnapshotStore
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        let summary = store.summary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(weekLine(summary)).font(.caption)
                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                    .help(info(summary))
            }
            Text(pollStatus)
                .font(.caption2)
                .foregroundStyle(store.pollError == nil ? Color.secondary : Color.orange)
            HStack {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox).font(.caption)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do { try LaunchAtLogin.setEnabled(enabled) }
                        catch { launchAtLogin = LaunchAtLogin.isEnabled }
                    }
                Spacer()
                Button(store.isPolling ? "Updating…" : "Refresh") { Task { await store.poll() } }
                    .glassButton().disabled(store.isPolling)
                Button("Quit") { NSApplication.shared.terminate(nil) }.glassButton()
            }
        }
    }

    private func weekLine(_ summary: WeekSummary) -> String {
        String(localized: "Week ≈\(Formatters.percent(summary.weeklyPercent)) · resets \(Formatters.resetText(summary.weekEnd)) (\(Formatters.countdown(to: summary.weekEnd, from: store.now)))")
    }

    private var pollStatus: String {
        if store.isPolling { return String(localized: "Fetching from Claude…") }
        if let error = store.pollError { return String(localized: "Update failed: \(error.message)") }
        guard let lastPoll = store.lastPoll else { return String(localized: "Not updated yet") }
        let minutes = Int(store.now.timeIntervalSince(lastPoll) / 60)
        return minutes < 1 ? String(localized: "Updated ✓ (just now)") : String(localized: "Last update: \(minutes) min ago")
    }

    private func info(_ summary: WeekSummary) -> String {
        var text = String(localized: "Days change at local midnight; the first and last day absorb the gap to the reset time. Claude Code reports whole percents, so values may be off by ±1.")
        if let fiveHour = summary.fiveHour {
            let countdown = Formatters.countdown(to: Date(timeIntervalSince1970: fiveHour.resetsAt), from: store.now)
            text += "\n" + String(localized: "5-hour limit: \(Formatters.percent(fiveHour.percent)), resets in \(countdown).")
        }
        return text
    }
}
