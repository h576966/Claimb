import Foundation

/// Manages API keys in a centralized way
enum APIKeyManager {
    /// Gets the Riot API key from build settings or environment
    static var riotAPIKey: String {
        // Try to get from build settings first
        if let key = Bundle.main.object(forInfoDictionaryKey: "RIOT_API_KEY") as? String,
            !key.isEmpty
        {
            return key
        }

        // Try to get from environment variables
        if let key = ProcessInfo.processInfo.environment["RIOT_API_KEY"], !key.isEmpty {
            return key
        }

        // Try to get from UserDefaults (for development/testing)
        if let key = UserDefaults.standard.string(forKey: "RIOT_API_KEY"), !key.isEmpty {
            return key
        }

        // Fallback to placeholder key for development
        // Set your API key programmatically using APIKeyManager.setRiotAPIKey() or environment variables
        return "RGAPI-PLACEHOLDER-KEY-REPLACE-WITH-REAL-KEY"
    }

    /// Sets the Riot API key for development/testing
    static func setRiotAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "RIOT_API_KEY")
        print("✅ API key set successfully")
    }
}
