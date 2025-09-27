//
//  Champion.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData

@Model
public class Champion {
    @Attribute(.unique) public var id: Int
    public var key: String  // Data Dragon champion ID (used for image URLs)
    public var name: String
    public var title: String
    public var version: String
    public var lastUpdated: Date
    
    // Relationships
    @Relationship(deleteRule: .nullify) public var participants: [Participant] = []
    
    public init(id: Int, key: String, name: String, title: String, version: String) {
        self.id = id
        self.key = key
        self.name = name
        self.title = title
        self.version = version
        self.lastUpdated = Date()
    }
    
    // Convenience initializer for Data Dragon data
    public convenience init(from dataDragonChampion: DataDragonChampion, version: String) throws {
        guard let id = Int(dataDragonChampion.key) else {
            throw ChampionError.invalidKey(dataDragonChampion.key)
        }
        self.init(
            id: id,
            key: dataDragonChampion.id, // Use the champion name (id field) for image URLs
            name: dataDragonChampion.name,
            title: dataDragonChampion.title,
            version: version
        )
    }
    
    // Computed properties
    public var fullTitle: String {
        return "\(name), \(title)"
    }
    
    public var iconURL: String {
        // Transform champion name to match Data Dragon image naming convention
        let transformedName = Champion.transformChampionNameForImage(name)
        return "https://ddragon.leagueoflegends.com/cdn/\(version)/img/champion/\(transformedName).png"
    }
    
    public var loadingScreenURL: String {
        // Use the key (champion name from Data Dragon) for loading screen
        return "https://ddragon.leagueoflegends.com/cdn/img/champion/loading/\(key)_0.jpg"
    }
    
    public var splashArtURL: String {
        // Use the key (champion name from Data Dragon) for splash art
        return "https://ddragon.leagueoflegends.com/cdn/img/champion/splash/\(key)_0.jpg"
    }
    
    // MARK: - Champion Class Mapping
    
    /// Static mapping of champion keys to their primary classes
    private static let championClassMapping: [String: String] = {
        // Load from JSON file once and cache statically
        guard let url = Bundle.main.url(forResource: "champion_class_mapping_clean", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mappings = try? JSONDecoder().decode([ChampionClassMappingData].self, from: data) else {
            ClaimbLogger.error("Failed to load champion class mapping from JSON", service: "Champion")
            return [:]
        }
        
        var mapping: [String: String] = [:]
        for item in mappings {
            mapping[item.champion_id] = item.primary_class
        }
        
        ClaimbLogger.info("Loaded champion class mappings", service: "Champion", 
                         metadata: ["count": String(mappings.count)])
        return mapping
    }()
    
    /// The primary class/role of this champion (Fighter, Mage, Assassin, etc.)
    public var championClass: String {
        return Self.championClassMapping[key] ?? "Unknown"
    }
    
    // MARK: - Champion Name Transformation
    
    /// Transforms champion names to match Data Dragon image naming convention
    private static func transformChampionNameForImage(_ name: String) -> String {
        // Special champion name mappings for Data Dragon images
        let championNameMapping: [String: String] = [
            "Cho'Gath": "Chogath",
            "Dr. Mundo": "DrMundo",
            "Kai'Sa": "Kaisa",
            "Kha'Zix": "Khazix",
            "Kog'Maw": "KogMaw",
            "LeBlanc": "Leblanc",
            "Master Yi": "MasterYi",
            "Miss Fortune": "MissFortune",
            "Nunu & Willump": "Nunu",
            "Rek'Sai": "RekSai",
            "Tahm Kench": "TahmKench",
            "Twisted Fate": "TwistedFate",
            "Vel'Koz": "Velkoz",
            "Wukong": "MonkeyKing",
            "Xin Zhao": "XinZhao",
            "Jarvan IV": "JarvanIV",
            "Aurelion Sol": "AurelionSol",
            "Lee Sin": "LeeSin",
            "Renata Glasc": "Renata"
        ]
        
        // Check for special mappings first
        if let mappedName = championNameMapping[name] {
            return mappedName
        }
        
        // For other champions, remove spaces, apostrophes, and dots
        return name
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - Supporting Types

/// JSON structure for champion class mapping data
private struct ChampionClassMappingData: Codable {
    let champion_id: String
    let champion_name: String
    let primary_class: String
}

// MARK: - Errors

public enum ChampionError: Error, LocalizedError {
    case invalidKey(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidKey(let key):
            return "Invalid champion key: \(key)"
        }
    }
}
