import SwiftUI

struct CaptureSection: View {
    var onRegionCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            CaptureModeButton(
                label: "Region",
                systemImage: "crop",
                disabled: false,
                action: { onRegionCapture?() }
            )
            CaptureModeButton(
                label: "Fullscreen",
                systemImage: "display",
                disabled: false,
                action: { onFullscreenCapture?() }
            )
            CaptureModeButton(
                label: "Window",
                systemImage: "macwindow",
                disabled: true,
                action: {}
            )
        }
        .padding(.bottom, 4)
    }
}

private struct CaptureModeButton: View {
    let label: String
    let systemImage: String
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isHovered && !disabled ? Color(nsColor: .controlAccentColor).opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    CaptureSection()
        .frame(width: 280)
}
