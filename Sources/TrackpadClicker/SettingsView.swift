import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var coordinator: GestureCoordinator
    @State private var showsAdvancedSettings = false
    @State private var selectedPage = SettingsPage.settings

    private enum SettingsPage: Hashable {
        case settings
        case test
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            settingsPage
                .tabItem { Label("設定", systemImage: "slider.horizontal.3") }
                .tag(SettingsPage.settings)

            testPage
                .tabItem { Label("測試", systemImage: "hand.tap") }
                .tag(SettingsPage.test)
        }
        .frame(minWidth: 620, minHeight: 560)
        .onChange(of: selectedPage) { _, page in
            coordinator.setTesting(page == .test)
        }
        .onDisappear { coordinator.setTesting(false) }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if coordinator.status == .needsPermission {
                    permissionCard
                } else if coordinator.status == .noTrackpad || coordinator.status == .eventMonitorUnavailable {
                    warningCard
                }

                if coordinator.status == .listening || coordinator.status == .stopped {
                    activityRow
                }
                gestureList
                advancedSettings
                footer
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private var testPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("手勢測試")
                        .font(.largeTitle.bold())
                    Text("測試期間只顯示結果，不會執行設定的動作。")
                        .foregroundStyle(.secondary)
                }

                if coordinator.status == .needsPermission {
                    permissionCard
                } else if coordinator.status == .noTrackpad || coordinator.status == .eventMonitorUnavailable {
                    warningCard
                }
                testTrackpad
                testResults
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private var testTrackpad: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.quaternary)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.separator))
                HStack(spacing: 22) {
                    ForEach(0..<min(coordinator.fingerCount, 5), id: \.self) { _ in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)
                    }
                }
            }
            .frame(height: 110)

            Text(coordinator.fingerCount == 0
                 ? "將手指放在觸控板上開始測試"
                 : "目前偵測到 \(coordinator.fingerCount) 指")
                .font(.headline)
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.55)))
    }

    private var testResults: some View {
        VStack(spacing: 0) {
            ForEach(Array(GestureKind.allCases.enumerated()), id: \.element.id) { index, gesture in
                HStack(spacing: 12) {
                    Image(systemName: gesture.symbol)
                        .frame(width: 28)
                    Text(gesture.title)
                    Spacer()
                    if coordinator.detectedGestures.contains(gesture) {
                        Label("已辨識", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("等待")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if index < GestureKind.allCases.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }

            Divider()
            HStack {
                Text(coordinator.lastGesture.map { "上次：\($0.title)" } ?? "尚未辨識手勢")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("清除結果") { coordinator.clearTestResults() }
            }
            .padding(14)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.55)))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trackpad Clicker")
                    .font(.largeTitle.bold())
                Text("選擇手勢與要執行的動作")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("啟用", isOn: masterEnabled)
                .toggleStyle(.switch)
        }
    }

    private var masterEnabled: Binding<Bool> {
        Binding(
            get: { preferences.value.isEnabled },
            set: {
                preferences.value.isEnabled = $0
                coordinator.refresh()
            }
        )
    }

    private var activityRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(nsColor: coordinator.status.color))
                .frame(width: 9, height: 9)
            Text(coordinator.status.title)
                .fontWeight(.medium)
            Spacer()
            if coordinator.fingerCount > 0 {
                Text("偵測到 \(coordinator.fingerCount) 指")
                    .foregroundStyle(.secondary)
            } else if let lastGesture = coordinator.lastGesture {
                Text("上次：\(lastGesture.title)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var gestureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(GestureKind.allCases.enumerated()), id: \.element.id) { index, gesture in
                GestureRow(gesture: gesture)
                if index < GestureKind.allCases.count - 1 {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.55)))
    }

    private var advancedSettings: some View {
        DisclosureGroup("進階設定", isExpanded: $showsAdvancedSettings) {
            VStack(spacing: 14) {
                SliderSetting(
                    title: "最長輕點時間",
                    value: Binding(get: { preferences.value.tapDuration }, set: {
                        preferences.value.tapDuration = $0
                    }),
                    range: 0.18...0.55,
                    valueText: "\(Int(preferences.value.tapDuration * 1000)) ms"
                )
                Divider()
                SliderSetting(
                    title: "移動容許範圍",
                    value: Binding(get: { preferences.value.movementTolerance }, set: {
                        preferences.value.movementTolerance = $0
                    }),
                    range: 0.015...0.09,
                    valueText: String(format: "%.1f%%", preferences.value.movementTolerance * 100)
                )
                Divider()
                Toggle("辨識成功時提供觸覺回饋", isOn: Binding(get: {
                    preferences.value.hapticFeedback
                }, set: { preferences.value.hapticFeedback = $0 }))
                Divider()
                Toggle("登入時自動啟動", isOn: Binding(get: {
                    preferences.value.launchAtLogin
                }, set: {
                    preferences.value.launchAtLogin = $0
                    LaunchAtLoginController.setEnabled($0)
                }))
                Divider()
                HStack {
                    Button("打開觸控板設定") { AccessibilityController.openTrackpadSettings() }
                    Spacer()
                    Button("結束程式") { NSApp.terminate(nil) }
                    Spacer()
                    Button("回復預設值") {
                        preferences.value = AppPreferences()
                        coordinator.refresh()
                    }
                }
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.55)))
    }

    private var permissionCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("需要輔助使用權限").font(.headline)
                Text("權限只用來輸出滑鼠與鍵盤動作。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("打開設定") { coordinator.requestPermission() }
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var warningCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(coordinator.status == .noTrackpad
                 ? "找不到觸控板。請確認已連接後重新偵測。"
                 : "事件監聽未能啟動，請確認輔助使用權限。")
            Spacer()
            Button("重新偵測") { coordinator.refresh() }
        }
        .padding(14)
        .background(.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("三指輕點會在快速碰觸後放開時觸發；實體按壓只在真正按下觸控板時觸發。")
            Text("所有辨識都在本機完成。完整多指版本使用 MultitouchSupport，僅供直接散佈。")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GestureRow: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var coordinator: GestureCoordinator
    let gesture: GestureKind

    private var binding: GestureBinding { preferences.binding(for: gesture) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: gesture.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(binding.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(gesture.title).fontWeight(.medium)
                Text(gesture.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Picker("動作", selection: Binding(get: { binding.action }, set: {
                preferences.update(gesture, action: $0)
                coordinator.refresh()
            })) {
                ForEach(GestureAction.allCases) { action in
                    Label(action.title, systemImage: action.symbol).tag(action)
                }
            }
            .labelsHidden()
            .frame(width: 160)
            .disabled(!binding.isEnabled)
            Toggle("啟用 \(gesture.title)", isOn: Binding(get: { binding.isEnabled }, set: {
                preferences.update(gesture, enabled: $0)
                coordinator.refresh()
            }))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct SliderSetting: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    var body: some View {
        HStack(spacing: 16) {
            Text(title).frame(width: 126, alignment: .leading)
            Slider(value: $value, in: range)
            Text(valueText)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .trailing)
        }
    }
}
