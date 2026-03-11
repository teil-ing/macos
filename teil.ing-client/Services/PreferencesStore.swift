import SwiftUI

// MARK: - ClipboardMode

/// Controls what is written to the clipboard after a successful upload.
enum ClipboardMode: String, CaseIterable, Identifiable {
    /// Copy the share URL (default — existing behavior).
    case url = "url"
    /// Copy the captured image as PNG data.
    case image = "image"

    var id: String { rawValue }

    /// Human-readable label for display in the preferences UI.
    var displayName: String {
        switch self {
        case .url: return "Share URL"
        case .image: return "Image"
        }
    }
}

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

    /// Automatically check for updates on launch and every 4 hours.
    /// Default: true (users get updates without manual checking).
    @AppStorage("pref_autoCheckForUpdates")
    var autoCheckForUpdates: Bool = true

    /// Make uploaded images private (owner-only, not accessible via share link).
    /// When true, sends `private=true` as a multipart form field.
    /// When false, omits the field entirely (API contract: omission = public).
    /// Default: false (public uploads by default, privacy is opt-in).
    @AppStorage("pref_privateUpload")
    var privateUpload: Bool = false

    /// Controls what is written to the clipboard after upload.
    /// Stored as raw String value because @AppStorage does not support custom enums directly.
    /// Default: .url (preserves existing behavior for all users).
    @AppStorage("pref_clipboardMode")
    private var clipboardModeRaw: String = ClipboardMode.url.rawValue

    /// Typed accessor for the clipboard mode preference.
    var clipboardMode: ClipboardMode {
        get { ClipboardMode(rawValue: clipboardModeRaw) ?? .url }
        set { clipboardModeRaw = newValue.rawValue }
    }

    private init() {}
}
