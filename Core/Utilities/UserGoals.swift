//
//  UserGoals.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// User focus type for goals system
public enum FocusType: String, CaseIterable {
    case climbing = "Climbing"
    case learning = "Learning"
    
    public var displayName: String {
        return self.rawValue
    }
}

/// Manages user goals and preferences using UserDefaults for simplicity
public struct UserGoals {
    
    // MARK: - Goal Setters
    
    /// Sets the primary KPI goal that the user wants to focus on
    public static func setPrimaryGoal(_ kpiMetric: String) {
        UserDefaults.standard.set(kpiMetric, forKey: AppConstants.UserDefaultsKeys.primaryGoalKPI)
        ClaimbLogger.info("Primary goal set", service: "UserGoals", metadata: ["kpi": kpiMetric])
    }
    
    /// Sets the focus type (climbing vs learning)
    public static func setFocusType(_ type: FocusType) {
        UserDefaults.standard.set(type.rawValue, forKey: AppConstants.UserDefaultsKeys.focusType)
        ClaimbLogger.info("Focus type set", service: "UserGoals", metadata: ["type": type.rawValue])
    }
    
    /// Sets learning context (champion and/or role when in learning mode)
    public static func setLearningContext(champion: String?, role: String?) {
        if let champion = champion {
            UserDefaults.standard.set(champion, forKey: AppConstants.UserDefaultsKeys.learningChampion)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.learningChampion)
        }
        
        if let role = role {
            UserDefaults.standard.set(role, forKey: AppConstants.UserDefaultsKeys.learningRole)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.learningRole)
        }
        
        ClaimbLogger.info("Learning context set", service: "UserGoals", metadata: [
            "champion": champion ?? "none",
            "role": role ?? "none"
        ])
    }
    
    /// Sets the goal date to track when the goal was last updated
    public static func setGoalDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: AppConstants.UserDefaultsKeys.goalSetDate)
        ClaimbLogger.debug("Goal date set", service: "UserGoals", metadata: [
            "date": DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        ])
    }
    
    // MARK: - Goal Getters
    
    /// Gets the current primary KPI goal
    public static func getPrimaryGoal() -> String? {
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.primaryGoalKPI)
    }
    
    /// Gets the current focus type, defaults to climbing if not set
    public static func getFocusType() -> FocusType {
        guard let rawValue = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.focusType),
              let focusType = FocusType(rawValue: rawValue) else {
            return .climbing // Default to climbing focus
        }
        return focusType
    }
    
    /// Gets the learning champion (only relevant when focus type is learning)
    public static func getLearningChampion() -> String? {
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.learningChampion)
    }
    
    /// Gets the learning role (only relevant when focus type is learning)
    public static func getLearningRole() -> String? {
        return UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKeys.learningRole)
    }
    
    /// Gets the date when the goal was last set
    public static func getGoalDate() -> Date? {
        return UserDefaults.standard.object(forKey: AppConstants.UserDefaultsKeys.goalSetDate) as? Date
    }
    
    // MARK: - Goal State Checks
    
    /// Checks if the user has an active goal set
    public static func hasActiveGoal() -> Bool {
        return getPrimaryGoal() != nil && getGoalDate() != nil
    }
    
    /// Checks if the goal needs updating (7+ days since last goal)
    public static func needsGoalUpdate() -> Bool {
        guard let lastGoalDate = getGoalDate() else { return true }
        let daysSinceGoal = Calendar.current.dateComponents([.day], from: lastGoalDate, to: Date()).day ?? 0
        return daysSinceGoal >= 7
    }
    
    /// Checks if we should show the Friday modal for weekly goal updates
    public static func shouldShowFridayModal() -> Bool {
        // Always show if no goal is set
        guard hasActiveGoal() else { return true }
        
        // Check if it's been 7+ days since last goal update
        guard needsGoalUpdate() else { return false }
        
        // Check if it's Friday or after Friday (weekend users)
        let today = Calendar.current.component(.weekday, from: Date())
        let isFridayOrWeekend = today >= 6 // Friday (6), Saturday (7), Sunday (1)
        
        return isFridayOrWeekend
    }
    
    /// Checks if this is the first time setting goals (for onboarding)
    public static func isFirstTimeGoalSetup() -> Bool {
        return getGoalDate() == nil
    }
    
    // MARK: - Goal Operations
    
    /// Sets a complete goal with all context
    public static func setCompleteGoal(
        kpiMetric: String,
        focusType: FocusType,
        learningChampion: String? = nil,
        learningRole: String? = nil
    ) {
        setPrimaryGoal(kpiMetric)
        setFocusType(focusType) 
        setLearningContext(champion: learningChampion, role: learningRole)
        setGoalDate(Date())
        
        ClaimbLogger.info("Complete goal set", service: "UserGoals", metadata: [
            "kpi": kpiMetric,
            "focusType": focusType.rawValue,
            "hasLearningContext": (learningChampion != nil || learningRole != nil) ? "true" : "false"
        ])
    }
    
    /// Clears all goal data
    public static func clearGoals() {
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.primaryGoalKPI)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.focusType)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.learningChampion)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.learningRole)
        UserDefaults.standard.removeObject(forKey: AppConstants.UserDefaultsKeys.goalSetDate)
        
        ClaimbLogger.info("All goals cleared", service: "UserGoals")
    }
    
    /// Gets a summary of current goals for display
    public static func getCurrentGoalSummary() -> String {
        guard let primaryGoal = getPrimaryGoal() else {
            return "No goal set"
        }
        
        let focusType = getFocusType()
        var summary = "Focus: \(primaryGoal) (\(focusType.displayName))"
        
        if focusType == .learning {
            let learningDetails = [getLearningChampion(), getLearningRole()]
                .compactMap { $0 }
                .joined(separator: " / ")
            
            if !learningDetails.isEmpty {
                summary += " - \(learningDetails)"
            }
        }
        
        return summary
    }
}

