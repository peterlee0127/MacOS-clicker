import ServiceManagement

enum LaunchAtLoginController {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The UI remains usable when running as a raw SwiftPM executable; registration
            // becomes available once built as the included .app bundle.
        }
    }
}
