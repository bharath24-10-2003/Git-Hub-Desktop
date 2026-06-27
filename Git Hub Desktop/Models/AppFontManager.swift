import AppKit
import Foundation

class AppFontManager {
    static let shared = AppFontManager()
    
    let availableFonts: [String]
    
    private init() {
        var fonts = NSFontManager.shared.availableFontFamilies
        // Add standard system identifiers at the top
        if !fonts.contains("System") {
            fonts.insert("System", at: 0)
        }
        self.availableFonts = fonts
    }
}
