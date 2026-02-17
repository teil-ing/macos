import CoreGraphics
import Foundation

// MARK: - CaptureResult

/// Value type wrapping a captured CGImage with metadata about the capture operation.
///
/// CGImage is a CoreFoundation type that is thread-safe, so CaptureResult
/// can be safely passed across actor and task boundaries.
struct CaptureResult: Sendable {
    /// The captured image.
    let image: CGImage

    /// The captured rectangle in global screen coordinates (AppKit coordinate space,
    /// origin at bottom-left of primary display, Y increasing upward).
    let capturedRect: CGRect

    /// Timestamp when the capture completed.
    let timestamp: Date

    init(image: CGImage, capturedRect: CGRect, timestamp: Date = Date()) {
        self.image = image
        self.capturedRect = capturedRect
        self.timestamp = timestamp
    }
}
