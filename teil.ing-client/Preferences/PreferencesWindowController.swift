import AppKit
import SwiftUI

// MARK: - PreferencesWindowController

/// Manages the preferences window lifecycle for a menu bar-only (LSUIElement) app.
///
/// Mirrors the OnboardingWindowController pattern from Phase 2:
/// - Switches activation policy to .regular on open so text fields and shortcut recorders
///   can accept keyboard input (required when running in .accessory mode).
/// - Restores .accessory policy in windowWillClose so the Dock icon disappears on close.
/// - Holds isReleasedWhenClosed = false to prevent deallocation on close.
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - Init

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        // CRITICAL: prevents deallocation when the window closes — allows re-opening
        window.isReleasedWhenClosed = false
        // Non-resizable per locked decision
        window.styleMask.remove(.resizable)

        let hostingController = NSHostingController(rootView: PreferencesView())
        window.contentViewController = hostingController

        super.init(window: window)
        // Set delegate to receive windowWillClose for activation policy restoration
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Public Interface

    /// Opens the preferences window. If already visible, brings it to front.
    func open() {
        if window?.isVisible == true {
            // Already open — bring to front without recreating
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Order matters: set .regular BEFORE makeKeyAndOrderFront so the window
        // can become key and accept keyboard input (text fields, shortcut recorders).
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Restore menu bar-only mode — removes Dock icon
        NSApp.setActivationPolicy(.accessory)
    }
}
