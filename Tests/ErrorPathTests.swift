import XCTest
@testable import teil_ing_client

// MARK: - ErrorPathTests

final class ErrorPathTests: XCTestCase {

    // MARK: - UploadError localized descriptions

    func testUploadErrorNoAPIKeyDescription() {
        let error = UploadError.noAPIKey
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        XCTAssertTrue(
            description!.lowercased().contains("api key"),
            "Expected 'API key' in: \(description!)"
        )
    }

    func testUploadErrorUnauthorizedDescription() {
        let error = UploadError.unauthorized
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        let lower = description!.lowercased()
        XCTAssertTrue(
            lower.contains("invalid") || lower.contains("expired"),
            "Expected 'invalid' or 'expired' in: \(description!)"
        )
    }

    func testUploadErrorRateLimitedNilDescription() {
        let error = UploadError.rateLimited(retryAfter: nil)
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        let lower = description!.lowercased()
        XCTAssertTrue(
            lower.contains("wait") || lower.contains("try again"),
            "Expected 'wait' or 'try again' in: \(description!)"
        )
    }

    func testUploadErrorRateLimitedWithRetryAfterDescription() {
        let error = UploadError.rateLimited(retryAfter: 30)
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        let lower = description!.lowercased()
        XCTAssertTrue(
            lower.contains("wait") || lower.contains("try again"),
            "Expected 'wait' or 'try again' in: \(description!)"
        )
    }

    func testUploadErrorBadRequestDescription() {
        let message = "test error message"
        let error = UploadError.badRequest(message)
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        XCTAssertTrue(
            description!.contains(message),
            "Expected provided message '\(message)' in: \(description!)"
        )
    }

    func testUploadErrorServerErrorDescription() {
        let error = UploadError.serverError(500)
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        XCTAssertTrue(
            description!.contains("500"),
            "Expected '500' in: \(description!)"
        )
    }

    func testUploadErrorNetworkErrorDescription() {
        let error = UploadError.networkError("timeout")
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        XCTAssertTrue(
            description!.lowercased().contains("timeout"),
            "Expected 'timeout' in: \(description!)"
        )
    }

    func testUploadErrorEncodingFailedDescription() {
        let error = UploadError.encodingFailed
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        let lower = description!.lowercased()
        XCTAssertTrue(
            lower.contains("encode") || lower.contains("png"),
            "Expected 'encode' or 'PNG' in: \(description!)"
        )
    }

    // MARK: - KeychainError localized description

    func testKeychainErrorSaveFailedDescription() {
        let error = KeychainError.saveFailed(errSecParam)
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertFalse(description!.isEmpty)
        XCTAssertTrue(
            description!.contains("OSStatus"),
            "Expected 'OSStatus' in: \(description!)"
        )
    }

    // MARK: - UploadResponse decoding

    func testUploadResponseDecoding() throws {
        let json = """
        {
            "id": "abc123",
            "slug": "test-slug",
            "shareUrl": "https://teil.ing/i/test-slug",
            "imageUrl": "https://teil.ing/images/abc123.png",
            "thumbnailUrl": "https://teil.ing/thumbnails/abc123.png",
            "isPrivate": false
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UploadResponse.self, from: json)
        XCTAssertEqual(response.id, "abc123")
        XCTAssertEqual(response.slug, "test-slug")
        XCTAssertEqual(response.shareUrl, "https://teil.ing/i/test-slug")
        XCTAssertEqual(response.imageUrl, "https://teil.ing/images/abc123.png")
        XCTAssertEqual(response.thumbnailUrl, "https://teil.ing/thumbnails/abc123.png")
        XCTAssertFalse(response.isPrivate)
    }

    func testUploadResponseDecodingFailsWithMissingFields() {
        let json = """
        {
            "id": "abc123"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode(UploadResponse.self, from: json),
            "Expected decoding to fail with missing required fields"
        )
    }
}
