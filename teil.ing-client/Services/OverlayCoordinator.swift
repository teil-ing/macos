import AppKit

// MARK: - OverlayCoordinator

/// Manages the lifecycle of selection overlay windows across all connected displays.
///
/// Usage:
/// ```swift
/// let coordinator = OverlayCoordinator()
/// let rect = await coordinator.beginRegionSelection()
/// // rect is in global screen coordinates, or nil if the user cancelled
/// ```
@MainActor
final class OverlayCoordinator {

    // MARK: - State

    /// Retains overlay windows for the duration of the selection to prevent ARC deallocation.
    private var overlayWindows: [(NSWindow, SelectionOverlayView)] = []

    // MARK: - Public API

    /// Presents full-screen crosshair-selection overlays on every connected display,
    /// waits for the user to drag a selection or cancel, then returns the result.
    ///
    /// - Returns: The selected region in global screen coordinates (origin at
    ///   bottom-left of the primary display), or `nil` if the user cancelled.
    func beginRegionSelection() async -> CGRect? {
        let windows = createOverlayWindows()
        overlayWindows = windows

        // Push crosshair cursor before showing windows
        NSCursor.crosshair.push()

        // Order all overlay windows to the front
        for (window, _) in windows {
            window.orderFrontRegardless()
        }

        // Make the window under the current cursor the key window so it receives
        // keyboard events (Escape) immediately
        let mouseLocation = NSEvent.mouseLocation
        if let (keyWindow, _) = windows.first(where: { (window, _) in
            window.frame.contains(mouseLocation)
        }) {
            keyWindow.makeKey()
        }

        // Bridge the callback-based result to async/await.
        // Only the first view to call the callback wins (guards against double-resume).
        let result: CGRect? = await withCheckedContinuation { continuation in
            var resumed = false

            for (_, view) in windows {
                view.onSelectionComplete = { [weak self] rect in
                    guard let self else { return }
                    guard !resumed else { return }
                    resumed = true

                    // Tear-down must happen on the main actor (already here since
                    // mouse events arrive on the main thread and this closure is
                    // called synchronously from mouseDown).
                    self.tearDown()
                    continuation.resume(returning: rect)
                }
            }
        }

        return result
    }

    // MARK: - Window creation

    private func createOverlayWindows() -> [(NSWindow, SelectionOverlayView)] {
        NSScreen.screens.map { screen in
            // Create an NSWindow that covers the entire screen
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            // Visual configuration
            window.level = .screenSaver
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = true

            // Allow overlay to appear over fullscreen spaces
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            // Exclude this window from ScreenCaptureKit capture (macOS 13/14).
            // On macOS 15 the SCContentFilter handles exclusion on the capture side.
            window.sharingType = .none

            // Create the overlay view covering the whole screen
            let view = SelectionOverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.owningScreen = screen
            window.contentView = view

            // The view needs to be first responder so it receives key events (Escape)
            window.makeFirstResponder(view)

            return (window, view)
        }
    }

    // MARK: - Tear-down

    private func tearDown() {
        NSCursor.pop()

        for (window, _) in overlayWindows {
            window.orderOut(nil)
            window.close()
        }

        overlayWindows = []
    }
}
