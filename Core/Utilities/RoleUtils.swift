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
    /// Uses Riot's teamPosition field directly - excludes games with missing teamPosition
    static func normalizeRole(teamPosition: String?) -> String {
        // Use Riot's teamPosition field directly - no fallback logic
        guard let teamPosition = teamPosition, !teamPosition.isEmpty else {
            ClaimbLogger.warning(
                "Missing teamPosition, excluding game", service: "RoleUtils",
                metadata: ["teamPosition": teamPosition ?? "nil"]
            )
            return "UNKNOWN"  // This will be filtered out
        }

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
                metadata: ["teamPosition": teamPosition]
            )
            return "UNKNOWN"  // This will be filtered out
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
