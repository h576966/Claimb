import Foundation

/// Manages API keys in a centralized way
enum APIKeyManager {
    /// Gets the Riot API key from build settings or environment
    static var riotAPIKey: String {
        // Try to get from build settings first
        if let key = Bundle.main.object(forInfoDictionaryKey: "RIOT_API_KEY") as? String, !key.isEmpty {
            return key
        }
        
        // Fallback to hardcoded key for development
        // TODO: Remove this when proper build configuration is set up
        return "RGAPI-2133e577-bec8-433b-b519-b3ba66331263"
    }
}
