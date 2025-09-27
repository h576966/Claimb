import Foundation

/// Manages API keys in a centralized way
enum APIKeyManager {
    /// Gets the Riot API key from build settings or environment
    static var riotAPIKey: String {
        // 1. Try to get from build settings (Info.plist)
        if let key = Bundle.main.object(forInfoDictionaryKey: "RIOT_API_KEY") as? String,
            !key.isEmpty
        {
            return key
        }

        // 2. Try to get from environment variables
        if let key = ProcessInfo.processInfo.environment["RIOT_API_KEY"], !key.isEmpty {
            return key
        }

        // 3. Try to get from UserDefaults (for development/testing)
        if let key = UserDefaults.standard.string(forKey: "RIOT_API_KEY"), !key.isEmpty {
            return key
        }

        // 4. If no key found, return placeholder that will cause clear error
        return "PLACEHOLDER_API_KEY"
    }

    /// Gets the OpenAI API key from build settings or environment
    static var openAIAPIKey: String {
        // 1. Try to get from build settings (Info.plist)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
            !key.isEmpty
        {
            return key
        }

        // 2. Try to get from environment variables
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }

        // 3. Try to get from UserDefaults (for development/testing)
        if let key = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !key.isEmpty {
            return key
        }

        // 4. If no key found, return placeholder that will cause clear error
        return "PLACEHOLDER_OPENAI_API_KEY"
    }

    /// Check if we have a valid Riot API key
    static var hasValidRiotAPIKey: Bool {
        return riotAPIKey != "PLACEHOLDER_API_KEY" && !riotAPIKey.isEmpty
    }

    /// Check if we have a valid OpenAI API key
    static var hasValidOpenAIAPIKey: Bool {
        return openAIAPIKey != "PLACEHOLDER_OPENAI_API_KEY" && !openAIAPIKey.isEmpty
    }

    /// Check if we have a valid API key (legacy method for backward compatibility)
    static var hasValidAPIKey: Bool {
        return hasValidRiotAPIKey
    }
}
