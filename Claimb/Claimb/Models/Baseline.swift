//
//  Baseline.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import Foundation
import SwiftData

@Model
public class Baseline {
    @Attribute(.unique) public var id: String
    public var role: String
    public var classTag: String
    public var metric: String
    public var mean: Double
    public var median: Double
    public var p40: Double
    public var p60: Double
    public var lastUpdated: Date
    
    public init(role: String, classTag: String, metric: String, mean: Double, median: Double, p40: Double, p60: Double) {
        self.id = "\(role)_\(classTag)_\(metric)"
        self.role = role
        self.classTag = classTag
        self.metric = metric
        self.mean = mean
        self.median = median
        self.p40 = p40
        self.p60 = p60
        self.lastUpdated = Date()
    }
    
    // Get the "good" performance range (P40-P60)
    public var goodRange: ClosedRange<Double> {
        return p40...p60
    }
    
    // Check if value is within "good" range
    public func isGoodPerformance(_ value: Double) -> Bool {
        return goodRange.contains(value)
    }
    
    // Check if value is excellent (above P60)
    public func isExcellentPerformance(_ value: Double) -> Bool {
        return value >= p60
    }
    
    // Check if value needs improvement (below P40)
    public func needsImprovement(_ value: Double) -> Bool {
        return value < p40
    }
    
    // Get performance level for a value
    public func getPerformanceLevel(_ value: Double) -> PerformanceLevel {
        if isExcellentPerformance(value) {
            return .excellent
        } else if isGoodPerformance(value) {
            return .good
        } else {
            return .needsImprovement
        }
    }
    
    // Performance level enum
    public enum PerformanceLevel: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case needsImprovement = "Needs Improvement"
        
        public var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .needsImprovement: return "red"
            }
        }
    }
}