// MARK: - Goal Context for AI Coaching

/// Context information about user goals for AI coaching prompts
public struct GoalContext {
    public let primaryKPI: String
    public let focusType: FocusType
    public let learningChampion: String?
    public let learningRole: String?
    public let goalSetDate: Date
    
    public init(
        primaryKPI: String,
        focusType: FocusType,
        learningChampion: String? = nil,
        learningRole: String? = nil,
        goalSetDate: Date
    ) {
        self.primaryKPI = primaryKPI
        self.focusType = focusType
        self.learningChampion = learningChampion
        self.learningRole = learningRole
        self.goalSetDate = goalSetDate
    }
    
    /// Creates goal context from current UserGoals state
    public static func current() -> GoalContext? {
        guard let primaryKPI = UserGoals.getPrimaryGoal(),
              let goalDate = UserGoals.getGoalDate() else {
            return nil
        }
        
        return GoalContext(
            primaryKPI: primaryKPI,
            focusType: UserGoals.getFocusType(),
            learningChampion: UserGoals.getLearningChampion(),
            learningRole: UserGoals.getLearningRole(),
            goalSetDate: goalDate
        )
    }
    
    /// Formatted string for use in AI prompts
    public var promptDescription: String {
        var description = "PLAYER FOCUS: \(primaryKPI) improvement | Context: \(focusType.displayName)"
        
        if focusType == .learning {
            let learningDetails = [learningChampion, learningRole]
                .compactMap { $0 }
                .joined(separator: " / ")
            
            if !learningDetails.isEmpty {
                description += " (\(learningDetails))"
            }
        }
        
        let daysSinceGoal = Calendar.current.dateComponents([.day], from: goalSetDate, to: Date()).day ?? 0
        description += " | Goal set \(daysSinceGoal) days ago"
        
        return description
    }
}
