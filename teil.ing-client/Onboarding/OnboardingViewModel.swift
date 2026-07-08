import Foundation
import SwiftUI

// MARK: - OnboardingPhase

enum OnboardingPhase {
    case signIn
    case screenRecording
    case complete
}

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published State

    /// Fallback for users who prefer to paste a dashboard-created key.
    @Published var useManualKey: Bool = false
    @Published var apiKey: String = ""
    @Published var isRevealed: Bool = false
    @Published var isValidating: Bool = false
    /// True while the browser handshake is in flight (waiting for the
    /// teiling:// callback and the key exchange).
    @Published var isWaitingForBrowser: Bool = false
    @Published var errorMessage: String? = nil
    @Published var shakeAttempts: Int = 0
    @Published var phase: OnboardingPhase = .signIn

    // MARK: - Callbacks

    var onComplete: (() -> Void)?

    // MARK: - Sign In (browser connect flow → provisioned API key)

    func signInWithBrowser() async {
        errorMessage = nil
        isWaitingForBrowser = true
        defer { isWaitingForBrowser = false }

        do {
            let key = try await AuthService.shared.signInViaBrowser()
            try KeychainService.shared.save(key)
            phase = .screenRecording
        } catch AuthError.cancelled {
            // User backed out — not an error worth a banner.
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
            withAnimation(.default) {
                shakeAttempts += 1
            }
        } catch {
            errorMessage = "Could not save your credentials: \(error.localizedDescription)"
        }
    }

    func cancelBrowserSignIn() {
        AuthService.shared.cancel()
    }

    // MARK: - Manual API Key Fallback

    func validateAndSave() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter your API key."
            withAnimation(.default) {
                shakeAttempts += 1
            }
            return
        }

        isValidating = true
        errorMessage = nil
        defer { isValidating = false }

        let result = await APIValidationService.validate(apiKey: trimmedKey)

        switch result {
        case .valid:
            do {
                try KeychainService.shared.save(trimmedKey)
                phase = .screenRecording
            } catch {
                errorMessage = "Could not save API key to Keychain: \(error.localizedDescription)"
            }

        case .invalidKey:
            errorMessage = "Invalid API key. Please check and try again."
            withAnimation(.default) {
                shakeAttempts += 1
            }

        case .networkError(let message):
            errorMessage = message

        case .serverError(let code):
            errorMessage = "Unexpected server response (\(code)). Try again later."
            withAnimation(.default) {
                shakeAttempts += 1
            }
        }
    }

    func toggleManualKey() {
        // Entering (or leaving) manual mode abandons any waiting browser flow.
        AuthService.shared.cancel()
        useManualKey.toggle()
        errorMessage = nil
    }

    // MARK: - Screen Recording Permission

    func checkPermission() async {
        let granted = await PermissionService.checkScreenRecordingPermission()
        if granted {
            phase = .complete
            onComplete?()
        }
        // If false: the user needs to grant permission in System Settings
        // and tap the "I've granted permission" button to re-check.
    }

    func openSettings() {
        PermissionService.openScreenRecordingSettings()
    }

    func retryPermissionCheck() async {
        await checkPermission()
    }
}
