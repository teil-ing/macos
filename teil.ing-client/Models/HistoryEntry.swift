import Foundation
import SwiftData

// MARK: - HistoryEntry

/// SwiftData persistent model for a single upload history record.
///
/// Each entry corresponds to one successful upload, storing the share URL,
/// an absolute path to the thumbnail JPEG file, and the capture timestamp.
/// `thumbnailPath` is stored as `String` (not `URL`) to avoid SwiftData URL encoding quirks.
@Model
final class HistoryEntry {
    /// Unique identifier. `@Attribute(.unique)` prevents duplicate entries.
    @Attribute(.unique) var id: UUID

    /// Share URL returned by the teil.ing API (stored as String to avoid URL encoding quirks).
    var shareURL: String

    /// Absolute path to the JPEG thumbnail file in Application Support.
    var thumbnailPath: String

    /// Timestamp when the capture completed (from CaptureResult.timestamp).
    var timestamp: Date

    init(
        id: UUID = UUID(),
        shareURL: String,
        thumbnailPath: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.shareURL = shareURL
        self.thumbnailPath = thumbnailPath
        self.timestamp = timestamp
    }
}
