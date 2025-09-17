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
                return "Server error (\(code)): Please try again later"
            }
        }
        
        if let dataError = error as? DataManagerError {
            switch dataError {
            case .missingResource(let resource):
                return "Missing resource: \(resource) not found"
            case .databaseError(let message):
                return "Database error: \(message)"
            case .invalidData(let message):
                return "Invalid data: \(message)"
            }
        }
        
        // Generic error handling
        return "An unexpected error occurred: \(error.localizedDescription)"
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
