import SwiftUI

enum AppFontStyle: String, CaseIterable, Identifiable {
    case system = "System"
    case rounded = "Rounded"
    case serif = "Serif"
    case monospaced = "Monospaced"
    
    var id: String { rawValue }
    
    var fontDesign: Font.Design {
        switch self {
        case .system:
            return .default
        case .rounded:
            return .rounded
        case .serif:
            return .serif
        case .monospaced:
            return .monospaced
        }
    }
}
