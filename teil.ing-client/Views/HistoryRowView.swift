import AppKit
import SwiftUI

struct HistoryRowView: View {
    let entry: HistoryEntry
    let onDelete: () -> Void

    @State private var copied = false

    // Formatters are expensive to init — stored as property, not created inside body (Pitfall 7)
    private let formatter = RelativeDateTimeFormatter()

    var body: some View {
        // TimelineView(.everyMinute) auto-refreshes the relative timestamp every minute
        TimelineView(.everyMinute) { context in
            HStack(spacing: 8) {
                thumbnailView
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(formatter.localizedString(for: entry.timestamp, relativeTo: context.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Copy URL button — shows checkmark for 1.5 seconds after copying
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.shareURL, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .milliseconds(1500))
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)

                // Open in browser button
                Button {
                    if let url = URL(string: entry.shareURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            .contextMenu {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }

    @ViewBuilder private var thumbnailView: some View {
        if let nsImage = NSImage(contentsOfFile: entry.thumbnailPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
