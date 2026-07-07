import AppKit
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Stored Properties
    // NSStatusItem MUST be a stored property on AppDelegate — never a local variable
    // or SwiftUI @State. ARC would deallocate a local, silently removing the menu bar icon.
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var eventMonitor: Any?
    private var onboardingWindowController: OnboardingWindowController?
    private let hotkeyMonitor = HotkeyMonitor()

    // MARK: - Persistence
    private var modelContainer: ModelContainer!
    private var historyStore: HistoryStore!

    // MARK: - Update Service
    private let updateService = UpdateService.shared

    // MARK: - Capture Services
    private let captureEngine = CaptureEngine()
    private let overlayCoordinator = OverlayCoordinator()
    private let windowSelectionCoordinator = WindowSelectionCoordinator()

    /// Error message to surface inside the popover after a capture failure.
    private var captureError: String?

    /// Error message from the most recent failed upload — shown in popover error banner.
    private var uploadError: String?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders alongside LSUIElement: prevent any Dock icon flash
        NSApp.setActivationPolicy(.accessory)

        if KeychainService.shared.apiKey != nil {
            // Returning user — API key already in Keychain, launch directly
            completeLaunch()
        } else {
            // First launch — no key found
            showOnboardingWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopEventMonitor()
    }

    // MARK: - Onboarding Gate

    private func showOnboardingWindow() {
        // Switch to .regular so the onboarding window can become key
        // (per research pitfall: accessory-mode apps can't show key windows)
        NSApp.setActivationPolicy(.regular)

        let controller = OnboardingWindowController()
        controller.onComplete = { [weak self] in
            self?.onboardingWindowController = nil
            NSApp.setActivationPolicy(.accessory)
            self?.completeLaunch()
        }

        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        onboardingWindowController = controller
    }

    // MARK: - Launch Completion

    private func completeLaunch() {
        // Initialize SwiftData ModelContainer and HistoryStore before other setup.
        // Fatal error is appropriate here — if SwiftData cannot create its store,
        // the app cannot function correctly.
        do {
            modelContainer = try ModelContainer(for: HistoryEntry.self)
            historyStore = HistoryStore(container: modelContainer)
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error)")
        }

        // Sync launch-at-login state — ensures SMAppService matches stored preference
        // (handles cases where user toggled it in System Settings > Login Items)
        if PreferencesStore.shared.launchAtLogin {
            LaunchAtLoginService.shared.setEnabled(true)
        }

        setupStatusItem()
        setupPopover()
        // setupHotkeyMonitor MUST come after setupStatusItem/setupPopover —
        // the hotkey handlers reference statusItem, overlayCoordinator,
        // windowSelectionCoordinator, and captureEngine (research Pitfall 7).
        setupHotkeyMonitor()

        // Start auto-update check if enabled
        if PreferencesStore.shared.autoCheckForUpdates {
            updateService.startPeriodicCheck()
            Task { await updateService.checkForUpdates() }
        }
    }

    // MARK: - Status Item Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "teil.ing")
        // isTemplate = true enables automatic dark/light mode adaptation (SHELL-03)
        image?.isTemplate = true
        button.image = image
        button.action = #selector(togglePopover)
        button.target = self
    }

    // MARK: - Hotkey Monitor Setup

    private func setupHotkeyMonitor() {
        hotkeyMonitor.start(
            onRegion: { [weak self] in
                Task { @MainActor [weak self] in
                    // 200ms delay — lets user lift fingers off keys before overlay appears
                    try? await Task.sleep(for: .milliseconds(200))
                    self?.startRegionCapture(fromHotkey: true)
                }
            },
            onFullscreen: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(200))
                    self?.startFullscreenCapture(fromHotkey: true)
                }
            },
            onWindow: { [weak self] in
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(200))
                    self?.startWindowCapture(fromHotkey: true)
                }
            }
        )
    }

    // MARK: - Popover Setup

    private func setupPopover() {
        let rootView = PopoverRootView(
            onRegionCapture: { [weak self] in self?.startRegionCapture() },
            onFullscreenCapture: { [weak self] in self?.startFullscreenCapture() },
            onWindowCapture: { [weak self] in self?.startWindowCapture() },
            captureError: captureError,
            uploadError: uploadError,
            onRetry: { [weak self] in self?.retryUpload() },
            historyStore: historyStore
        )
        let hostingController = NSHostingController(rootView: rootView)
        // preferredContentSize: enables content-adaptive height — popover grows/shrinks with content
        hostingController.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = hostingController
    }

    // MARK: - Popover Content Rebuild

    /// Rebuilds the popover content view with the current error state.
    ///
    /// Called before showing the popover and whenever error state changes,
    /// ensuring the popover always reflects current captureError and uploadError.
    private func rebuildPopoverContent() {
        let rootView = PopoverRootView(
            onRegionCapture: { [weak self] in self?.startRegionCapture() },
            onFullscreenCapture: { [weak self] in self?.startFullscreenCapture() },
            onWindowCapture: { [weak self] in self?.startWindowCapture() },
            captureError: captureError,
            uploadError: uploadError,
            onRetry: { [weak self] in self?.retryUpload() },
            historyStore: historyStore
        )
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    // MARK: - Toggle

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        // Always rebuild before showing so the popover reflects current error state
        rebuildPopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // makeKey() is REQUIRED for .transient dismiss to work on first open —
        // without this the popover does not receive events on first show.
        popover.contentViewController?.view.window?.makeKey()
        // Ensure popover receives events properly
        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()

        // Refresh the recent-upload list every time the menu opens so it reflects the
        // latest server state (new uploads, edits, or deletions made elsewhere).
        Task { await historyStore.refreshAll() }

        // Acknowledge error icon by restoring normal icon when popover opens
        if uploadError != nil {
            CaptureFeedback.restoreNormalIcon(on: statusItem)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    // MARK: - Upload Feedback Handler

    /// Handles UploadFeedbackEvent callbacks from UploadService.
    ///
    /// Drives the menu bar icon state machine: spinner during upload,
    /// checkmark + sound on success, error icon on failure.
    private func handleUploadFeedback(_ event: UploadFeedbackEvent) {
        switch event {
        case .uploadStarted:
            // Clear any previous error when a new upload starts
            uploadError = nil
            CaptureFeedback.showUploadSpinner(on: statusItem)

        case .uploadSucceeded(let imageId, let shareUrl, let capture):
            _ = shareUrl  // clipboard/browser handled by UploadService internally
            CaptureFeedback.stopUploadSpinner(on: statusItem)
            CaptureFeedback.playCaptureSound()
            CaptureFeedback.showSuccessIcon(on: statusItem)
            // Upload succeeded — clear error state
            uploadError = nil
            // Write history entry — thumbnail generation is synchronous on main actor
            // (CGImage resize at 64px is negligibly fast; no background dispatch needed)
            if let thumbnailPath = try? ThumbnailService.saveThumbnail(from: capture.image, id: UUID()) {
                historyStore.addEntry(
                    imageId: imageId,
                    shareURL: shareUrl,
                    thumbnailPath: thumbnailPath,
                    timestamp: capture.timestamp
                )
            }
            // Refresh the remote image list so the newly uploaded screenshot appears at the
            // top of the history immediately. The history list prefers remote images over local
            // entries, so adding a local entry alone would not surface the new upload.
            Task { await historyStore.refreshAll() }

        case .uploadFailed(let error):
            CaptureFeedback.stopUploadSpinner(on: statusItem)
            CaptureFeedback.showErrorIcon(on: statusItem)
            uploadError = error.localizedDescription
            // Show the popover with the error banner
            showUploadError(error.localizedDescription)
        }
    }

    // MARK: - Error Display

    /// Reopens the popover with an upload error banner.
    private func showUploadError(_ message: String) {
        uploadError = message
        rebuildPopoverContent()
        showPopover()
    }

    /// Reopens the popover with a capture error banner.
    ///
    /// Error is shown inside the popover per locked decision:
    /// capture errors must not appear as system notifications.
    private func showCaptureError(_ message: String) {
        captureError = message
        rebuildPopoverContent()
        showPopover()
    }

    // MARK: - Screen Recording Permission Alert

    /// Shows a modal NSAlert when Screen Recording permission is denied or revoked.
    ///
    /// Per locked decision: modal NSAlert (not inline in popover) with "Open Settings" button
    /// that calls PermissionService.openScreenRecordingSettings().
    private func presentScreenRecordingDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "teil.ing needs Screen Recording permission to capture screenshots.\n\nOpen System Settings > Privacy & Security > Screen Recording and enable teil.ing."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Not Now")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            PermissionService.openScreenRecordingSettings()
        }
    }

    // MARK: - Retry Upload

    /// Re-enqueues the last failed upload into UploadService.
    ///
    /// Passes current preference values at retry time so any changes made
    /// between failure and retry are honoured.
    private func retryUpload() {
        Task {
            await UploadService.shared.retry(
                stripExif: PreferencesStore.shared.stripExif,
                privateUpload: PreferencesStore.shared.privateUpload,
                openInBrowser: PreferencesStore.shared.openInBrowser,
                clipboardCopy: PreferencesStore.shared.clipboardCopy,
                clipboardMode: PreferencesStore.shared.clipboardMode.rawValue,
                onFeedback: { [weak self] event in
                    self?.handleUploadFeedback(event)
                }
            )
        }
    }

    // MARK: - Capture Flow: Region

    private func startRegionCapture(fromHotkey: Bool = false) {
        // When triggered from menu bar, close the popover first.
        // When triggered from hotkey, the 200ms delay is already applied in setupHotkeyMonitor.
        if !fromHotkey {
            closePopover()
        }

        Task { @MainActor in
            if !fromHotkey {
                // Let the popover fully dismiss before showing the overlay
                try? await Task.sleep(for: .milliseconds(200))
            }

            // Check screen recording permission before attempting capture
            let hasPermission = await PermissionService.checkScreenRecordingPermission()
            if !hasPermission {
                presentScreenRecordingDeniedAlert()
                return
            }

            guard let selectedRect = await overlayCoordinator.beginRegionSelection() else {
                // User cancelled — no capture, no feedback
                return
            }

            // Give the compositor one frame to clear overlay windows before capturing
            try? await Task.sleep(for: .milliseconds(50))

            do {
                let result = try await captureEngine.captureRegion(selectedRect)

                // Flash fires at capture time (no sound — sound plays on upload success)
                await CaptureFeedback.showCaptureFlash(in: selectedRect)

                // Enqueue for upload — sound/checkmark/browser happen on upload success
                Task {
                    await UploadService.shared.enqueue(
                        result,
                        stripExif: PreferencesStore.shared.stripExif,
                        privateUpload: PreferencesStore.shared.privateUpload,
                        openInBrowser: PreferencesStore.shared.openInBrowser,
                        clipboardCopy: PreferencesStore.shared.clipboardCopy,
                        clipboardMode: PreferencesStore.shared.clipboardMode.rawValue,
                        onFeedback: { [weak self] event in
                            self?.handleUploadFeedback(event)
                        }
                    )
                }
            } catch {
                showCaptureError(error.localizedDescription)
            }
        }
    }

    // MARK: - Capture Flow: Fullscreen

    private func startFullscreenCapture(fromHotkey: Bool = false) {
        if !fromHotkey {
            closePopover()
        }

        Task { @MainActor in
            if !fromHotkey {
                // Let the popover fully dismiss before capturing
                try? await Task.sleep(for: .milliseconds(200))
            }

            // Check screen recording permission before attempting capture
            let hasPermission = await PermissionService.checkScreenRecordingPermission()
            if !hasPermission {
                presentScreenRecordingDeniedAlert()
                return
            }

            do {
                let result = try await captureEngine.captureFullscreen()

                // Flash fires at capture time (no sound — sound plays on upload success)
                await CaptureFeedback.showCaptureFlash(in: result.capturedRect)

                // Enqueue for upload — sound/checkmark/browser happen on upload success
                Task {
                    await UploadService.shared.enqueue(
                        result,
                        stripExif: PreferencesStore.shared.stripExif,
                        privateUpload: PreferencesStore.shared.privateUpload,
                        openInBrowser: PreferencesStore.shared.openInBrowser,
                        clipboardCopy: PreferencesStore.shared.clipboardCopy,
                        clipboardMode: PreferencesStore.shared.clipboardMode.rawValue,
                        onFeedback: { [weak self] event in
                            self?.handleUploadFeedback(event)
                        }
                    )
                }
            } catch {
                showCaptureError(error.localizedDescription)
            }
        }
    }

    // MARK: - Capture Flow: Window

    private func startWindowCapture(fromHotkey: Bool = false) {
        if !fromHotkey {
            closePopover()
        }

        Task { @MainActor in
            if !fromHotkey {
                // Same 200ms delay as other capture modes — lets popover fully dismiss
                try? await Task.sleep(for: .milliseconds(200))
            }

            // Check screen recording permission before attempting capture
            let hasPermission = await PermissionService.checkScreenRecordingPermission()
            if !hasPermission {
                presentScreenRecordingDeniedAlert()
                return
            }

            guard let selection = await windowSelectionCoordinator.beginWindowSelection() else {
                // User cancelled (Escape) — no capture, no feedback
                return
            }

            // Give compositor one frame to clear overlay windows before capturing
            try? await Task.sleep(for: .milliseconds(50))

            switch selection {
            case .window(let scWindow):
                do {
                    // Extract Sendable value (CGRect) before crossing actor boundary
                    let windowFrame = scWindow.frame
                    // Wrap non-Sendable SCWindow in nonisolated(unsafe) to transfer across actor boundary.
                    // The value is fully constructed here and not mutated after transfer.
                    nonisolated(unsafe) let windowToCapture = scWindow
                    let result = try await captureEngine.captureWindow(windowToCapture)

                    // Convert CG frame to AppKit coordinates for flash feedback positioning
                    let appKitRect = windowSelectionCoordinator.cgFrameToAppKit(windowFrame)

                    // Flash fires at capture time (no sound — sound plays on upload success)
                    await CaptureFeedback.showCaptureFlash(in: appKitRect)

                    // Enqueue for upload — sound/checkmark/browser happen on upload success
                    Task {
                        await UploadService.shared.enqueue(
                            result,
                            stripExif: PreferencesStore.shared.stripExif,
                            privateUpload: PreferencesStore.shared.privateUpload,
                            openInBrowser: PreferencesStore.shared.openInBrowser,
                            clipboardCopy: PreferencesStore.shared.clipboardCopy,
                            clipboardMode: PreferencesStore.shared.clipboardMode.rawValue,
                            onFeedback: { [weak self] event in
                                self?.handleUploadFeedback(event)
                            }
                        )
                    }
                } catch {
                    showCaptureError(error.localizedDescription)
                }

            case .desktop:
                // Per locked decision: clicking desktop = fullscreen capture of the current display
                do {
                    let result = try await captureEngine.captureFullscreen()

                    // Flash fires at capture time (no sound — sound plays on upload success)
                    await CaptureFeedback.showCaptureFlash(in: result.capturedRect)

                    // Enqueue for upload — sound/checkmark/browser happen on upload success
                    Task {
                        await UploadService.shared.enqueue(
                            result,
                            stripExif: PreferencesStore.shared.stripExif,
                            privateUpload: PreferencesStore.shared.privateUpload,
                            openInBrowser: PreferencesStore.shared.openInBrowser,
                            clipboardCopy: PreferencesStore.shared.clipboardCopy,
                            clipboardMode: PreferencesStore.shared.clipboardMode.rawValue,
                            onFeedback: { [weak self] event in
                                self?.handleUploadFeedback(event)
                            }
                        )
                    }
                } catch {
                    showCaptureError(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Event Monitor

    private func startEventMonitor() {
        // Guard against double-registration
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            // Swift 6 concurrency: wrap the MainActor-isolated call in a Task
            Task { @MainActor [weak self] in
                guard let self, self.popover.isShown else { return }
                self.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
