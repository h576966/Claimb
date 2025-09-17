//
//  DataCoordinatorEnvironmentKey.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

/// Environment key for DataCoordinator injection
struct DataCoordinatorKey: EnvironmentKey {
    static let defaultValue: DataCoordinator? = nil
}

extension EnvironmentValues {
    var dataCoordinator: DataCoordinator? {
        get { self[DataCoordinatorKey.self] }
        set { self[DataCoordinatorKey.self] = newValue }
    }
}
