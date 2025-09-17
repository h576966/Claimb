//
//  DataDragonService.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-08.
//

import Foundation

/// Service for fetching and caching static game data from Riot's Data Dragon CDN
public class DataDragonService: DataDragonServiceProtocol {

    // MARK: - Properties

    private let baseURL = "https://ddragon.leagueoflegends.com"
    private let session: URLSession
    private var cachedVersion: String?
    private var cachedChampions: [String: DataDragonChampion] = [:]

    // MARK: - Initialization

    public init() {
        // Configure URLSession with caching
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// Fetches the latest patch version from Data Dragon
    public func getLatestVersion() async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/versions.json") else {
            throw DataDragonError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let versions = try JSONDecoder().decode([String].self, from: data)

        guard let latestVersion = versions.first else {
            throw DataDragonError.noVersionsAvailable
        }

        cachedVersion = latestVersion
        return latestVersion
    }

    /// Fetches champion data for a specific version
    public func getChampions(version: String? = nil) async throws -> [String: DataDragonChampion] {
        let versionToUse: String
        if let version = version {
            versionToUse = version
        } else if let cachedVersion = cachedVersion {
            versionToUse = cachedVersion
        } else {
            versionToUse = try await getLatestVersion()
        }

        // Return cached data if available and version matches
        if !cachedChampions.isEmpty && cachedVersion == versionToUse {
            return cachedChampions
        }

        guard let url = URL(string: "\(baseURL)/cdn/\(versionToUse)/data/en_US/champion.json")
        else {
            throw DataDragonError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(DataDragonChampionResponse.self, from: data)

        cachedChampions = response.data
        cachedVersion = versionToUse

        return cachedChampions
    }

    /// Gets champion icon URL for a specific champion and version
    public func getChampionIconURL(championId: String, version: String? = nil) -> URL? {
        let versionToUse = version ?? cachedVersion ?? "latest"
        return URL(string: "\(baseURL)/cdn/\(versionToUse)/img/champion/\(championId).png")
    }

    /// Gets champion data by ID
    public func getChampion(by id: String, version: String? = nil) async throws
        -> DataDragonChampion?
    {
        let champions = try await getChampions(version: version)
        return champions[id]
    }
}

// MARK: - Data Models

public struct DataDragonChampionResponse: Codable {
    public let type: String
    public let format: String
    public let version: String
    public let data: [String: DataDragonChampion]
}

public struct DataDragonChampion: Codable {
    public let id: String
    public let key: String
    public let name: String
    public let title: String
    public let image: DataDragonImage
    public let tags: [String]

    public init(
        id: String, key: String, name: String, title: String, image: DataDragonImage, tags: [String]
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.title = title
        self.image = image
        self.tags = tags
    }
}

public struct DataDragonImage: Codable {
    public let full: String
    public let sprite: String
    public let group: String
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int

    public init(full: String, sprite: String, group: String, x: Int, y: Int, w: Int, h: Int) {
        self.full = full
        self.sprite = sprite
        self.group = group
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}

// MARK: - Errors

public enum DataDragonError: Error, LocalizedError {
    case invalidURL
    case noVersionsAvailable
    case noChampionsAvailable
    case championNotFound
    case networkError(Error)
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noVersionsAvailable:
            return "No versions available"
        case .noChampionsAvailable:
            return "No champions available"
        case .championNotFound:
            return "Champion not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
