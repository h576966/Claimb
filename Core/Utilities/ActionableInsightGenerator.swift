//
//  ActionableInsightGenerator.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-28.
//

import Foundation

/// Generates actionable insights for KPIs based on user goals and focus type
public struct ActionableInsightGenerator {
    
    // MARK: - Main Insight Generation
    
    /// Generates a 1-2 sentence actionable insight for a KPI
    public static func generateInsight(
        for kpi: KPIMetric, 
        focusType: FocusType,
        learningContext: String? = nil
    ) -> String {
        
        // Get base insight template based on KPI and performance level
        let baseInsight = getBaseInsight(for: kpi)
        
        // Customize based on focus type
        let customizedInsight = customizeForFocusType(
            baseInsight: baseInsight,
            kpi: kpi,
            focusType: focusType,
            learningContext: learningContext
        )
        
        return customizedInsight
    }
    
    /// Generates insight for the user's current goal
    public static func generateGoalInsight() -> String? {
        guard let goalContext = GoalContext.current() else { return nil }
        
        // This would need access to current KPI metrics to provide specific insight
        // For now, return a general goal-focused message
        let daysSinceGoal = Calendar.current.dateComponents([.day], from: goalContext.goalSetDate, to: Date()).day ?? 0
        
        if daysSinceGoal == 0 {
            return "Goal set today: Focus on \(goalContext.primaryKPI) improvement during your next games."
        } else if daysSinceGoal <= 3 {
            return "Day \(daysSinceGoal) of your \(goalContext.primaryKPI) focus - stay consistent with your improvement plan."
        } else {
            return "Week \(daysSinceGoal / 7 + 1) of your \(goalContext.primaryKPI) goal - review your progress and adjust if needed."
        }
    }
    
    // MARK: - Base Insight Templates
    
    private static func getBaseInsight(for kpi: KPIMetric) -> String {
        switch kpi.metric {
        case "deaths_per_game":
            return getDeathsInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "cs_per_min":
            return getCSInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "vision_score_per_min":
            return getVisionInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "kill_participation_pct":
            return getKillParticipationInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "objective_participation_pct":
            return getObjectiveInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "team_damage_pct":
            return getTeamDamageInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        case "damage_taken_share_pct":
            return getDamageTakenInsight(performanceLevel: kpi.performanceLevel, currentValue: kpi.value)
            
        default:
            return "Focus on improving this metric through consistent practice and game awareness."
        }
    }
    
    // MARK: - KPI-Specific Insights
    
