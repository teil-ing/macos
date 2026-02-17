import AppKit
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

    // MARK: - Capture Services
    private let captureEngine = CaptureEngine()
    private let overlayCoordinator = OverlayCoordinator()

    /// The most recent successful capture result — consumed by the upload pipeline in a later phase.
    private var lastCaptureResult: CaptureResult?

    /// Error message to surface inside the popover after a capture failure.
    private var captureError: String?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders alongside LSUIElement: prevent any Dock icon flash
        NSApp.setActivationPolicy(.accessory)

        if KeychainService.shared.apiKey != nil {
            // Returning user — API key already in Keychain
            showWelcomeBackAndProceed()
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

    private func showWelcomeBackAndProceed() {
        // Switch to .regular temporarily so the welcome window can show
        NSApp.setActivationPolicy(.regular)

        let welcomeWindow = makeWelcomeBackWindow()
        welcomeWindow.center()
        welcomeWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            welcomeWindow.close()
            NSApp.setActivationPolicy(.accessory)
            self.completeLaunch()
        }
    }

    private func makeWelcomeBackWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "teil.ing"
        window.isReleasedWhenClosed = false

        let welcomeView = WelcomeBackView()
        let hostingController = NSHostingController(rootView: welcomeView)
        window.contentViewController = hostingController

        return window
    }

    // MARK: - Launch Completion

    private func completeLaunch() {
        setupStatusItem()
        setupPopover()
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

    // MARK: - Popover Setup

    private func setupPopover() {
        let rootView = PopoverRootView(
            onRegionCapture: { [weak self] in self?.startRegionCapture() },
            onFullscreenCapture: { [weak self] in self?.startFullscreenCapture() },
            captureError: captureError
        )
        let hostingController = NSHostingController(rootView: rootView)
        // preferredContentSize: enables content-adaptive height — popover grows/shrinks with content
        hostingController.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
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
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // makeKey() is REQUIRED for .transient dismiss to work on first open —
        // without this the popover does not receive events on first show.
        popover.contentViewController?.view.window?.makeKey()
        // Ensure popover receives events properly
        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    // MARK: - Capture Flow: Region

    private func startRegionCapture() {
        closePopover()

        Task { @MainActor in
            // Let the popover fully dismiss before showing the overlay
            try? await Task.sleep(for: .milliseconds(200))

            guard let selectedRect = await overlayCoordinator.beginRegionSelection() else {
                // User cancelled — no capture, no feedback
                return
            }

            // Give the compositor one frame to clear overlay windows before capturing
            try? await Task.sleep(for: .milliseconds(50))

            do {
                let result = try await captureEngine.captureRegion(selectedRect)
                lastCaptureResult = result

                await CaptureFeedback.showCaptureFlash(in: selectedRect)
                CaptureFeedback.playCaptureSound()
                CaptureFeedback.showSuccessIcon(on: statusItem)
            } catch {
                showCaptureError(error.localizedDescription)
            }
        }
    }

    // MARK: - Capture Flow: Fullscreen

    private func startFullscreenCapture() {
        closePopover()

        Task { @MainActor in
            // Let the popover fully dismiss before capturing
            try? await Task.sleep(for: .milliseconds(200))

            do {
                let result = try await captureEngine.captureFullscreen()
                lastCaptureResult = result

                await CaptureFeedback.showCaptureFlash(in: result.capturedRect)
                CaptureFeedback.playCaptureSound()
                CaptureFeedback.showSuccessIcon(on: statusItem)
            } catch {
                showCaptureError(error.localizedDescription)
            }
        }
    }

    // MARK: - Error Display

    /// Reopens the popover with an inline error banner.
    ///
    /// Error is shown inside the popover per locked decision:
    /// capture errors must not appear as system notifications.
    private func showCaptureError(_ message: String) {
        captureError = message

        // Rebuild the popover content with the error message included,
        // then open it so the user sees the error inside the popover.
        let rootView = PopoverRootView(
            onRegionCapture: { [weak self] in self?.startRegionCapture() },
            onFullscreenCapture: { [weak self] in self?.startFullscreenCapture() },
            captureError: message
        )
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController

        showPopover()
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

// MARK: - WelcomeBackView

private struct WelcomeBackView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)

            Text("Welcome back!")
                .font(.headline)

            Text("API key found — launching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 300, height: 120)
        .padding()
    }
}
