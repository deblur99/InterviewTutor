import Foundation
import SwiftUI

enum LetterGrade: String, CaseIterable, Codable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"

    init(score: Int) {
        switch score {
        case 90...100: self = .s
        case 80..<90: self = .a
        case 70..<80: self = .b
        case 60..<70: self = .c
        case 50..<60: self = .d
        default: self = .f
        }
    }

    var displayName: String { rawValue }

    var accentColor: Color {
        switch self {
        case .s: .purple
        case .a: .green
        case .b: .blue
        case .c: .teal
        case .d: .orange
        case .f: .red
        }
    }
}
