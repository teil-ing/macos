import Foundation

// MARK: - UploadResponse

/// Decodable model matching the teil.ing API 201 upload response.
struct UploadResponse: Decodable, Sendable {
    let id: String
    let slug: String
    let shareUrl: String
    /// null when the image is private (S3 ACL is private).
    let imageUrl: String?
    /// null when the image is private.
    let thumbnailUrl: String?
    let isPrivate: Bool
}

// MARK: - UploadError

/// Errors that can occur during the upload pipeline.
enum UploadError: Error, LocalizedError, Sendable {
    /// Keychain has no API key — reject before making request.
    case noAPIKey
    /// 401 from API — bad or expired key; must NOT be retried.
    case unauthorized
    /// 429 from API — rate limited; optional Retry-After seconds.
    case rateLimited(retryAfter: Int?)
    /// 400 — not an image, missing file, or other bad request.
    case badRequest(String)
    /// 413 — upload would exceed storage quota.
    case quotaExceeded(storageUsed: Int, storageQuota: Int)
    /// 5xx or unexpected status code.
    case serverError(Int)
    /// URLError or other network-layer error.
    case networkError(String)
    /// CGImage to PNG conversion returned nil.
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please add your key in settings."
        case .unauthorized:
            return "API key is invalid or expired. Please update your key."
        case .rateLimited:
            return "Too many uploads. Please wait and try again."
        case .badRequest(let message):
            return "The image could not be uploaded: \(message)"
        case .quotaExceeded:
            return "Storage quota exceeded. Free up space or upgrade your plan."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError(let message):
            return "Upload failed: \(message)"
        case .encodingFailed:
            return "Failed to encode screenshot as PNG."
        }
    }
}
