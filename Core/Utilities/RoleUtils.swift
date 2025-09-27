//
//  RoleUtils.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-11.
//

import Foundation

struct RoleUtils {
    private static var seenRoleLogs: Set<String> = []
    /// Normalizes role names from Riot API to our standard 5 roles
    /// Uses Riot's teamPosition field directly (preferred) or falls back to role/lane
    static func normalizeRole(_ role: String, lane: String? = nil, teamPosition: String? = nil) -> String {
        // Use Riot's teamPosition field directly if available
        if let teamPosition = teamPosition, !teamPosition.isEmpty {
            let upperTeamPosition = teamPosition.uppercased()
            switch upperTeamPosition {
            case "TOP": return "TOP"
            case "JUNGLE": return "JUNGLE"
            case "MIDDLE": return "MID"
            case "BOTTOM": return "BOTTOM"
            case "UTILITY": return "SUPPORT"
            default:
                ClaimbLogger.warning(
                    "Unknown teamPosition, excluding game", service: "RoleUtils",
                    metadata: ["teamPosition": teamPosition])
                return "UNKNOWN"  // This will be filtered out
            }
        }

        // Fallback to old logic if teamPosition is not available
        let upperRole = role.uppercased()
        let upperLane = lane?.uppercased() ?? ""

        // Use combination of role and lane for better accuracy
        let result: String

        // Check lane first for more accurate mapping
        switch upperLane {
        case "JUNGLE":
            result = "JUNGLE"
        case "TOP_LANE":
            result = "TOP"
        case "MID_LANE":
            result = "MID"
        case "BOT_LANE":
            // For bot lane, use role to distinguish between ADC and Support
            switch upperRole {
            case "DUO_CARRY", "CARRY", "ADC":
                result = "BOTTOM"
            case "DUO_SUPPORT", "SUPPORT", "UTILITY":
                result = "SUPPORT"
            default:
                result = "BOTTOM"  // Default to ADC for bot lane
            }
        default:
            // Fallback to role-only mapping if lane is unknown
            switch upperRole {
            case "TOP", "TOP_LANE": result = "TOP"
            case "JUNGLE", "JUNGLE_LANE": result = "JUNGLE"
            case "MIDDLE", "SOLO", "MID", "MID_LANE", "MIDDLE_LANE": result = "MID"
            case "BOTTOM", "DUO", "CARRY", "ADC", "BOTTOM_LANE", "DUO_CARRY": result = "BOTTOM"
            case "UTILITY", "SUPPORT", "SUPPORT_LANE", "DUO_SUPPORT": result = "SUPPORT"
            case "NONE":
                result = "JUNGLE"  // NONE typically means Jungle
            default:
                ClaimbLogger.warning(
                    "Unknown role, defaulting to TOP", service: "RoleUtils",
                    metadata: [
                        "role": role,
                        "lane": lane ?? "unknown",
                    ])
                result = "TOP"  // Fallback to Top
            }
        }

        return result
    }

    /// Legacy method for backward compatibility
    static func normalizeRole(_ role: String) -> String {
        return normalizeRole(role, lane: nil)
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

public struct RoleStats {
    public let role: String
    public let winRate: Double
    public let totalGames: Int

    public init(role: String, winRate: Double, totalGames: Int) {
        self.role = role
        self.winRate = winRate
        self.totalGames = totalGames
    }
}
