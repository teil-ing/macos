import SwiftUI
import AppKit

struct PopoverFooterView: View {
    var body: some View {
        HStack {
            Button {
                // Settings — wired in Phase 8
            } label: {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .disabled(true)

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
    PopoverFooterView()
        .frame(width: 280)
}
