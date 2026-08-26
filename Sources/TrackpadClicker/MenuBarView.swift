import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var coordinator: GestureCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(Color(nsColor: coordinator.status.color)).frame(width: 8, height: 8)
                Text(coordinator.status.title).font(.headline)
            }
            Divider()
            Toggle("啟用觸控板手勢", isOn: Binding(get: {
                preferences.value.isEnabled
            }, set: {
                preferences.value.isEnabled = $0
                coordinator.refresh()
            }))
            Button("設定⋯") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")
            Divider()
            Button("結束 Trackpad Clicker") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(8)
        .frame(width: 250)
    }
}
