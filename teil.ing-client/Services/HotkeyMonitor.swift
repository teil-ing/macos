import AppKit
import KeyboardShortcuts

// MARK: - Shortcut Names
// Defined at file scope (not nested in a type) for Swift 6 strict concurrency compliance.
// The `default:` parameter writes the shortcut to UserDefaults only if no entry exists yet —
// user changes in Phase 8 will persist across launches.
extension KeyboardShortcuts.Name {
    static let regionCapture = Self(
        "regionCapture",
        default: .init(.x, modifiers: [.command, .shift])
    )
    static let fullscreenCapture = Self(
        "fullscreenCapture",
        default: .init(.s, modifiers: [.command, .shift])
    )
    static let windowCapture = Self(
        "windowCapture",
        default: .init(.c, modifiers: [.command, .shift])
    )
}

// MARK: - HotkeyMonitor

/// Registers global keyboard shortcuts for all three capture modes and re-registers
/// them after sleep/wake cycles so shortcuts survive system sleep without an app relaunch.
///
/// This class is `@MainActor` (not an actor) because Carbon event registration
/// requires the main run loop.
@MainActor
final class HotkeyMonitor {

    private var wakeObserver: NSObjectProtocol?

    init() {}

    /// Register hotkey handlers. Call EXACTLY ONCE — `onKeyUp` appends to an internal
    /// array; calling it again creates duplicate handlers (research Pitfall 2).
    func start(
        onRegion: @escaping @MainActor () -> Void,
        onFullscreen: @escaping @MainActor () -> Void,
        onWindow: @escaping @MainActor () -> Void
    ) {
        // Register handlers once
        KeyboardShortcuts.onKeyUp(for: .regionCapture) {
            Task { @MainActor in onRegion() }
        }
        KeyboardShortcuts.onKeyUp(for: .fullscreenCapture) {
            Task { @MainActor in onFullscreen() }
        }
        KeyboardShortcuts.onKeyUp(for: .windowCapture) {
            Task { @MainActor in onWindow() }
        }

        // Re-register after sleep — Carbon hotkeys can fail to re-activate after wake.
        // Only disable/enable — do NOT re-call onKeyUp (would duplicate handlers).
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                KeyboardShortcuts.disable(.regionCapture, .fullscreenCapture, .windowCapture)
                KeyboardShortcuts.enable(.regionCapture, .fullscreenCapture, .windowCapture)
            }
        }
    }

    /// Unregister all handlers and remove the sleep/wake observer.
    func stop() {
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
        KeyboardShortcuts.disable(.regionCapture, .fullscreenCapture, .windowCapture)
    }
}
