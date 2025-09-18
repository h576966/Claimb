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
        // This is a placeholder key - you need to get a real API key from https://developer.riotgames.com/
        print("⚠️ WARNING: Using placeholder API key. Get a real key from https://developer.riotgames.com/")
        return "RGAPI-PLACEHOLDER-KEY-REPLACE-WITH-REAL-KEY"
    }
}
