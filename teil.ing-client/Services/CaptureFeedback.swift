import AppKit
import AudioToolbox
import QuartzCore

// MARK: - CaptureFeedback

/// Caseless enum namespace for post-capture feedback: flash window, system sound,
/// and temporary menu bar icon success state.
///
/// All methods manipulate NSWindow and NSStatusItem, which must run on the main actor.
@MainActor
enum CaptureFeedback {

    /// Task handle for the pending icon revert — cancelled when a new capture starts
    /// so rapid successive captures don't leave stale revert timers.
    private static var iconRevertTask: Task<Void, Never>?

    // MARK: - Flash Window

    /// Displays a brief white flash over the captured area to confirm the capture.
    ///
    /// The flash window appears AFTER the capture is complete — it is purely cosmetic
    /// and does not interfere with the captured image.
    ///
    /// This method is async and awaitable so the caller can sequence it before
    /// playing the sound (though the flash animation runs concurrently with sound).
    ///
    /// - Parameter rect: The captured area in global AppKit screen coordinates.
    static func showCaptureFlash(in rect: CGRect) async {
        // Find the screen that contains the majority of the captured rect
        let targetScreen = NSScreen.screens.max(by: { a, b in
            a.frame.intersection(rect).area < b.frame.intersection(rect).area
        })

        // Position the flash window at the captured rect in screen coordinates.
        // NSWindow uses AppKit coordinates (origin at bottom-left, Y upward) which
        // matches the global coordinate space used by CaptureResult.capturedRect.
        let flashWindow = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: targetScreen
        )

        flashWindow.level = .screenSaver
        flashWindow.backgroundColor = .white
        flashWindow.isOpaque = true
        flashWindow.alphaValue = 0.8
        flashWindow.isReleasedWhenClosed = false
        flashWindow.hasShadow = false

        // Exclude the flash from being captured by ScreenCaptureKit on a rapid
        // second capture (belt-and-suspenders — flash appears post-capture anyway).
        flashWindow.sharingType = .none

        flashWindow.orderFront(nil)

        // Await the fade animation so the caller knows when the flash is done.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup(
                { ctx in
                    ctx.duration = 0.15
                    flashWindow.animator().alphaValue = 0.0
                },
                completionHandler: {
                    flashWindow.orderOut(nil)
                    continuation.resume()
                }
            )
        }
    }

    // MARK: - Sound

    /// Plays a camera-shutter system sound to confirm the capture.
    ///
    /// Uses NSSound for reliability across macOS versions.
    /// "Tink" is a short, pleasant confirmation sound available on all supported macOS versions.
    static func playCaptureSound() {
        NSSound(named: "Tink")?.play()
    }

    // MARK: - Menu Bar Icon Success State

    /// Temporarily changes the menu bar icon to a checkmark to confirm the capture,
    /// then reverts to the normal icon after ~2 seconds.
    ///
    /// Cancels any pending revert from a prior rapid capture before starting the new one.
    ///
    /// - Parameter statusItem: The NSStatusItem whose button image will be updated.
    static func showSuccessIcon(on statusItem: NSStatusItem) {
        // Cancel any previous revert task — a new capture supersedes the old one
        iconRevertTask?.cancel()
        iconRevertTask = nil

        let successImage = NSImage(
            systemSymbolName: "checkmark.circle.fill",
            accessibilityDescription: "Capture successful"
        )
        successImage?.isTemplate = true
        statusItem.button?.image = successImage

        // Schedule revert after 2 seconds
        iconRevertTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            restoreNormalIcon(on: statusItem)
            iconRevertTask = nil
        }
    }

    // MARK: - Upload Spinner and Error Icon

    /// Starts an animated rotation spinner on the menu bar icon to indicate an ongoing upload.
    ///
    /// Cancels any pending icon revert task — the spinner supersedes a pending success revert.
    /// Uses CABasicAnimation for smooth infinite rotation without polling.
    ///
    /// - Parameter statusItem: The NSStatusItem whose button will be animated.
    static func showUploadSpinner(on statusItem: NSStatusItem) {
        // Cancel any pending revert task — spinner supersedes it
        iconRevertTask?.cancel()
        iconRevertTask = nil

        guard let button = statusItem.button else { return }

        let spinnerImage = NSImage(
            systemSymbolName: "arrow.triangle.2.circlepath",
            accessibilityDescription: "Uploading"
        )
        spinnerImage?.isTemplate = true
        button.image = spinnerImage

        // CABasicAnimation requires the view to have a backing layer
        button.wantsLayer = true

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = 1.0
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        rotation.repeatCount = .infinity

        button.layer?.add(rotation, forKey: "uploadSpinner")
    }

    /// Stops the upload spinner animation, leaving the current icon image unchanged.
    ///
    /// The caller is responsible for setting the next icon state (success checkmark,
    /// error icon, or normal icon) after calling this method.
    ///
    /// - Parameter statusItem: The NSStatusItem whose spinner animation will be removed.
    static func stopUploadSpinner(on statusItem: NSStatusItem) {
        statusItem.button?.layer?.removeAnimation(forKey: "uploadSpinner")
    }

    /// Shows a persistent error icon on the menu bar to indicate an upload failure.
    ///
    /// The error icon does NOT auto-revert — it stays until AppDelegate explicitly
    /// calls `restoreNormalIcon` (e.g., when the user opens the popover or a retry succeeds).
    ///
    /// - Parameter statusItem: The NSStatusItem whose button image will be updated.
    static func showErrorIcon(on statusItem: NSStatusItem) {
        // Stop any running spinner first (belt-and-suspenders)
        stopUploadSpinner(on: statusItem)

        // Cancel any pending revert task
        iconRevertTask?.cancel()
        iconRevertTask = nil

        let errorImage = NSImage(
            systemSymbolName: "exclamationmark.triangle.fill",
            accessibilityDescription: "Upload failed"
        )
        errorImage?.isTemplate = true
        statusItem.button?.image = errorImage
        // No auto-revert — the error icon stays until AppDelegate calls restoreNormalIcon
    }

    // MARK: - Icon Helpers

    /// Restores the menu bar icon to the normal (non-error, non-success) state.
    ///
    /// Internal so AppDelegate (Plan 03) can call this when the user dismisses
    /// an upload error or a retry succeeds, clearing the persistent error icon.
    static func restoreNormalIcon(on statusItem: NSStatusItem) {
        let normalImage = NSImage(
            systemSymbolName: "rectangle.dashed",
            accessibilityDescription: "teil.ing"
        )
        normalImage?.isTemplate = true
        statusItem.button?.image = normalImage
    }
}

// MARK: - CGRect area helper

private extension CGRect {
    var area: CGFloat { width * height }
}
