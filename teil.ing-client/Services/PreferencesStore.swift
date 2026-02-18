import SwiftUI

// MARK: - PreferencesStore

/// Central observable store for user-configurable upload preferences.
///
/// Uses @AppStorage for transparent UserDefaults persistence and automatic SwiftUI
/// reactivity. All three preferences default to true (privacy-first, zero-friction sharing).
///
/// Values are read at enqueue time in AppDelegate and passed as Bool parameters into
/// UploadService.enqueue() — no actor-crossing required at upload time.
@MainActor
final class PreferencesStore: ObservableObject {

    static let shared = PreferencesStore()

    // MARK: - Preferences

    /// Strip EXIF metadata (location, camera info) from uploaded images server-side.
    /// When true, sends `stripExif=true` as a multipart form field.
    /// When false, omits the field entirely (API contract: omission = no stripping).
    /// Default: true (privacy-first).
    @AppStorage("pref_stripExif")
    var stripExif: Bool = true

    /// Open the share URL in the default browser automatically after upload.
    /// Default: true (user sees share page immediately).
    @AppStorage("pref_openInBrowser")
    var openInBrowser: Bool = true

    /// Copy the share URL to the clipboard automatically after upload.
    /// Default: true (zero-friction sharing).
    @AppStorage("pref_clipboardCopy")
    var clipboardCopy: Bool = true

    /// Start teil.ing automatically when the user logs in.
    /// Default: false (opt-in).
    @AppStorage("pref_launchAtLogin")
    var launchAtLogin: Bool = false

    private init() {}
}
