//
//  Item.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
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
