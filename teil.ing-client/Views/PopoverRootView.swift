import SwiftUI

struct PopoverRootView: View {
    var onRegionCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?
    var onWindowCapture: (() -> Void)?

    /// Non-nil when a capture error has occurred and needs to be shown inside the popover.
    var captureError: String?

    var body: some View {
        VStack(spacing: 0) {
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
