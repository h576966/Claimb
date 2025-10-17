//
//  DataDragonServiceProtocol.swift
//  Claimb
//
//  Created by AI Assistant on 2025-01-27.
//

import Foundation

/// Protocol for Data Dragon service to enable dependency injection
public protocol DataDragonServiceProtocol {
    /// Fetches the latest patch version from Data Dragon
    func getLatestVersion() async throws -> String

    /// Fetches champion data for a specific version
    func getChampions(version: String?) async throws -> [String: DataDragonChampion]

    /// Gets the URL for a champion icon
    func getChampionIconURL(championId: String, version: String?) -> URL?

    /// Gets a specific champion by ID
    func getChampion(by id: String, version: String?) async throws -> DataDragonChampion?
}
