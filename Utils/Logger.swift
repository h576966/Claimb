//
//  Logger.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import os.log

/// Centralized logging system for Claimb
public struct ClaimbLogger {
    private static let logger = Logger(subsystem: "com.claimb.app", category: "general")
    
    // MARK: - Log Levels
    
    /// Debug level logging (development only)
    public static func debug(_ message: String, service: String = "App", metadata: [String: String] = [:]) {
        #if DEBUG
        let metadataString = metadata.isEmpty ? "" : " | \(metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.debug("[\(service)] \(message)\(metadataString)")
        #endif
    }
    
    /// Info level logging
    public static func info(_ message: String, service: String = "App", metadata: [String: String] = [:]) {
        let metadataString = metadata.isEmpty ? "" : " | \(metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.info("[\(service)] \(message)\(metadataString)")
    }
    
    /// Warning level logging
    public static func warning(_ message: String, service: String = "App", metadata: [String: String] = [:]) {
        let metadataString = metadata.isEmpty ? "" : " | \(metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.warning("[\(service)] \(message)\(metadataString)")
    }
    
    /// Error level logging
    public static func error(_ message: String, service: String = "App", error: Error? = nil, metadata: [String: String] = [:]) {
        var allMetadata = metadata
        if let error = error {
            allMetadata["error"] = error.localizedDescription
            allMetadata["errorType"] = String(describing: type(of: error))
        }
        let metadataString = allMetadata.isEmpty ? "" : " | \(allMetadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        logger.error("[\(service)] \(message)\(metadataString)")
    }
    
    // MARK: - Convenience Methods
    
    /// Log API requests
    public static func apiRequest(_ endpoint: String, method: String = "GET", service: String = "API") {
        debug("\(method) \(endpoint)", service: service, metadata: [
            "endpoint": endpoint,
            "method": method
        ])
    }
    
    /// Log API responses
    public static func apiResponse(_ endpoint: String, statusCode: Int, service: String = "API") {
        let level = statusCode >= 400 ? "error" : "info"
        let message = "\(endpoint) -> \(statusCode)"
        
        if level == "error" {
            error(message, service: service, metadata: [
                "endpoint": endpoint,
                "statusCode": String(statusCode)
            ])
        } else {
            info(message, service: service, metadata: [
                "endpoint": endpoint,
                "statusCode": String(statusCode)
            ])
        }
    }
    
    /// Log data operations
    public static func dataOperation(_ operation: String, count: Int? = nil, service: String = "DataManager") {
        var metadata: [String: String] = ["operation": operation]
        if let count = count {
            metadata["count"] = String(count)
        }
        info("\(operation)\(count != nil ? " (\(count!) items)" : "")", service: service, metadata: metadata)
    }
    
    /// Log user actions
    public static func userAction(_ action: String, service: String = "UserSession") {
        info("User action: \(action)", service: service)
    }
    
    /// Log performance metrics
    public static func performance(_ metric: String, value: Double, service: String = "Performance") {
        debug("\(metric): \(String(format: "%.2f", value))", service: service, metadata: [
            "metric": metric,
            "value": String(format: "%.2f", value)
        ])
    }
    
    /// Log cache operations
    public static func cache(_ operation: String, key: String? = nil, service: String = "Cache") {
        var metadata: [String: String] = ["operation": operation]
        if let key = key {
            metadata["key"] = key
        }
        debug("Cache \(operation)\(key != nil ? " for \(key!)" : "")", service: service, metadata: metadata)
    }
}

