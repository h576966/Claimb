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
        URL(string: str("CLAIMB_FUNCTION_BASE_URL"))!
    }
    
    static var anonKey: String { 
        str("SUPABASE_ANON_KEY") 
    }
    
    static var appToken: String { 
        str("APP_SHARED_TOKEN") 
    }
    
    /// Adds authentication headers to a URLRequest
    static func addAuthHeaders(_ req: inout URLRequest) {
        req.addValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.addValue(appToken, forHTTPHeaderField: "X-Claimb-App-Token")
        req.addValue(UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                     forHTTPHeaderField: "X-Claimb-Device")
    }
}
