//
//  Item.swift
//  WidgetToDo
//
//  Created by 陈晓峰 on 2026/5/17.
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
