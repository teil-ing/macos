import Foundation

// MARK: - APIError

/// Errors that can occur when calling the teil.ing API (non-upload endpoints).
enum APIError: Error, LocalizedError, Sendable {
    /// No API key in Keychain — cannot authenticate.
    case noAPIKey
    /// 401 — API key is missing or invalid.
    case unauthorized
    /// 404 — image not found or not owned by the authenticated user.
    case notFound
    /// 429 — rate limit exceeded; optional Retry-After seconds.
    case rateLimited(retryAfter: Int?)
    /// 5xx or unexpected HTTP status code.
    case serverError(Int)
    /// URLError or other network-layer error.
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key found. Please add your key in settings."
        case .unauthorized:
            return "API key is invalid or expired."
        case .notFound:
            return "Image not found."
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - APIService

/// Centralized Swift actor for teil.ing API v1 GET/PATCH/DELETE endpoints.
///
/// All methods retrieve the API key from KeychainService, attach the X-API-Key header,
/// and map HTTP status codes to typed APIError cases. Upload is handled separately
/// by UploadService to keep the actor boundaries clean.
actor APIService {

    static let shared = APIService()

    private static let baseURL = "https://teil.ing/api/v1"

    private init() {}

    // MARK: - List Images

    /// Returns a paginated list of images owned by the authenticated user.
    func listImages(limit: Int = 20, offset: Int = 0) async throws -> ImageListResponse {
        let url = URL(string: "\(APIService.baseURL)/images?limit=\(limit)&offset=\(offset)")!
        let request = try buildRequest(url: url, method: "GET")
        let data = try await perform(request)
        return try decode(ImageListResponse.self, from: data)
    }

    // MARK: - Get Image Details

    /// Returns full metadata for a single image by its UUID.
    func getImageDetails(id: String) async throws -> ImageResponse {
        let url = URL(string: "\(APIService.baseURL)/images/\(id)")!
        let request = try buildRequest(url: url, method: "GET")
        let data = try await perform(request)
        return try decode(ImageResponse.self, from: data)
    }

    // MARK: - Update Image Settings

    /// Updates settings (password, privacy, maxViews, expiry) for a single image.
    func updateImage(id: String, update: ImageUpdateRequest) async throws {
        let url = URL(string: "\(APIService.baseURL)/images/\(id)")!
        var request = try buildRequest(url: url, method: "PATCH")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        request.httpBody = try encoder.encode(update)
        _ = try await perform(request)
    }

    // MARK: - Delete Image

    /// Deletes an image from both the database and S3 storage (including thumbnail).
    func deleteImage(id: String) async throws {
        let url = URL(string: "\(APIService.baseURL)/images/\(id)")!
        let request = try buildRequest(url: url, method: "DELETE")
        _ = try await perform(request)
    }

    // MARK: - Get Quota

    /// Returns the authenticated user's storage quota and usage.
    func getQuota() async throws -> QuotaResponse {
        let url = URL(string: "\(APIService.baseURL)/quota")!
        let request = try buildRequest(url: url, method: "GET")
        let data = try await perform(request)
        return try decode(QuotaResponse.self, from: data)
    }

    // MARK: - Private: Request Builder

    private func buildRequest(url: URL, method: String) throws -> URLRequest {
        guard let apiKey = KeychainService.shared.apiKey else {
            throw APIError.noAPIKey
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 20
        return request
    }

    // MARK: - Private: Request Performer

    /// Performs the URLRequest and maps HTTP status codes to APIError cases.
    /// Returns the response body data on success (2xx).
    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkError("No internet connection")
            default:
                throw APIError.networkError("Could not reach teil.ing")
            }
        } catch {
            throw APIError.networkError("Could not reach teil.ing")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Unexpected response from teil.ing")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    // MARK: - Private: JSON Decoder

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.networkError("Failed to parse response")
        }
    }
}
