import CoreGraphics
import ScreenCaptureKit

// MARK: - ScreenshotCapture

/// Namespace for SCScreenshotManager-based capture on macOS 14+.
///
/// Both methods are simple wrappers — all complexity (filter building, config
/// building, coordinate conversion) lives in CaptureEngine.
@available(macOS 14, *)
enum ScreenshotCapture {

    /// Captures the full display described by the filter and configuration.
    ///
    /// - Parameters:
    ///   - filter: An SCContentFilter targeting the display, with own-app exclusions applied.
    ///   - config: An SCStreamConfiguration with full-display width/height in backing pixels.
    /// - Returns: A CGImage of the captured display.
    static func captureFullscreen(
        filter: SCContentFilter,
        config: SCStreamConfiguration
    ) async throws -> CGImage {
        try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    /// Captures a region of the display described by the filter and configuration.
    ///
    /// The configuration's sourceRect must already be set in display-local point
    /// coordinates by the caller (CaptureEngine.buildConfig).
    ///
    /// - Parameters:
    ///   - filter: An SCContentFilter targeting the display, with own-app exclusions applied.
    ///   - config: An SCStreamConfiguration with sourceRect, width, and height set.
    /// - Returns: A CGImage of the captured region.
    static func captureRegion(
        filter: SCContentFilter,
        config: SCStreamConfiguration
    ) async throws -> CGImage {
        try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
}
