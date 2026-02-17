import Foundation
import SwiftUI

// MARK: - OnboardingPhase

enum OnboardingPhase {
    case apiKey
    case screenRecording
    case complete
}

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var apiKey: String = ""
    @Published var isRevealed: Bool = false
    @Published var isValidating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var shakeAttempts: Int = 0
    @Published var phase: OnboardingPhase = .apiKey

    // MARK: - Callbacks

    var onComplete: (() -> Void)?

    // MARK: - API Key Validation

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
