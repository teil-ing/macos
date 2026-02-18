@preconcurrency import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit

// MARK: - StreamCaptureBridge

/// SCStream-based single-frame capture bridge for macOS 13 Ventura.
///
/// Bridges SCStream's callback-based delegate API to Swift async/await
/// using CheckedContinuation. CGImage extraction happens synchronously
/// inside the delegate callback — CMSampleBuffer is never passed across
/// a Task boundary.
///
/// Marked @unchecked Sendable because mutable state (continuation, stream,
/// didResume) is accessed exclusively from the serialized capture queue
/// and the CheckedContinuation pattern, which prevents data races.
final class StreamCaptureBridge: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {

    // MARK: - Private state

    private var continuation: CheckedContinuation<CGImage, Error>?
    private var stream: SCStream?
    private var didResume: Bool = false

    // MARK: - Static resources

    /// Dedicated background queue for SCStream frame callbacks.
    ///
    /// CRITICAL: Must NOT be the main queue — SCStreamOutput callbacks on the main queue
    /// conflict with Swift 6 strict concurrency and can cause deadlocks.
    private static let captureQueue = DispatchQueue(
        label: "ing.teil.capture.stream",
        qos: .userInteractive
    )

    /// Shared CIContext — reuse for better performance (CIContext creation is expensive).
    private static let ciContext = CIContext()

    // MARK: - Public API

    /// Captures a single frame from the display described by the filter and configuration.
    ///
    /// Uses withCheckedThrowingContinuation to bridge the callback-based SCStream API
    /// to async/await. The stream is stopped immediately after the first valid frame.
    ///
    /// - Parameters:
    ///   - filter: The SCContentFilter describing which display to capture.
    ///   - config: The SCStreamConfiguration controlling output resolution and format.
    /// - Returns: A CGImage of the captured frame.
    func captureOneFrame(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: CaptureEngineError.captureFailedNoImage)
                return
            }

            self.continuation = continuation
            self.didResume = false

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            self.stream = stream

            do {
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: Self.captureQueue)
                stream.startCapture()
            } catch {
                self.resumeOnce(throwing: error)
                return
            }

            // 10-second timeout: resume with error if no frame arrives
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                self?.resumeOnce(throwing: StreamCaptureError.timeout)
            }
        }
    }

    // MARK: - SCStreamOutput

    /// Receives sample buffers from the SCStream capture queue.
    ///
    /// CRITICAL: Extract CGImage synchronously here — do NOT store sampleBuffer
    /// or reference it from a Task. The CMSampleBuffer is owned by ScreenCaptureKit
    /// and freed when this method returns.
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }

        // Only process complete frames — skip idle, blank, or suspended frames
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]],
              let statusRawValue = attachments.first?[SCStreamFrameInfo.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else { return }

        // Extract CGImage SYNCHRONOUSLY inside this callback before sampleBuffer is freed
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = Self.ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        // CGImage is now an independent object — safe to use after this method returns
        resumeOnce(returning: cgImage)

        // Stop the stream asynchronously — do NOT block the capture queue.
        // Capture self (which is @unchecked Sendable) rather than the SCStream directly.
        Task { [self] in
            await stopStream()
        }
    }

    // MARK: - SCStreamDelegate

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        resumeOnce(throwing: error)
    }

    // MARK: - Stream lifecycle

    /// Stops the current stream, if any.
    private func stopStream() async {
        guard let s = stream else { return }
        try? await s.stopCapture()
        stream = nil
    }

    // MARK: - Resume helpers

    /// Resumes the continuation with a result, guarding against double-resume.
    private func resumeOnce(returning image: CGImage) {
        guard !didResume else { return }
        didResume = true
        let c = continuation
        continuation = nil
        c?.resume(returning: image)
    }

    private func resumeOnce(throwing error: Error) {
        guard !didResume else { return }
        didResume = true
        let c = continuation
        continuation = nil
        c?.resume(throwing: error)
    }
}

// MARK: - StreamCaptureError

enum StreamCaptureError: LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Screen capture timed out after 10 seconds."
        }
    }
}
