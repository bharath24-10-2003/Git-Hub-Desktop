import Foundation
import SwiftUI

enum HookStatus {
    case waiting
    case running
    case passed
    case failed
    case skipped
    
    var icon: String {
        switch self {
        case .waiting: return "circle"
        case .running: return "hourglass"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "forward.end.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .waiting: return .gray
        case .running: return .blue
        case .passed: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }
}

struct HookTask: Identifiable {
    let id = UUID()
    var name: String
    var status: HookStatus = .running
    var rawOutput: [String] = []
}
