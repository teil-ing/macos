import SwiftUI
import AppKit

struct PopoverFooterView: View {
    var onOpenPreferences: (() -> Void)?

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
