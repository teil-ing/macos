import SwiftUI
import AppKit

struct PopoverFooterView: View {
    var onOpenPreferences: (() -> Void)?

    @ObservedObject private var updateService = UpdateService.shared

    var body: some View {
        HStack {
            Button {
                onOpenPreferences?()
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .disabled(onOpenPreferences == nil)

            if updateService.updateAvailable {
                Button {
                    onOpenPreferences?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                        Text("Update")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    PopoverFooterView(onOpenPreferences: {})
        .frame(width: 280)
}
