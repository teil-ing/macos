import AppKit
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

// MARK: - CaptureEngineError

enum CaptureEngineError: LocalizedError {
    case noDisplayFound
    case noScreenFound
    case captureFailedNoImage
    case stitchFailed
    case windowCaptureFailedNoImage

    var errorDescription: String? {
        switch self {
        case .noDisplayFound:
            return "Could not find a suitable display for capture."
        case .noScreenFound:
            return "Could not find the current screen."
        case .captureFailedNoImage:
            return "Capture did not produce an image."
        case .stitchFailed:
            return "Could not stitch cross-monitor captures."
        case .windowCaptureFailedNoImage:
            return "Window capture did not produce an image."
        }
    }
}

// MARK: - ScreenInfo
// A Sendable snapshot of NSScreen data needed for capture configuration.

private struct ScreenInfo: Sendable {
    let frame: CGRect
    let backingScaleFactor: CGFloat
}

// MARK: - CaptureEngine

/// Main capture coordinator actor.
///
/// Dispatches fullscreen and region capture requests using the appropriate backend:
/// - macOS 14+: SCScreenshotManager (simple async API)
/// - macOS 13: SCStream single-frame bridge via StreamCaptureBridge
///
/// Own app bundle is always excluded from SCContentFilter so no overlay or popover
/// will ever appear in a captured image.
actor CaptureEngine {

    // MARK: - Public API

    /// Captures the display where the mouse cursor currently is.
    ///
    /// - Returns: A CaptureResult containing the full-display CGImage.
    func captureFullscreen() async throws -> CaptureResult {
        let (display, screenInfo) = try await findCurrentDisplay()

        let filter = try await buildFilter(for: display)
        let config = buildConfig(sourceRect: nil, display: display, scale: screenInfo.backingScaleFactor)

        // Wrap in nonisolated(unsafe) to transfer non-Sendable SCKit types across actor boundary.
        // These values are fully constructed before the transfer and not mutated afterward.
        let image: CGImage
        if #available(macOS 14, *) {
            nonisolated(unsafe) let f = filter
            nonisolated(unsafe) let c = config
            image = try await ScreenshotCapture.captureFullscreen(filter: f, config: c)
        } else {
            nonisolated(unsafe) let f = filter
            nonisolated(unsafe) let c = config
            let bridge = StreamCaptureBridge()
            image = try await bridge.captureOneFrame(filter: f, config: c)
        }

        let capturedRect = display.frame
        return CaptureResult(image: image, capturedRect: capturedRect)
    }

    /// Captures a region defined by a global-coordinate CGRect.
    ///
    /// If the rect spans multiple displays, each display's intersecting portion is captured
    /// separately and stitched by CrossMonitorStitcher.
    ///
    /// - Parameter rect: The region to capture, in global AppKit screen coordinates.
    /// - Returns: A CaptureResult containing the captured CGImage.
    func captureRegion(_ rect: CGRect) async throws -> CaptureResult {
        // Collect NSScreen data on MainActor — NSScreen is not Sendable
        let screenInfos: [(frame: CGRect, scale: CGFloat)] = await MainActor.run {
            NSScreen.screens.map { ($0.frame, $0.backingScaleFactor) }
        }

        // Find which screens intersect the requested rect
        let intersecting: [(frame: CGRect, scale: CGFloat, intersection: CGRect)] = screenInfos.compactMap { info in
            let intersection = info.frame.intersection(rect)
            guard !intersection.isNull && intersection.width > 0 && intersection.height > 0 else {
                return nil
            }
            return (info.frame, info.scale, intersection)
        }

        guard !intersecting.isEmpty else {
            throw CaptureEngineError.noScreenFound
        }

        if intersecting.count == 1 {
            // Single-display path
            let entry = intersecting[0]
            let display = try await findDisplayByFrame(entry.frame)
            let filter = try await buildFilter(for: display)
            let config = buildConfig(sourceRect: entry.intersection, display: display, scale: entry.scale)

            let image: CGImage
            if #available(macOS 14, *) {
                image = try await ScreenshotCapture.captureRegion(filter: filter, config: config)
            } else {
                let bridge = StreamCaptureBridge()
                image = try await bridge.captureOneFrame(filter: filter, config: config)
            }

            return CaptureResult(image: image, capturedRect: entry.intersection)
        } else {
            // Multi-display path — capture each portion and stitch
            var displayCaptures: [CrossMonitorStitcher.DisplayCapture] = []

            for entry in intersecting {
                let display = try await findDisplayByFrame(entry.frame)
                let filter = try await buildFilter(for: display)
                let config = buildConfig(sourceRect: entry.intersection, display: display, scale: entry.scale)

                let image: CGImage
                if #available(macOS 14, *) {
                    image = try await ScreenshotCapture.captureRegion(filter: filter, config: config)
                } else {
                    let bridge = StreamCaptureBridge()
                    image = try await bridge.captureOneFrame(filter: filter, config: config)
                }

                displayCaptures.append(
                    CrossMonitorStitcher.DisplayCapture(
                        image: image,
                        displayFrame: entry.intersection,
                        scale: entry.scale
                    )
                )
            }

            guard let stitched = CrossMonitorStitcher.stitch(displayCaptures, totalRect: rect) else {
                throw CaptureEngineError.stitchFailed
            }

            return CaptureResult(image: stitched, capturedRect: rect)
        }
    }

    /// Captures a specific window without shadow and with transparent corners.
    ///
    /// Uses `SCContentFilter(desktopIndependentWindow:)` to capture the full window
    /// regardless of screen position (correctly handles partially off-screen windows).
    ///
    /// - Parameter scWindow: The window to capture, obtained from SCShareableContent.
    /// - Returns: A CaptureResult with a BGRA CGImage (alpha channel preserved).
    func captureWindow(_ scWindow: SCWindow) async throws -> CaptureResult {
        let filter = SCContentFilter(desktopIndependentWindow: scWindow)

        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA  // Has alpha channel for transparent corners
        config.showsCursor = false
        config.capturesAudio = false

        // true = IGNORE (exclude) the shadow — counter-intuitive naming (Pitfall 3 from research)
        config.ignoreShadowsSingleWindow = true

        // false = do NOT force opaque — preserves the window's alpha channel for rounded corners
        config.shouldBeOpaque = false

        // Logical points: SCKit handles Retina backing scale internally
        config.width = Int(scWindow.frame.width)
        config.height = Int(scWindow.frame.height)

        // Wrap in nonisolated(unsafe) to transfer non-Sendable SCKit types across actor boundary.
        // These values are fully constructed before the transfer and not mutated afterward.
        let image: CGImage
        if #available(macOS 14, *) {
            nonisolated(unsafe) let f = filter
            nonisolated(unsafe) let c = config
            image = try await SCScreenshotManager.captureImage(
                contentFilter: f,
                configuration: c
            )
        } else {
            nonisolated(unsafe) let f = filter
            nonisolated(unsafe) let c = config
            let bridge = StreamCaptureBridge()
            image = try await bridge.captureOneFrame(filter: f, config: c)
        }

        // capturedRect: SCWindow.frame is in CG coordinates; CaptureResult documents AppKit.
        // For window capture the rect is used only for flash feedback positioning in AppDelegate,
        // which calls cgFrameToAppKit before passing to CaptureFeedback.
        return CaptureResult(image: image, capturedRect: scWindow.frame)
    }

    // MARK: - Private Helpers

    /// Builds an SCContentFilter for the given display, excluding the app's own bundle.
    private func buildFilter(for display: SCDisplay) async throws -> SCContentFilter {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let excluded = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        return SCContentFilter(
            display: display,
            excludingApplications: excluded,
            exceptingWindows: []
        )
    }

    /// Builds an SCStreamConfiguration for the given capture parameters.
    ///
    /// - Parameters:
    ///   - sourceRect: The rect to capture in global screen coordinates. Nil captures the full display.
    ///   - display: The target SCDisplay.
    ///   - scale: The backing scale factor (from NSScreen.backingScaleFactor).
    private func buildConfig(sourceRect: CGRect?, display: SCDisplay, scale: CGFloat) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.capturesAudio = false

        if let rect = sourceRect {
            // sourceRect must be in display-LOCAL point coordinates (subtract display origin)
            let localX = rect.origin.x - display.frame.origin.x
            let localY = rect.origin.y - display.frame.origin.y
            config.sourceRect = CGRect(x: localX, y: localY, width: rect.width, height: rect.height)
            // width/height must be in backing pixels
            config.width = Int(rect.width * scale)
            config.height = Int(rect.height * scale)
        } else {
            // Full display capture
            config.width = Int(CGFloat(display.width) * scale)
            config.height = Int(CGFloat(display.height) * scale)
        }

        return config
    }

    /// Finds the SCDisplay whose frame origin matches the given screen frame origin.
    private func findDisplayByFrame(_ screenFrame: CGRect) async throws -> SCDisplay {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: {
            abs($0.frame.origin.x - screenFrame.origin.x) < 1.0
                && abs($0.frame.origin.y - screenFrame.origin.y) < 1.0
        }) else {
            throw CaptureEngineError.noDisplayFound
        }
        return display
    }

    /// Finds the display where the mouse cursor is currently located.
    ///
    /// NSScreen.screens and NSEvent.mouseLocation are accessed on MainActor.
    /// Only Sendable values (CGRect, CGFloat) are returned from the MainActor closure.
    ///
    /// - Returns: A tuple of (SCDisplay, ScreenInfo) for the display under the cursor.
    private func findCurrentDisplay() async throws -> (SCDisplay, ScreenInfo) {
        // Collect NSScreen data on MainActor — NSScreen is not Sendable
        let (mouseLocation, screenInfos): (CGPoint, [ScreenInfo]) = await MainActor.run {
            let mouse = NSEvent.mouseLocation
            let infos = NSScreen.screens.map { ScreenInfo(frame: $0.frame, backingScaleFactor: $0.backingScaleFactor) }
            return (mouse, infos)
        }

        // Find which screen contains the cursor
        guard let screenInfo = screenInfos.first(where: { $0.frame.contains(mouseLocation) })
            ?? screenInfos.first else {
            throw CaptureEngineError.noScreenFound
        }

        let display = try await findDisplayByFrame(screenInfo.frame)
        return (display, screenInfo)
    }
}
