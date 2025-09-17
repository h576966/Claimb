//
//  ServiceEnvironmentKeys.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import SwiftUI

// MARK: - RiotClient Environment Key

struct RiotClientKey: EnvironmentKey {
    static let defaultValue: RiotClient? = nil
}

extension EnvironmentValues {
    var riotClient: RiotClient? {
        get { self[RiotClientKey.self] }
        set { self[RiotClientKey.self] = newValue }
    }
}

// MARK: - DataDragonService Environment Key

struct DataDragonServiceKey: EnvironmentKey {
    static let defaultValue: DataDragonServiceProtocol? = nil
}

extension EnvironmentValues {
    var dataDragonService: DataDragonServiceProtocol? {
        get { self[DataDragonServiceKey.self] }
        set { self[DataDragonServiceKey.self] = newValue }
    }
}
