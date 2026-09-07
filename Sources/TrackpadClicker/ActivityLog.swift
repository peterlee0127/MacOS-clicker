import Foundation

@MainActor
final class ActivityLog: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let date = Date()
        let category: String
        let message: String
    }

    static let capacity = 1_000
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var isEnabled: Bool
    private let defaults: UserDefaults
    private static let enabledKey = "trackpadClicker.loggingEnabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.enabledKey)
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if !enabled { record("紀錄", "已停止紀錄；既有紀錄仍可查看。") }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
        if enabled { record("紀錄", "已開始紀錄。") }
    }

    func record(_ category: String, _ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        entries.append(Entry(category: category, message: message()))
        if entries.count > Self.capacity {
            entries.removeFirst(entries.count - Self.capacity)
        }
    }

    func clear() { entries.removeAll() }

    var plainText: String {
        entries.map {
            "\($0.date.formatted(date: .numeric, time: .standard)) [\($0.category)] \($0.message)"
        }.joined(separator: "\n")
    }
}
