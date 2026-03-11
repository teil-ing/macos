import SwiftUI

// MARK: - QuotaBarView

/// Compact storage quota display for the popover footer area.
/// Shows a progress bar and usage summary. Hides the bar for admin users (unlimited quota).
struct QuotaBarView: View {

    let quota: QuotaResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let storageQuota = quota.storageQuota, storageQuota > 0 {
                let used = Double(quota.storageUsed)
                let total = Double(storageQuota)

                ProgressView(value: used, total: total)
                    .progressViewStyle(.linear)
                    .tint(used / total > 0.9 ? .red : used / total > 0.7 ? .orange : .accentColor)

                HStack {
                    Text("\(formatBytes(quota.storageUsed)) / \(formatBytes(storageQuota))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(quota.tier.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Storage: Unlimited")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(quota.tier.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        }
        let kb = Double(bytes) / 1024
        return String(format: "%.0f KB", kb)
    }
}
