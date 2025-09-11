//
//  RoleUtils.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-11.
//

import Foundation

struct RoleUtils {
    /// Normalizes role names from Riot API to our standard 5 roles
    static func normalizeRole(_ role: String) -> String {
        switch role.uppercased() {
        case "TOP": return "TOP"
        case "JUNGLE": return "JUNGLE"
        case "MIDDLE", "SOLO", "MID": return "MID"
        case "BOTTOM", "DUO", "CARRY", "ADC": return "BOTTOM"
        case "UTILITY", "SUPPORT": return "SUPPORT"
        default: return "TOP" // Fallback to Top
        }
    }
    
    /// Returns the display name for a normalized role
    static func displayName(for role: String) -> String {
        switch role.uppercased() {
        case "TOP": return "Top"
        case "JUNGLE": return "Jungle"
        case "MID": return "Mid"
        case "BOTTOM": return "Bottom"
        case "SUPPORT": return "Support"
        default: return role
        }
    }
    
    /// Returns the icon name for a normalized role
    static func iconName(for role: String) -> String {
        switch role.uppercased() {
        case "TOP": return "RoleTopIcon"
        case "JUNGLE": return "RoleJungleIcon"
        case "MID": return "RoleMidIcon"
        case "BOTTOM": return "RoleAdcIcon"
        case "SUPPORT": return "RoleSupportIcon"
        default: return "RoleTopIcon"
        }
    }
    
    /// Returns the win rate color based on performance
    static func winRateColor(_ winRate: Double) -> String {
        if winRate >= 0.54 {
            return "accent"  // Teal for good performance
        } else if winRate >= 0.5 {
            return "textSecondary"  // Gray for average+ performance
        } else if winRate >= 0.48 {
            return "primary"  // Orange for average performance
        } else {
            return "secondary"  // Red-orange for poor performance
        }
    }
}

// MARK: - Supporting Types

struct RoleStats {
    let role: String
    let winRate: Double
    let totalGames: Int
}
