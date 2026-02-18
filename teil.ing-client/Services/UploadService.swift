import AppKit
import Foundation

// MARK: - UploadFeedbackEvent

/// Events emitted by UploadService to drive UI feedback on the main actor.
enum UploadFeedbackEvent: Sendable {
    case uploadStarted
    case uploadSucceeded(shareUrl: String, capture: CaptureResult)
    case uploadFailed(error: UploadError)
}

// MARK: - Data Extension

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - UploadService

/// Serial upload queue implemented as a Swift actor.
///
/// Uploads are processed one at a time in FIFO order using a chained Task pattern.
/// Only the last queued upload copies the URL to clipboard and opens the browser.
actor UploadService {

    static let shared = UploadService()

    // MARK: - Private State

    private var uploadTask: Task<Void, Never>?
    private var pendingCount: Int = 0

    /// Retained for Retry; cleared on next enqueue call.
    private(set) var failedCapture: CaptureResult?

    /// Most recent error for popover display; cleared on next successful upload or enqueue.
    private(set) var lastError: UploadError?

    private init() {}

    // MARK: - Public API

    /// Enqueue a capture result for upload.
    ///
    /// Chains a new Task onto the current uploadTask for serial execution.
    /// Only the last enqueued upload will copy the URL to clipboard and open the browser.
    /// Preference values are snapshotted at enqueue time — no actor-crossing needed during upload.
    func enqueue(
        _ capture: CaptureResult,
        stripExif: Bool,
        openInBrowser: Bool,
        clipboardCopy: Bool,
        onFeedback: @MainActor @Sendable @escaping (UploadFeedbackEvent) -> Void
    ) {
        pendingCount += 1
        let capturedPendingCount = pendingCount
        let capturedStripExif = stripExif
        let capturedOpenInBrowser = openInBrowser
        let capturedClipboardCopy = clipboardCopy
        failedCapture = nil
        lastError = nil

        let previousTask = uploadTask
        uploadTask = Task {
            await previousTask?.value
            await self.performUpload(
                capture: capture,
                capturedPendingCount: capturedPendingCount,
                stripExif: capturedStripExif,
                shouldOpenInBrowser: capturedOpenInBrowser,
                shouldCopyToClipboard: capturedClipboardCopy,
                onFeedback: onFeedback
            )
        }
    }

    /// Retry the last failed upload, if one exists.
    ///
    /// Passes current preference values at retry time so any preference changes
    /// made between failure and retry are honoured.
    func retry(
        stripExif: Bool,
        openInBrowser: Bool,
        clipboardCopy: Bool,
        onFeedback: @MainActor @Sendable @escaping (UploadFeedbackEvent) -> Void
    ) {
        if let capture = failedCapture {
            enqueue(
                capture,
                stripExif: stripExif,
                openInBrowser: openInBrowser,
                clipboardCopy: clipboardCopy,
                onFeedback: onFeedback
            )
        }
    }

    // MARK: - Private: Upload Execution

    private func performUpload(
        capture: CaptureResult,
        capturedPendingCount: Int,
        stripExif: Bool,
        shouldOpenInBrowser: Bool,
        shouldCopyToClipboard: Bool,
        onFeedback: @MainActor @Sendable @escaping (UploadFeedbackEvent) -> Void
    ) async {
        await onFeedback(.uploadStarted)

        // Step 1: Retrieve API key from Keychain.
        guard let apiKey = KeychainService.shared.apiKey else {
            failedCapture = capture
            lastError = .noAPIKey
            await onFeedback(.uploadFailed(error: .noAPIKey))
            return
        }

        // Step 2: Convert CGImage to PNG data.
        let rep = NSBitmapImageRep(cgImage: capture.image)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            failedCapture = capture
            lastError = .encodingFailed
            await onFeedback(.uploadFailed(error: .encodingFailed))
            return
        }

        // Step 3: Build multipart request (stripExif field conditionally included).
        let (request, bodyData) = buildMultipartRequest(apiKey: apiKey, pngData: pngData, stripExif: stripExif)

        // Step 4: Perform upload with retry.
        do {
            let result = try await performWithRetry(maxAttempts: 3) {
                try await self.executeUploadRequest(request: request, bodyData: bodyData)
            }

            // Step 5: Post-upload actions — only the last queued upload triggers clipboard/browser.
            let isLast = capturedPendingCount == pendingCount
            if isLast {
                if shouldCopyToClipboard {
                    await copyToClipboard(result.shareUrl)
                }
                if shouldOpenInBrowser {
                    await openInBrowser(result.shareUrl)
                }
            }

            lastError = nil
            await onFeedback(.uploadSucceeded(shareUrl: result.shareUrl, capture: capture))
        } catch let uploadError as UploadError {
            failedCapture = capture
            lastError = uploadError
            await onFeedback(.uploadFailed(error: uploadError))
        } catch {
            let wrapped = UploadError.networkError(error.localizedDescription)
            failedCapture = capture
            lastError = wrapped
            await onFeedback(.uploadFailed(error: wrapped))
        }
    }

    // MARK: - Private: Multipart Request Builder

    private func buildMultipartRequest(apiKey: String, pngData: Data, stripExif: Bool) -> (URLRequest, Data) {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: "https://teil.ing/api/v1/upload")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 30

        var body = Data()

        // File field (always required)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"screenshot.png\"\r\n")
        body.append("Content-Type: image/png\r\n")
        body.append("\r\n")
        body.append(pngData)
        body.append("\r\n")

        // stripExif field — only included when preference is ON.
        // API contract: omit the field entirely when stripping is off (do NOT send stripExif=false).
        if stripExif {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"stripExif\"\r\n")
            body.append("\r\n")
            body.append("true")
            body.append("\r\n")
        }

        body.append("--\(boundary)--\r\n")

        return (request, body)
    }

    // MARK: - Private: Upload Execution

    private func executeUploadRequest(request: URLRequest, bodyData: Data) async throws -> UploadResponse {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.upload(for: request, from: bodyData)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw UploadError.networkError("No internet connection")
            default:
                throw UploadError.networkError("Could not reach teil.ing")
            }
        } catch {
            throw UploadError.networkError("Could not reach teil.ing")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.networkError("Unexpected response from teil.ing")
        }

        switch httpResponse.statusCode {
        case 201:
            let decoder = JSONDecoder()
            return try decoder.decode(UploadResponse.self, from: data)
        case 401:
            throw UploadError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw UploadError.rateLimited(retryAfter: retryAfter)
        case 400:
            throw UploadError.badRequest("Image rejected by server")
        default:
            throw UploadError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Private: Retry Logic

    private func performWithRetry<T: Sendable>(
        maxAttempts: Int,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error = UploadError.networkError("Unknown error")

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch UploadError.unauthorized {
                // Never retry 401 — rethrow immediately.
                throw UploadError.unauthorized
            } catch UploadError.rateLimited(let retryAfter) {
                lastError = UploadError.rateLimited(retryAfter: retryAfter)
                if attempt < maxAttempts {
                    let delay = Double(retryAfter ?? Int(pow(2.0, Double(attempt))))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch let uploadError as UploadError {
                lastError = uploadError
                if attempt < maxAttempts {
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = UploadError.networkError(error.localizedDescription)
                if attempt < maxAttempts {
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError
    }

    // MARK: - Private: Post-Upload Actions

    private func copyToClipboard(_ urlString: String) async {
        await MainActor.run {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(urlString, forType: .string)
        }
    }

    private func openInBrowser(_ urlString: String) async {
        await MainActor.run {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
