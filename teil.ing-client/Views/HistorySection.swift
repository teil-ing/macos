import SwiftUI

struct HistorySection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("No recent uploads")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    HistorySection()
        .frame(width: 280)
}
