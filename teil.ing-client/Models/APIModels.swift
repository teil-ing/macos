import Foundation

// MARK: - ImageResponse

/// Image metadata returned by GET /api/v1/images and GET /api/v1/images/:id
struct ImageResponse: Codable, Sendable, Identifiable {
    let id: String
    let slug: String
    let originalFilename: String
    let mimeType: String
    let fileSize: Int
    /// Direct CDN URL. null when image is private or password-protected.
    let imageUrl: String?
    /// Thumbnail URL. null for legacy uploads; signed URL for private/password-protected images.
    let thumbnailUrl: String?
    let hasPassword: Bool
    let isPrivate: Bool
    let viewCount: Int
    let maxViews: Int?
    /// ISO 8601 expiry date, or null if no expiry.
    let validUntil: String?
    let isEdited: Bool
    /// ISO 8601 creation date.
    let createdAt: String
}

// MARK: - ImageListResponse

/// Wrapper for GET /api/v1/images paginated response.
struct ImageListResponse: Codable, Sendable {
    let images: [ImageResponse]
    let limit: Int
    let offset: Int
}

// MARK: - QuotaResponse

/// GET /api/v1/quota response.
struct QuotaResponse: Codable, Sendable {
    let storageUsed: Int
    /// null for admin users (unlimited storage).
    let storageQuota: Int?
    let tier: String
    let imageCount: Int
}

// MARK: - ImageUpdateRequest

/// Request body for PATCH /api/v1/images/:id
struct ImageUpdateRequest: Encodable, Sendable {
    var password: String?
    var removePassword: Bool?
    var `private`: Bool?
    var maxViews: Int?
    var validUntil: String?
    var validForDays: Int?
}

// MARK: - SuccessResponse

/// Generic success response { "success": true }
struct SuccessResponse: Decodable, Sendable {
    let success: Bool
}
