import AppKit
import SwiftUI

// MARK: - OnboardingWindowController

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {

    // MARK: - Properties

    var onComplete: (() -> Void)?

    // MARK: - Init

    init() {
        // 1. Create the ViewModel so we can wire its onComplete before creating the view
        let viewModel = OnboardingViewModel()

        // 2. Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "teil.ing"
        // CRITICAL: prevents premature deallocation when the window closes
        window.isReleasedWhenClosed = false

        // 3. Create hosting controller with the view
        let hostingController = NSHostingController(rootView: OnboardingView(onComplete: {}))
        window.contentViewController = hostingController

        super.init(window: window)

        // 4. Set delegate for windowShouldClose
        window.delegate = self

        // 5. Wire onComplete through the ViewModel after super.init
        // We use a capture of self to forward the callback
        viewModel.onComplete = { [weak self] in
            self?.onComplete?()
        }

        // 6. Replace the hosting controller content with the properly wired view
        let wiredView = OnboardingView(onComplete: { [weak self] in
            self?.onComplete?()
        })
        hostingController.rootView = wiredView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Per locked decision: closing the onboarding window X button quits the app
        NSApp.terminate(nil)
        return false
    }
}
