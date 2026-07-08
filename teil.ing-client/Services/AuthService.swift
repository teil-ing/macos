import AppKit
import CryptoKit
import Foundation

// MARK: - AuthError

enum AuthError: Error, LocalizedError, Sendable {
    case denied
    case cancelled
    case exchangeFailed(String)
    case rateLimited
    case networkError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .denied:
            return "The connection request was denied in the browser."
        case .cancelled:
            return "Sign-in was cancelled."
        case .exchangeFailed(let message):
            return message
        case .rateLimited:
            return "Too many sign-in attempts. Please wait a few minutes and try again."
        case .networkError(let message):
            return message
        case .serverError(let code):
            return "Unexpected server response (\(code)). Try again later."
        }
    }
}

// MARK: - AuthService

/// Browser-based sign-in (connect flow).
///
/// `signInViaBrowser()` opens https://teil.ing/connect in the default
/// browser, where the user signs in with any teil.ing method (email, GitHub,
/// Google) and approves this device. The website then redirects to
/// teiling://connect?code=…&state=…, which macOS delivers to
/// `AppDelegate.application(_:open:)` → `handleCallback(_:)`. The one-time
/// code plus the locally held PKCE verifier are exchanged at
/// POST /api/app/exchange for a device-scoped API key — the durable
/// credential the caller stores in the Keychain. The key never travels
/// through the browser, and a hijacked teiling:// handler can't redeem the
/// code without the verifier.
@MainActor
final class AuthService {

    static let shared = AuthService()
    private init() {}

    private struct PendingFlow {
        let state: String
        let verifier: String
        let continuation: CheckedContinuation<String, any Error>
    }

    private var pending: PendingFlow?

    // MARK: - Flow

    /// Opens the browser handshake and suspends until the callback arrives
    /// and the key exchange completes, or `cancel()` is called.
    /// Returns the raw API key.
    func signInViaBrowser() async throws -> String {
        // A new attempt supersedes a stale one (e.g. the user closed the
        // browser tab and clicked the sign-in button again).
        cancel()

        let verifier = Self.randomBase64URL(byteCount: 32)
        let state = Self.randomBase64URL(byteCount: 24)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))

        var components = URLComponents(string: TeilAPI.connect)!
        components.queryItems = [
            URLQueryItem(name: "device", value: deviceName()),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "challenge", value: challenge),
        ]
        guard let url = components.url else {
            throw AuthError.networkError("Could not build the sign-in URL.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending = PendingFlow(state: state, verifier: verifier, continuation: continuation)
            NSWorkspace.shared.open(url)
        }
    }

    /// Cancels a waiting sign-in (no-op when idle).
    func cancel() {
        pending?.continuation.resume(throwing: AuthError.cancelled)
        pending = nil
    }

    /// Routes a teiling:// callback from the system. Returns true when the
    /// URL belonged to the waiting sign-in and was consumed.
    @discardableResult
    func handleCallback(_ url: URL) -> Bool {
        guard url.scheme == "teiling", url.host() == "connect", let flow = pending else {
            return false
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }

        // A mismatched state is a stray or forged callback — keep waiting.
        guard value("state") == flow.state else { return false }
        pending = nil

        if value("error") != nil {
            flow.continuation.resume(throwing: AuthError.denied)
            return true
        }
        guard let code = value("code"), !code.isEmpty else {
            flow.continuation.resume(
                throwing: AuthError.exchangeFailed("The sign-in callback was incomplete. Please try again.")
            )
            return true
        }

        Task {
            do {
                let key = try await Self.exchange(code: code, verifier: flow.verifier)
                flow.continuation.resume(returning: key)
            } catch {
                flow.continuation.resume(throwing: error)
            }
        }
        return true
    }

    // MARK: - Key Exchange

    private static func exchange(code: String, verifier: String) async throws -> String {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)

        guard let url = URL(string: TeilAPI.appExchange) else {
            throw AuthError.networkError("Could not build the exchange URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["code": code, "verifier": verifier])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let data: Data
        let status: Int
        do {
            let (body, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.networkError("Unexpected response from teil.ing. Please try again.")
            }
            data = body
            status = httpResponse.statusCode
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw AuthError.networkError("No internet connection. Please connect and try again.")
            default:
                throw AuthError.networkError("Could not reach teil.ing. Check your connection and try again.")
            }
        }

        struct ExchangeResponse: Decodable { let key: String }
        struct ExchangeError: Decodable { let error: String }

        switch status {
        case 201:
            guard let response = try? JSONDecoder().decode(ExchangeResponse.self, from: data) else {
                throw AuthError.serverError(status)
            }
            return response.key
        case 429:
            throw AuthError.rateLimited
        case 400:
            let message = (try? JSONDecoder().decode(ExchangeError.self, from: data))?.error
            throw AuthError.exchangeFailed(message ?? "Sign-in could not be completed. Please try again.")
        default:
            throw AuthError.serverError(status)
        }
    }

    // MARK: - Helpers

    private static func randomBase64URL(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func deviceName() -> String {
        Host.current().localizedName ?? "My Mac"
    }
}
