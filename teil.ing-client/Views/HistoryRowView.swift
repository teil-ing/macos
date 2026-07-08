import AppKit
import SwiftUI

// MARK: - ThumbnailSource

/// Identifies where the thumbnail for a history row should be loaded from.
enum ThumbnailSource: Sendable {
    /// Load from a local file path using NSImage.
    case local(path: String)
    /// Load from a remote URL using AsyncImage (may be nil for legacy/private images).
    case remote(url: String?)
}

// MARK: - HistoryDisplayItem

/// A unified, lightweight display model used by HistoryRowView for both local SwiftData
/// entries and remote API ImageResponse objects.
struct HistoryDisplayItem: Identifiable, Sendable {
    let id: String
    let shareURL: String
    let thumbnailSource: ThumbnailSource
    let timestamp: Date
    let isPrivate: Bool
    let viewCount: Int?
    let hasPassword: Bool
    /// Non-nil for remote images — enables detail sheet and server-side delete.
    let imageId: String?
}

// MARK: - HistoryDisplayItem init helpers

extension HistoryDisplayItem {

    /// Create a display item from a local SwiftData HistoryEntry.
    init(entry: HistoryEntry) {
        self.init(
            id: entry.id.uuidString,
            shareURL: entry.shareURL,
            thumbnailSource: .local(path: entry.thumbnailPath),
            timestamp: entry.timestamp,
            isPrivate: false,
            viewCount: nil,
            hasPassword: false,
            imageId: entry.imageId
        )
    }

    /// Create a display item from a remote API ImageResponse.
    init(imageResponse: ImageResponse) {
        let date = Self.parseISO8601(imageResponse.createdAt) ?? Date()
        self.init(
            id: imageResponse.id,
            shareURL: "https://teil.ing/i/\(imageResponse.slug)",
            thumbnailSource: .remote(url: imageResponse.thumbnailUrl),
            timestamp: date,
            isPrivate: imageResponse.isPrivate,
            viewCount: imageResponse.viewCount,
            hasPassword: imageResponse.hasPassword,
            imageId: imageResponse.id
        )
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - HistoryRowView

struct HistoryRowView: View {
    let item: HistoryDisplayItem
    let onDelete: () -> Void
    var onSelectDetail: ((String) -> Void)? = nil

    @State private var copied = false

    // Formatters are expensive to init — stored as property, not created inside body (Pitfall 7)
    private let formatter = RelativeDateTimeFormatter()

    var body: some View {
        // TimelineView(.everyMinute) auto-refreshes the relative timestamp every minute.
        // The scheduled tick only drives re-rendering; the label itself is computed against
        // the real current instant (see relativeTimestamp) rather than the minute-aligned tick.
        TimelineView(.everyMinute) { _ in
            HStack(spacing: 8) {
                thumbnailView
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(relativeTimestamp())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if item.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if item.hasPassword {
                            Image(systemName: "key.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let viewCount = item.viewCount {
                        Text("\(viewCount) \(viewCount == 1 ? "view" : "views")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Edit button — opens the web edit page for this image in the browser
                // (e.g. https://teil.ing/i/{slug}/edit), derived by appending "/edit" to
                // the share URL.
                Button {
                    if let url = URL(string: item.shareURL + "/edit") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // Copy URL button — shows checkmark for 1.5 seconds after copying
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.shareURL, forType: .string)
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
                    if let url = URL(string: item.shareURL) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                if let imageId = item.imageId {
                    onSelectDetail?(imageId)
                }
            }
            .contextMenu {
                Button("Copy URL") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.shareURL, forType: .string)
                }
                Button("Open in Browser") {
                    if let url = URL(string: item.shareURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                if item.imageId != nil {
                    Button("View Details") {
                        if let imageId = item.imageId {
                            onSelectDetail?(imageId)
                        }
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
        }
    }

    // MARK: - Relative Timestamp

    /// Human-friendly relative time for this row, measured against the real current instant.
    ///
    /// Clamps freshly-created or future timestamps to "Just now": a just-captured upload's
    /// server `createdAt` can be a second or two ahead of the local clock, and the minute-aligned
    /// TimelineView tick lags real time — either would otherwise render a nonsensical "in N seconds".
    private func relativeTimestamp() -> String {
        let secondsAgo = Date().timeIntervalSince(item.timestamp)
        if secondsAgo < 5 { return "Just now" }
        return formatter.localizedString(for: item.timestamp, relativeTo: Date())
    }

    // MARK: - Thumbnail

    @ViewBuilder private var thumbnailView: some View {
        switch item.thumbnailSource {
        case .local(let path):
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderThumbnail
            }
        case .remote(let urlString):
            if let urlString = urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderThumbnail
                    default:
                        loadingThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }

    private var loadingThumbnail: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.secondary.opacity(0.1))
            .overlay {
                ProgressView()
                    .controlSize(.small)
            }
    }
}
