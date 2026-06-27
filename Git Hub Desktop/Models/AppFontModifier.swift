import SwiftUI

struct AppFontModifier: ViewModifier {
    @AppStorage("appFontFamily") var appFontFamily = "System"
    var style: Font.TextStyle?
    var size: CGFloat?
    var weight: Font.Weight?
    var design: Font.Design?
    
    func body(content: Content) -> some View {
        if appFontFamily == "System" || appFontFamily.isEmpty {
            if let size = size {
                content.font(.system(size: size, weight: weight ?? .regular, design: design ?? .default))
            } else if let style = style {
                content.font(.system(style, design: design ?? .default).weight(weight ?? .regular))
            } else {
                content.font(.system(.body, design: design ?? .default).weight(weight ?? .regular))
            }
        } else {
            let actualSize = size ?? sizeFor(style ?? .body)
            content.font(.custom(appFontFamily, size: actualSize, relativeTo: style ?? .body).weight(weight ?? .regular))
        }
    }
    
    private func sizeFor(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension View {
    func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        self.modifier(AppFontModifier(style: style, size: nil, weight: weight, design: design))
    }
    
    func appFont(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        self.modifier(AppFontModifier(style: nil, size: size, weight: weight, design: design))
    }
}
