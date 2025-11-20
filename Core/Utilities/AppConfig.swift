//
//  AppConfig.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-28.
//

import Foundation
import UIKit

/// Application configuration from build settings
enum AppConfig {
    private static let fallbackBaseURL = URL(string: "https://invalid.claimb.app")!

    private static func str(_ k: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: k) as? String) ?? ""
    }

    static var baseURL: URL {
        let urlString = str("ClaimbFunctionBaseURL").trimmingCharacters(in: .whitespacesAndNewlines)
        
        #if DEBUG
        ClaimbLogger.debug("Loading base URL configuration", service: "AppConfig", metadata: [
            "urlString": urlString,
            "isEmpty": String(urlString.isEmpty),
            "length": String(urlString.count)
        ])
        #endif

        guard !urlString.isEmpty else {
            reportConfigurationIssue(
                title: "Missing Function URL",
                message:
                    "Set the build setting 'ClaimbFunctionBaseURL' before running the app. Open the project in Xcode and add the URL under Build Settings → User-Defined."
            )
            return fallbackBaseURL
        }

        guard let url = URL(string: urlString) else {
            reportConfigurationIssue(
                title: "Invalid Function URL",
                message:
                    "The value '\(urlString)' is not a valid URL. Update 'ClaimbFunctionBaseURL' in Build Settings."
            )
            return fallbackBaseURL
        }

        #if DEBUG
        ClaimbLogger.debug("Base URL loaded successfully", service: "AppConfig", metadata: ["url": url.absoluteString])
        #endif
        
        return url
    }

    static var anonKey: String {
        let key = str("SupabaseAnonKey")
        return key
    }

    static var appToken: String {
        let token = str("AppSharedToken")
        return token
    }

    /// Adds authentication headers to a URLRequest
    static func addAuthHeaders(_ req: inout URLRequest) {
        req.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.addValue(appToken, forHTTPHeaderField: "X-Claimb-App-Token")
        req.addValue(
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            forHTTPHeaderField: "X-Claimb-Device")

        // Only set essential headers - let URLSession handle HTTP/2+ negotiation
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        // Note: Removed Connection, Accept-Encoding, and User-Agent headers
        // These cause HTTP/2+ compatibility issues with Cloudflare/Supabase
    }

    private static func reportConfigurationIssue(title: String, message: String) {
        ClaimbLogger.error(message, service: "AppConfig")
        AppHealthReporter.report(
            LaunchIssue(
                title: title,
                message: message,
                severity: .critical)
        )
    }
}
