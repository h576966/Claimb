//
//  ChampionClassMapping.swift
//  Claimb
//
//  Created by AI Assistant on 2025-09-13.
//

import Foundation
import SwiftData

@Model
public class ChampionClassMapping {
    @Attribute(.unique) public var championId: String
    public var championName: String
    public var primaryClass: String

    public init(championId: String, championName: String, primaryClass: String) {
        self.championId = championId
        self.championName = championName
        self.primaryClass = primaryClass
    }
}
