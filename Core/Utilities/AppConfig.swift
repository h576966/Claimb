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
    private static func str(_ k: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: k) as? String) ?? ""
    }

    static var baseURL: URL {
        let urlString = str("ClaimbFunctionBaseURL")
        NSLog("DEBUG: ClaimbFunctionBaseURL = '\(urlString)'")
        NSLog("DEBUG: urlString.isEmpty = \(urlString.isEmpty)")
        NSLog("DEBUG: urlString.count = \(urlString.count)")

        if urlString.isEmpty {
            fatalError("ClaimbFunctionBaseURL is empty")
        }

        guard let url = URL(string: urlString) else {
            fatalError("ClaimbFunctionBaseURL is not a valid URL. Current value: '\(urlString)'")
        }

        NSLog("DEBUG: URL created successfully: \(url)")
        return url
    }

    static var anonKey: String {
        let key = str("SupabaseAnonKey")
        print("DEBUG: SupabaseAnonKey = '\(key.isEmpty ? "EMPTY" : "\(key.prefix(10))...")'")
        return key
    }

    static var appToken: String {
        let token = str("AppSharedToken")
        print("DEBUG: AppSharedToken = '\(token.isEmpty ? "EMPTY" : "\(token.prefix(10))...")'")
        return token
    }

    /// Adds authentication headers to a URLRequest
    static func addAuthHeaders(_ req: inout URLRequest) {
        req.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.addValue(appToken, forHTTPHeaderField: "X-Claimb-App-Token")
        req.addValue(
            UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            forHTTPHeaderField: "X-Claimb-Device")
    }
}
