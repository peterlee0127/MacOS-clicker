import AppKit
import SwiftUI

@MainActor
final class AppModel {
    static let shared = AppModel()

    let preferences: PreferencesStore
    let coordinator: GestureCoordinator

    private init() {
        let preferences = PreferencesStore()
        self.preferences = preferences
        coordinator = GestureCoordinator(preferences: preferences)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var launchedAsLoginItem = false
    private var handledInitialOpenApplicationEvent = false

    override init() {
        super.init()
        // Observe the actual Open Application Apple event instead of polling
        // currentAppleEvent during lifecycle callbacks. The login-item marker is
        // only guaranteed to be present on this event.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenApplication(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the process out of the Dock and Command-Tab while still allowing
        // an explicitly opened settings window to become active.
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.coordinator.refresh()
#if DEBUG
        // Xcode launches the executable directly and may not send the Open
        // Application Apple event used by Finder and LaunchServices.
        showSettings()
#endif
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // A reopen event is generated when the user explicitly opens an app
        // that is already running in the background.
        showSettings()
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // AppKit may request an untitled window as part of initial launch.
        // Only honor it after the Open Application event has established that
        // this was an explicit user launch rather than a login-item launch.
        guard handledInitialOpenApplicationEvent, !launchedAsLoginItem else {
            return false
        }
        showSettings()
        return true
    }

    @objc
    private func handleOpenApplication(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        handledInitialOpenApplicationEvent = true
        launchedAsLoginItem = Self.isLoginItemLaunchEvent(event)
        guard !launchedAsLoginItem else { return }
        showSettings()
    }

    static func isLoginItemLaunchEvent(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
              event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        return event.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
    }

    private func showSettings() {
        DispatchQueue.main.async {
            let window = self.settingsWindow ?? self.makeSettingsWindow()
            self.settingsWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makeSettingsWindow() -> NSWindow {
        let model = AppModel.shared
        let rootView = SettingsView()
            .environmentObject(model.preferences)
            .environmentObject(model.coordinator)
        let window = NSWindow(contentViewController: NSHostingController(rootView: rootView))
        window.title = "Trackpad Clicker 設定"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 680, height: 720))
        window.minSize = NSSize(width: 620, height: 560)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

@main
struct TrackpadClickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(AppModel.shared.preferences)
                .environmentObject(AppModel.shared.coordinator)
        }
        .defaultSize(width: 680, height: 720)
        .windowResizability(.contentMinSize)
    }
}
