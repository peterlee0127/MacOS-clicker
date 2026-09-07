import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    @EnvironmentObject private var coordinator: GestureCoordinator
    @State private var showsAdvancedSettings = false
    @State private var selectedPage = SettingsPage.settings
    @State private var showsPermissionResetConfirmation = false
    @State private var permissionResetErrorMessage: String?

    private enum SettingsPage: Hashable {
        case settings
        case test
        case logs
    }

    var body: some View {
        Group {
            switch selectedPage {
            case .settings: settingsPage
            case .test: testPage
            case .logs: logsPage
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .onChange(of: selectedPage) { _, page in
            coordinator.setTesting(page == .test)
        }
        .onAppear { coordinator.setTesting(selectedPage == .test) }
        .onDisappear { coordinator.setTesting(false) }
        .onChange(of: coordinator.isTesting) { _, testing in
            if !testing && selectedPage == .test { selectedPage = .settings }
        }
        .confirmationDialog(
            "重設輔助使用權限？",
            isPresented: $showsPermissionResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("重設並打開系統設定", role: .destructive) {
                resetAccessibilityPermission()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("目前授權會被移除，必須在系統設定中重新允許此 App。")
        }
        .alert(
            "無法重設輔助使用權限",
            isPresented: Binding(
                get: { permissionResetErrorMessage != nil },
                set: { if !$0 { permissionResetErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(permissionResetErrorMessage ?? "未知錯誤")
        }
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

    private var logsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("執行紀錄").font(.largeTitle.bold())
                Spacer()
                pageSwitcher
            }
            ActivityLogView(log: coordinator.activityLog)
        }
        .padding(28)
    }

    private var testPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("手勢測試")
                            .font(.largeTitle.bold())
                        Text("測試期間只顯示結果，不會執行設定的動作。")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    pageSwitcher
                }

                if coordinator.status == .needsPermission {
                    permissionCard
                } else if coordinator.status == .noTrackpad || coordinator.status == .eventMonitorUnavailable {
                    warningCard
                }
                activityRow
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
            pageSwitcher
            Toggle("啟用", isOn: masterEnabled)
                .toggleStyle(.switch)
        }
    }

    private var pageSwitcher: some View {
        Picker("頁面", selection: $selectedPage) {
            Text("設定").tag(SettingsPage.settings)
            Text("測試").tag(SettingsPage.test)
            Text("紀錄").tag(SettingsPage.logs)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.regular)
        .frame(width: 195)
        .accessibilityLabel("頁面")
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
            Text(coordinator.isTesting ? "測試中・不執行動作" : coordinator.status.title)
                .fontWeight(.medium)
            Spacer()
            if coordinator.fingerCount > 0 {
                Text("偵測到 \(coordinator.fingerCount) 指")
                    .foregroundStyle(.secondary)
            } else if let lastGesture = coordinator.lastGesture {
                Text("上次：\(lastGesture.title)")
                    .foregroundStyle(.secondary)
            }
            Button("重新偵測") { coordinator.reconnect() }
                .help(coordinator.lastRecovery.map { "上次重新偵測：\($0.formatted(date: .omitted, time: .standard))" }
                      ?? "重新連接觸控板與事件監聽，保留所有設定")
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var gestureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("手勢")
                .font(.headline)

            gestureGroup(
                title: "雙指",
                note: "預設關閉，避免覆蓋系統輔助按鈕",
                gestures: [.twoFingerClick, .twoFingerTap]
            )
            gestureGroup(
                title: "三指",
                gestures: [.threeFingerClick, .threeFingerTap]
            )
            gestureGroup(
                title: "四指",
                gestures: [.fourFingerClick, .fourFingerTap]
            )
            gestureGroup(
                title: "Force Touch",
                gestures: [.oneFingerForceTouch]
            )
        }
    }

    private func gestureGroup(
        title: String,
        note: String? = nil,
        gestures: [GestureKind]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 5)

            ForEach(Array(gestures.enumerated()), id: \.element.id) { index, gesture in
                GestureRow(gesture: gesture)
                if index < gestures.count - 1 {
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
                        coordinator.updateSensitivity()
                    }),
                    range: 0.18...0.55,
                    valueText: "\(Int(preferences.value.tapDuration * 1000)) ms"
                )
                Divider()
                SliderSetting(
                    title: "移動容許範圍",
                    value: Binding(get: { preferences.value.movementTolerance }, set: {
                        preferences.value.movementTolerance = $0
                        coordinator.updateSensitivity()
                    }),
                    range: 0.015...0.09,
                    valueText: String(format: "%.1f%%", preferences.value.movementTolerance * 100)
                )
                Divider()
                Toggle("辨識成功時提供觸覺回饋", isOn: Binding(get: {
                    preferences.value.hapticFeedback
                }, set: { preferences.value.hapticFeedback = $0 }))
                Divider()
                if LaunchAtLoginController.isAvailable {
                    Toggle("登入時自動啟動", isOn: Binding(get: {
                        preferences.value.launchAtLogin
                    }, set: {
                        preferences.value.launchAtLogin = $0
                        LaunchAtLoginController.setEnabled($0)
                    }))
                } else {
                    Label("Debug 版本不提供登入時自動啟動", systemImage: "hammer")
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Button("打開觸控板設定") { AccessibilityController.openTrackpadSettings() }
                    Spacer()
                    Button("重設輔助使用權限", role: .destructive) {
                        showsPermissionResetConfirmation = true
                    }
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

    private func resetAccessibilityPermission() {
        coordinator.stop()
        do {
            try AccessibilityController.reset()
            coordinator.requestPermission()
            AccessibilityController.openSettings()
        } catch {
            permissionResetErrorMessage = error.localizedDescription
            coordinator.refresh()
        }
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
            Button("重設權限") {
                showsPermissionResetConfirmation = true
            }
            .buttonStyle(.bordered)
            Button("打開設定") {
                coordinator.requestPermission()
                AccessibilityController.openSettings()
            }
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
            Text("輕點會在快速碰觸後放開時觸發；實體按壓必須真正按下觸控板才會觸發。")
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
        VStack(alignment: .leading, spacing: 8) {
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
                Picker("動作", selection: Binding(get: { binding.action }, set: { action in
                    preferences.update(gesture, action: action)
                    coordinator.refresh()
                })) {
                    ForEach(GestureAction.allCases) { action in
                        Label(action.title, systemImage: action.symbol).tag(action)
                    }
                }
                .labelsHidden()
                .frame(width: 178)
                .disabled(!binding.isEnabled)
                Toggle("啟用 \(gesture.title)", isOn: Binding(get: { binding.isEnabled }, set: {
                    preferences.update(gesture, enabled: $0)
                    coordinator.refresh()
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if binding.action == .openApplication {
                HStack(spacing: 8) {
                    if let application = binding.application {
                        Label(application.displayName, systemImage: "app.fill")
                            .lineLimit(1)
                            .help(application.path)
                    } else {
                        Label("請選擇要開啟或切換的 App", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button(binding.application == nil ? "選擇 App" : "更換 App") {
                        chooseApplication()
                    }
                    .controlSize(.small)
                    .disabled(!binding.isEnabled)
                }
                .padding(.leading, 44)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "選擇要開啟或切換到前景的 App"
        panel.prompt = "選擇"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let target = ApplicationTarget(
                bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
                path: url.path,
                displayName: url.deletingPathExtension().lastPathComponent
            )
            preferences.setApplication(target, for: gesture)
            coordinator.refresh()
        }
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

private struct ActivityLogView: View {
    @ObservedObject var log: ActivityLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("啟用紀錄", isOn: Binding(
                get: { log.isEnabled },
                set: { log.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            Text("保留本次開啟程式的最近 1,000 筆紀錄，結束程式後清空。開關設定會保留；關閉後停止新增，既有紀錄仍可查看。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(log.isEnabled ? "正在紀錄" : "紀錄已關閉",
                      systemImage: log.isEnabled ? "record.circle" : "pause.circle")
                Spacer()
                Text("\(log.entries.count) 筆").foregroundStyle(.secondary)
                Button("複製全部") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(log.plainText, forType: .string)
                }
                .disabled(log.entries.isEmpty)
                Button("清除紀錄") { log.clear() }
                    .disabled(log.entries.isEmpty)
            }
            Divider()
            if log.entries.isEmpty {
                ContentUnavailableView(
                    log.isEnabled ? "尚無紀錄" : "紀錄尚未啟用",
                    systemImage: "list.bullet.rectangle",
                    description: Text(log.isEnabled
                        ? "操作手勢或重新偵測後，紀錄會顯示在這裡。"
                        : "開啟上方開關後，會記錄手勢、監聽狀態與睡眠喚醒事件。")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(log.entries.reversed()) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(entry.category).fontWeight(.medium)
                                    Spacer()
                                    Text(entry.date.formatted(date: .numeric, time: .standard))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                                Text(entry.message)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
