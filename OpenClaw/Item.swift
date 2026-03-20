//
//  Item.swift
//  OpenClaw
//
//  Created by ceaser on 2026/3/19.
//

import Foundation
struct Item: Identifiable, Hashable {
    let id: UUID
    var timestamp: Date

    init(timestamp: Date, id: UUID = UUID()) {
        self.timestamp = timestamp
        self.id = id
    }
}
