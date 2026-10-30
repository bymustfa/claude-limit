import SwiftUI

@main
struct ClaudeLimitApp: App {
    @StateObject private var store = SnapshotStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            Text(Formatters.menuBar(store.summary)).monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