    private static func getDeathsInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Prioritize positioning and map awareness. Avoid risky plays and focus on staying alive to impact team fights."
        case .needsImprovement:
            return "Work on positioning in team fights. Consider safer farming patterns and ward key areas before pushing."
        case .good:
            return "Maintain your current positioning awareness. Look for opportunities to take calculated risks for game impact."
        case .excellent:
            return "Excellent death control! Use your positioning advantage to enable more aggressive plays when ahead."
        }
    }
    
    private static func getCSInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Focus on last-hitting fundamentals. Practice in training tool and prioritize farming over trading early game."
        case .needsImprovement:
            return "Improve wave management and back timings. Focus on not missing CS when roaming or fighting."
        case .good:
            return "Good CS numbers! Work on maintaining farm while increasing map presence and team fight participation."
        case .excellent:
            return "Excellent farming! Use your gold advantage to pressure objectives and help your team."
        }
    }
    
    private static func getVisionInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Buy more control wards and use trinkets actively. Ward river bushes and objectives before they spawn."
        case .needsImprovement:
            return "Improve vision timing around objectives. Clear enemy wards and establish vision control before fights."
        case .good:
            return "Good vision habits! Focus on deeper wards and coordinating vision control with your team."
        case .excellent:
            return "Excellent vision control! Use your map knowledge to shot-call and guide team rotations."
        }
    }
    
    private static func getKillParticipationInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Join more team fights and skirmishes. Use TP/mobility to arrive at fights faster."
        case .needsImprovement:
            return "Improve fight timing and positioning. Look for flanks and focus priority targets in team fights."
        case .good:
            return "Good team fight presence! Work on fight initiation and target selection to maximize impact."
        case .excellent:
            return "Excellent team fighting! Use your impact to shot-call and coordinate team strategies."
        }
    }
    
    private static func getObjectiveInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Focus on dragons, heralds, and baron. Group with team for objective fights and establish vision first."
        case .needsImprovement:
            return "Improve objective timing and preparation. Clear vision and position correctly before starting objectives."
        case .good:
            return "Good objective focus! Work on objective trading and timing to maximize team advantages."
        case .excellent:
            return "Excellent objective play! Use your game sense to shot-call objective priorities and rotations."
        }
    }
    
    private static func getTeamDamageInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Focus on positioning to deal consistent damage in fights. Build damage items and avoid being zoned out."
        case .needsImprovement:
            return "Improve fight positioning and target prioritization. Stay alive longer to increase damage output."
        case .good:
            return "Good damage output! Work on burst timing and focus fire coordination with your team."
        case .excellent:
            return "Excellent damage dealing! Use your DPS advantage to pressure objectives and team fights."
        }
    }
    
    private static func getDamageTakenInsight(performanceLevel: Baseline.PerformanceLevel, currentValue: String) -> String {
        switch performanceLevel {
        case .poor:
            return "Improve front-line positioning and engage timing. Build defensively and communicate with your team."
        case .needsImprovement:
            return "Work on absorbing more damage for your team. Position to protect carries and draw enemy focus."
        case .good:
            return "Good damage absorption! Focus on timing your engages when your team can follow up."
        case .excellent:
            return "Excellent tanking! Use your durability to make space for carries and control team fight positioning."
        }
    }
    
    // MARK: - Focus Type Customization
    
    private static func customizeForFocusType(
        baseInsight: String,
        kpi: KPIMetric,
        focusType: FocusType,
        learningContext: String?
    ) -> String {
        
        switch focusType {
        case .climbing:
            return customizeForClimbing(baseInsight: baseInsight, kpi: kpi)
        case .learning:
            return customizeForLearning(baseInsight: baseInsight, kpi: kpi, context: learningContext)
        }
    }
    
    private static func customizeForClimbing(baseInsight: String, kpi: KPIMetric) -> String {
        // Add rank-focused context
        let climbingContext = getClimbingContext(for: kpi.performanceLevel)
        return "\(baseInsight) \(climbingContext)"
    }
    
    private static func customizeForLearning(baseInsight: String, kpi: KPIMetric, context: String?) -> String {
        // Add learning-focused context
        var learningInsight = baseInsight
        
        if let context = context, !context.isEmpty {
            learningInsight += " Focus on \(context) fundamentals while practicing this."
        } else {
            learningInsight += " Take time to practice this in normals before bringing it to ranked."
        }
        
        return learningInsight
    }
    
    private static func getClimbingContext(for performanceLevel: Baseline.PerformanceLevel) -> String {
        switch performanceLevel {
        case .poor:
            return "This is holding back your climb - prioritize fixing this first."
        case .needsImprovement:
            return "Improving this will directly impact your win rate and LP gains."
        case .good:
            return "Maintaining this level will support consistent climbing."
        case .excellent:
            return "This strength can carry you to higher ranks."
        }
    }
    
    // MARK: - Utility Methods
    
    /// Checks if an insight should be shown for a KPI
    public static func shouldShowInsight(for kpi: KPIMetric) -> Bool {
        // Only show insights for KPIs that need improvement or are the current goal
        let needsImprovement = kpi.performanceLevel == .poor || kpi.performanceLevel == .needsImprovement
        let isCurrentGoal = UserGoals.getPrimaryGoal() == kpi.metric
        
        return needsImprovement || isCurrentGoal
    }
    
    /// Gets a short motivational message based on goal progress
    public static func getProgressMessage(daysSinceGoal: Int) -> String {
        switch daysSinceGoal {
        case 0:
            return "Goal set! Let's get started 🎯"
        case 1...3:
            return "Stay focused - early days are crucial 💪"
        case 4...7:
            return "Good progress this week 📈"
        default:
            return "Time for a goal check-in 📅"
        }
    }
}
