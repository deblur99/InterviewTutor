//
//  Item.swift
//  InterviewTutor
//
//  Created by 한현민 on 6/15/26.
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
