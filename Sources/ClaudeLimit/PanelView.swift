import SwiftUI
import ClaudeLimitCore

struct PanelView: View {
    @ObservedObject var store: SnapshotStore

    @State private var showHistory = false

    var body: some View {
        let summary = store.viewed
        VStack(alignment: .leading, spacing: 14) {
            if store.hasHistory { navigationRow }
            if showHistory {
                HistoryView(store: store)
            } else {
                HeaderView(summary: summary)
                if summary.hasData {
                    DayBarsView(summary: summary)
                } else {
                    Text("No data yet. Waiting for the first update from Claude Code.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider()
            FooterView(store: store)
        }
        .padding(16)
        .frame(width: 380)
        // Reopening the panel starts at the current week again.
        .onDisappear { store.showWeek(offset: 0); showHistory = false }
    }

    /// Week navigator, or the History title, with the toggle between the two on the right.
    private var navigationRow: some View {
        HStack {
            if showHistory {
                Text("History").font(.caption.weight(.semibold))
                Spacer()
            } else {
                WeekNavigatorView(store: store)
            }
            Button { showHistory.toggle() } label: {
                Image(systemName: showHistory ? "xmark" : "calendar")
                    .font(.caption.weight(.semibold)).frame(width: 24, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showHistory ? "Back to week" : "History")
        }
    }
}

/// ◀ week ▶ : steps through the finished weeks recorded in the database.
private struct WeekNavigatorView: View {
    @ObservedObject var store: SnapshotStore

    var body: some View {
        HStack {
            arrow("chevron.left", label: "Previous week", enabled: store.canGoBack) {
                store.showWeek(offset: store.weekOffset - 1)
            }
            Spacer()
            Text(store.viewed.isPast ? Formatters.weekRange(store.viewed) : String(localized: "This week"))
                .font(.caption.weight(.semibold))
            Spacer()
            arrow("chevron.right", label: "Next week", enabled: store.canGoForward) {
                store.showWeek(offset: store.weekOffset + 1)
            }
        }
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.caption.weight(.semibold)).frame(width: 24, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
