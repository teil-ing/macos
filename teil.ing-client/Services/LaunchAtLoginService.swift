import os
import ServiceManagement

@MainActor
final class LaunchAtLoginService {

    static let shared = LaunchAtLoginService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ing.teil.client",
        category: "LaunchAtLogin"
    )

    private init() {}

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
            // Revert the preference to match actual state
            PreferencesStore.shared.launchAtLogin = !enabled
        }
    }
}
