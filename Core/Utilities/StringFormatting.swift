//
//  StringFormatting.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Extension providing consistent string formatting methods for numeric values
public extension Double {
    
    /// Formats as a decimal with one decimal place (e.g., "5.2")
    var oneDecimal: String {
        return String(format: "%.1f", self)
    }
    
    /// Formats as a decimal with two decimal places (e.g., "5.23") 
    var twoDecimals: String {
        return String(format: "%.2f", self)
    }
    
    /// Formats as a percentage with no decimal places (e.g., "52%")
    var asPercentage: String {
        return String(format: "%.0f%%", self * 100)
    }
    
    /// Formats as a whole number with no decimal places (e.g., "5")
    var asWholeNumber: String {
        return String(format: "%.0f", self)
    }
    
    /// Formats as a decimal with three decimal places for precise values (e.g., "5.235")
    var threeDecimals: String {
        return String(format: "%.3f", self)
    }
}

public extension Int {
    
    /// Converts to Double and formats as percentage (e.g., 52 -> "52%")
    var asPercentage: String {
        return String(format: "%.0f%%", Double(self))
    }
}

/// Static formatting utility methods for consistency across the app
public enum StringFormatter {
    
    /// Formats a KPI metric value based on its type
    public static func formatKPIValue(_ value: Double, for metric: String) -> String {
        switch metric {
        case "kill_participation_pct", "team_damage_pct", "objective_participation_pct", "damage_taken_share_pct":
            return value.asPercentage
        case "primary_role_consistency":
            return value.asWholeNumber + "%"
        case "champion_pool_size":
            return value.asWholeNumber
        case "cs_per_min", "vision_score_per_min", "deaths_per_game":
            return value.oneDecimal
        default:
            return value.oneDecimal
        }
    }
    
    /// Formats baseline values for display
    public static func formatBaseline(_ value: Double) -> String {
        return value.threeDecimals
    }
    
    /// Formats win rate for display
    public static func formatWinRate(_ winRate: Double) -> String {
        return (winRate * 100).asWholeNumber + "%"
    }
}
