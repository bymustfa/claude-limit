import SwiftUI
import ClaudeLimitCore

struct PanelView: View {
    @ObservedObject var store: SnapshotStore

    var body: some View {
        let summary = store.summary
        VStack(alignment: .leading, spacing: 14) {
            HeaderView(summary: summary)
            if summary.hasData {
                DayBarsView(summary: summary)
            } else {
                Text("No data yet. Waiting for the first update from Claude Code.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            FooterView(store: store)
        }
        .padding(16)
        .frame(width: 380)
    }
}
