//
//  AppHealthMonitor.swift
//  Claimb
//
//  Created by AI Assistant on 2025-11-20.
//

import Foundation
import SwiftUI

@MainActor
final class AppHealthMonitor: ObservableObject {
    static let shared = AppHealthMonitor()

    @Published var launchIssue: LaunchIssue?

    func record(_ issue: LaunchIssue) {
        if let currentIssue = launchIssue {
            if issue.severity.rawValue >= currentIssue.severity.rawValue {
                launchIssue = issue
            }
        } else {
            launchIssue = issue
        }
    }

    func clearIssue() {
        launchIssue = nil
    }
}

struct LaunchIssue: Identifiable, Equatable {
    enum Severity: Int {
        case warning = 0
        case critical = 1
    }

    let id = UUID()
    let title: String
    let message: String
    let severity: Severity
}

enum AppHealthReporter {
    static func report(_ issue: LaunchIssue) {
        Task { @MainActor in
            AppHealthMonitor.shared.record(issue)
        }
    }
}

