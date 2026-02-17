import SwiftUI

struct CaptureSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Capture")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            CaptureModeButton(label: "Region", systemImage: "rectangle.dashed")
            CaptureModeButton(label: "Fullscreen", systemImage: "rectangle.inset.filled")
            CaptureModeButton(label: "Window", systemImage: "macwindow")
        }
        .padding(.bottom, 4)
    }
}

private struct CaptureModeButton: View {
    let label: String
    let systemImage: String

    @State private var isHovered = false

    var body: some View {
        Button {
            // Enabled in Phase 3/4
        } label: {
            Label(label, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(isHovered ? Color(nsColor: .controlAccentColor).opacity(0.15) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(true)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    CaptureSection()
        .frame(width: 280)
}
