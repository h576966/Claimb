import Foundation

/// Provides consistent error handling and user-friendly error messages
enum ErrorHandler {
    /// Converts technical errors to user-friendly messages
    static func userFriendlyMessage(for error: Error) -> String {
        if let riotError = error as? RiotAPIError {
            switch riotError {
            case .invalidURL:
                return "Invalid URL: Please check your configuration"
            case .noData:
                return "No data received: Please try again"
            case .networkError(_):
                return "Network error: Please check your internet connection"
            case .decodingError(_):
                return "Data error: Unable to process server response"
            case .rateLimitExceeded:
                return "Rate limit exceeded: Please wait a moment and try again"
            case .unauthorized:
                return "Authentication error: Please check your credentials"
            case .notFound:
                return "Summoner not found: Please check your username and region"
            case .serverError(let code):
                if code == 400 {
                    return
                        "API configuration error: Please check your API key at https://developer.riotgames.com/"
                }
                return "Server error (\(code)): Please try again later"
            }
        }

        if let dataError = error as? DataManagerError {
            switch dataError {
            case .notAvailable:
                return "Data not available. Please try refreshing."
            case .missingResource(let resource):
                return "Cannot find \(resource). Please refresh your data."
            case .databaseError:
                return "Database error. Try restarting the app."
            case .invalidData:
                return "Invalid data received. Please try again."
            }
        }

        if let openAIError = error as? OpenAIError {
            switch openAIError {
            case .invalidAPIKey:
                return "AI features are not configured properly. Please contact support."
            case .invalidResponse:
                return "AI service returned an invalid response. Please try again."
            case .httpError(let code) where code == 429:
                return "AI service rate limit reached. Please wait a moment and try again."
            case .httpError(let code) where code >= 500:
                return "AI service is temporarily unavailable. Please try again later."
            case .httpError:
                return "AI service error. Please try again."
            case .apiError:
                return "AI analysis failed. Please try again later."
            case .networkError:
                return "Network error connecting to AI service. Check your connection."
            }
        }

        if let proxyError = error as? ProxyError {
            switch proxyError {
            case .invalidResponse:
                return "Invalid server response. Please try again."
            case .httpError(let code) where code == 429:
                return "Too many requests. Please wait a moment and try again."
            case .httpError(let code) where code >= 500:
                return "Server is temporarily unavailable. Please try again later."
            case .httpError:
                return "Server error. Please try again."
            case .decodingError:
                return "Unable to process server response. Please try again."
            case .encodingError:
                return "Unable to send request. Please try again."
            case .networkError:
                return "Network error. Please check your connection."
            }
        }

        if let dataDragonError = error as? DataDragonError {
            switch dataDragonError {
            case .invalidURL:
                return "Configuration error. Please restart the app."
            case .noVersionsAvailable:
                return "Cannot load game version data. Check your connection."
            case .noChampionsAvailable:
                return "Champion data unavailable. Please try again."
            case .championNotFound:
                return "Champion not found. Please refresh your data."
            case .networkError:
                return "Network error loading game data. Check your connection."
            case .decodingError:
                return "Unable to process game data. Please try again."
            }
        }

        if let sessionError = error as? UserSessionError {
            switch sessionError {
            case .failedToRecreateSummoner:
                return "Cannot restore your session. Please log in again."
            }
        }

        // Generic error handling
        return "Something went wrong. Please try again."
    }

    /// Logs errors for debugging with structured logging
    static func logError(_ error: Error, context: String, metadata: [String: String] = [:]) {
        ClaimbLogger.error("Error occurred", service: context, error: error, metadata: metadata)
    }

    /// Logs warnings with structured logging
    static func logWarning(_ message: String, context: String, metadata: [String: String] = [:]) {
        ClaimbLogger.warning(message, service: context, metadata: metadata)
    }

    /// Logs info with structured logging
    static func logInfo(_ message: String, context: String, metadata: [String: String] = [:]) {
        ClaimbLogger.info(message, service: context, metadata: metadata)
    }
}
