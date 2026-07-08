import SwiftUI
import AppKit

// MARK: - ShakeEffect

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: Int = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * CGFloat(shakes)),
                y: 0
            )
        )
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {

    @StateObject private var viewModel = OnboardingViewModel()

    private let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Top section (always visible)
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                Text("Welcome to teil.ing")
                    .font(.title)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)

            Spacer().frame(height: 30)

            // MARK: Phase-dependent section
            switch viewModel.phase {
            case .signIn:
                if viewModel.useManualKey {
                    apiKeySection
                } else {
                    signInSection
                }

            case .screenRecording:
                screenRecordingSection
                    .onAppear {
                        Task {
                            await viewModel.checkPermission()
                        }
                    }

            case .complete:
                EmptyView()
            }

            Spacer()
        }
        .frame(minWidth: 480, maxWidth: 480, minHeight: 480)
        .onAppear {
            viewModel.onComplete = onComplete
        }
    }

    private var subtitle: String {
        switch viewModel.phase {
        case .signIn:
            return viewModel.useManualKey
                ? "Enter your API key to get started"
                : "Sign in with your teil.ing account to get started"
        case .screenRecording, .complete:
            return "One more step"
        }
    }

    // MARK: - Sign In Section

    private var signInSection: some View {
        VStack(spacing: 12) {
            if viewModel.isWaitingForBrowser {
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)

                    Text("Finish signing in to teil.ing in your browser, then approve this Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Cancel") {
                        viewModel.cancelBrowserSignIn()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 40)
            } else {
                Button {
                    Task { await viewModel.signInWithBrowser() }
                } label: {
                    Text("Sign in with teil.ing")
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .modifier(ShakeEffect(animatableData: CGFloat(viewModel.shakeAttempts)))

                Text("Your browser will open — sign in with your email, GitHub, or Google account and approve this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Prefer an API key? Enter one manually") {
                viewModel.toggleManualKey()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - API Key Section (manual fallback)

    private var apiKeySection: some View {
        VStack(spacing: 12) {
            // Field row with reveal toggle and spinner
            HStack(spacing: 8) {
                Group {
                    if viewModel.isRevealed {
                        TextField("Paste your API key", text: $viewModel.apiKey)
                            .focused($isFieldFocused)
                    } else {
                        SecureField("Paste your API key", text: $viewModel.apiKey)
                            .focused($isFieldFocused)
                    }
                }
                .textFieldStyle(.roundedBorder)

                Button {
                    viewModel.isRevealed.toggle()
                } label: {
                    Image(systemName: viewModel.isRevealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if viewModel.isValidating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            }
            .modifier(ShakeEffect(animatableData: CGFloat(viewModel.shakeAttempts)))
            .padding(.horizontal, 40)

            // Hint text
            Text("Create a key at teil.ing/dashboard/api-keys")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Continue button
            Button("Continue") {
                Task {
                    await viewModel.validateAndSave()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                viewModel.apiKey.trimmingCharacters(in: .whitespaces).isEmpty ||
                viewModel.isValidating
            )
            .padding(.top, 4)

            Button("Back to sign in") {
                viewModel.toggleManualKey()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Screen Recording Section

    private var screenRecordingSection: some View {
        VStack(spacing: 16) {
            Text("teil.ing needs Screen Recording permission to capture screenshots. This allows the app to take screenshots of your screen when you trigger a capture.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open System Settings") {
                viewModel.openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("I've granted permission — continue") {
                Task {
                    await viewModel.retryPermissionCheck()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.horizontal, 40)
    }
}
