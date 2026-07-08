import Foundation

// MARK: - TeilAPI

/// Single source of truth for the teil.ing host. All services build their
/// endpoints from these constants.
enum TeilAPI {
    /// Debug builds honor a host override for testing against a local dev
    /// server: `defaults write ing.teil.client TeilHost http://localhost:4321`
    /// (delete the key to return to production).
    static let host: String = {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "TeilHost"),
           !override.isEmpty {
            return override
        }
        #endif
        return "https://teil.ing"
    }()
    static let v1 = "\(host)/api/v1"
    static let auth = "\(host)/api/auth"
    /// Browser page where the user approves connecting this device.
    static let connect = "\(host)/connect"
    /// Endpoint where a one-time grant code is redeemed for an API key.
    static let appExchange = "\(host)/api/app/exchange"
}
