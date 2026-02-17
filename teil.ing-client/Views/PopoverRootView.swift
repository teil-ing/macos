import SwiftUI

struct PopoverRootView: View {
    var onRegionCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?
    var onWindowCapture: (() -> Void)?

    /// Non-nil when a capture error has occurred and needs to be shown inside the popover.
    var captureError: String?

    /// Non-nil when the most recent upload failed after all retries.
    var uploadError: String?

    /// Called when the user taps "Retry Upload". Non-nil when a retry action is available.
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            if let uploadError = uploadError {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(uploadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                        Spacer()
                    }
                    if onRetry != nil {
                        Button {
                            onRetry?()
                        } label: {
                            Text("Retry Upload")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08))

                Divider()
            }

            if let error = captureError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))

                Divider()
            }

            CaptureSection(
                onRegionCapture: onRegionCapture,
                onFullscreenCapture: onFullscreenCapture,
                onWindowCapture: onWindowCapture
            )
            Divider()
            HistorySection()
            Divider()
            PopoverFooterView()
        }
        .frame(width: 280)
    }
}

#Preview {
    PopoverRootView()
}

#Preview("Upload Error") {
    PopoverRootView(uploadError: "API key is invalid or expired.", onRetry: {})
}
