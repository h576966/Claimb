import Foundation

/// Manages API keys in a centralized way
enum APIKeyManager {
    /// Gets the App Shared Token for Supabase edge function authentication
    static var appSharedToken: String {
        // 1. Try to get from build settings (Info.plist)
        if let token = Bundle.main.object(forInfoDictionaryKey: "APP_SHARED_TOKEN") as? String,
            !token.isEmpty
        {
            return token
        }

        // 2. Try to get from environment variables
        if let token = ProcessInfo.processInfo.environment["APP_SHARED_TOKEN"], !token.isEmpty {
            return token
        }

        // 3. Try to get from UserDefaults (for development/testing)
        if let token = UserDefaults.standard.string(forKey: "APP_SHARED_TOKEN"), !token.isEmpty {
            return token
        }

        // 4. If no token found, return placeholder that will cause clear error
        return "PLACEHOLDER_APP_SHARED_TOKEN"
    }

    /// Check if we have a valid App Shared Token
    static var hasValidAppSharedToken: Bool {
        return appSharedToken != "PLACEHOLDER_APP_SHARED_TOKEN" && !appSharedToken.isEmpty
    }

    // MARK: - Legacy Methods (for backward compatibility during transition)
    
    /// Legacy method - now returns placeholder since we use Proxy service
    static var riotAPIKey: String {
        return "PLACEHOLDER_API_KEY"
    }

    /// Legacy method - now returns placeholder since we use Proxy service
    static var openAIAPIKey: String {
        return "PLACEHOLDER_OPENAI_API_KEY"
    }

    /// Legacy method - now checks App Shared Token
    static var hasValidAPIKey: Bool {
        return hasValidAppSharedToken
    }

    /// Legacy method - now returns false since we use Proxy service
    static var hasValidRiotAPIKey: Bool {
        return false
    }

    /// Legacy method - now returns false since we use Proxy service
    static var hasValidOpenAIAPIKey: Bool {
        return false
    }
}
