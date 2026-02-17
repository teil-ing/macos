import SwiftUI

struct PopoverRootView: View {
    var body: some View {
        VStack(spacing: 0) {
            CaptureSection()
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
