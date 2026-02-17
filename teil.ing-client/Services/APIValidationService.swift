import Foundation

// MARK: - ValidationResult

enum ValidationResult: Sendable {
    case valid
    case invalidKey
    case networkError(String)
    case serverError(Int)
}

// MARK: - APIValidationService

enum APIValidationService {

    static let validationURL = URL(string: "https://teil.ing/api/v1/images")!

    static func validate(apiKey: String) async -> ValidationResult {
        var request = URLRequest(url: validationURL)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError("Unexpected response from teil.ing. Please try again.")
            }

            switch httpResponse.statusCode {
            case 200:
                return .valid
            case 401, 403:
                return .invalidKey
            default:
                return .serverError(httpResponse.statusCode)
            }
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError("No internet connection. Please connect and try again.")
            default:
                return .networkError("Could not reach teil.ing. Check your connection and try again.")
            }
        } catch {
            return .networkError("Could not reach teil.ing. Check your connection and try again.")
        }
    }
}
