//
//  Item.swift
//  Claimb
//
//  Created by Niklas Johansson on 2025-09-07.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
