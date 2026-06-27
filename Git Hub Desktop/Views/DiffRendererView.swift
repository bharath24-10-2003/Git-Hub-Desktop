//
//  DiffRendererView.swift
//  Git Hub Desktop
//

import SwiftUI
import Highlighter

struct DiffRendererView: View {
    let diff: FileDiff
    let file: ChangedFile
    
    var language: String {
        let path = file.path as NSString
        let ext = path.pathExtension.lowercased()
        return ext.isEmpty ? "plaintext" : ext
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(file.path)
                    .appFont(.headline)
                    .padding()
                Spacer()
                if diff.isNewFile {
                    Text("New File")
                        .appFont(.caption)
                        .padding(4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.trailing)
                }
                if diff.isDeletedFile {
                    Text("Deleted File")
                        .appFont(.caption)
                        .padding(4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.trailing)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            GeometryReader { geometry in
                ScrollView(showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        let lines = diff.lines.filter { $0.type != .fileHeader }
                        ForEach(lines) { line in
                            DiffLineView(line: line, language: language)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

class SyntaxHighlighter {
    static let shared = SyntaxHighlighter()
    let highlighter: Highlighter?
    
    private init() {
        self.highlighter = Highlighter()
    }
}

struct DiffLineView: View {
    let line: DiffLine
    let language: String
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appFontFamily") var appFontFamily = "System"
    
    // Asynchronous highlighting state
    @State private var highlightedString: AttributedString?
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line numbers
            HStack(spacing: 0) {
                Text(line.oldLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                    .foregroundColor(.secondary)
                
                Text(line.newLineNumber.map { String($0) } ?? "")
                    .frame(width: 40, alignment: .trailing)
                    .padding(.trailing, 8)
                    .foregroundColor(.secondary)
            }
            .appFont(.caption, design: .monospaced)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            // Code
            Group {
                if let attrStr = highlightedString {
                    Text(attrStr)
                } else {
                    Text(line.text)
                        .foregroundColor(textColor(for: line.type))
                }
            }
            .appFont(.subheadline, design: .monospaced)
            .textSelection(.enabled)
            .padding(.leading, 8)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor(for: line.type))
        }
        .task(id: line.id) {
            await highlightText()
        }
    }
    
    private func highlightText() async {
        guard line.type == .added || line.type == .removed || line.type == .context else {
            return
        }
        
        let rawText = line.text
        if rawText.isEmpty { return }
        
        // Strip the first character (+, -, or space) for highlighting
        let firstChar = rawText.first!
        let codeToHighlight = String(rawText.dropFirst())
        
        // Pick a theme based on color scheme
        let theme = colorScheme == .dark ? "atom-one-dark" : "xcode"
        
        if let highlighter = SyntaxHighlighter.shared.highlighter {
            _ = highlighter.setTheme(theme)
            if let result = highlighter.highlight(codeToHighlight, as: language) {
                var finalString = AttributedString(String(firstChar))
                
                var highlighted = AttributedString(result)
                // Adjust font size since highlighter might set its own
                if appFontFamily == "System" || appFontFamily.isEmpty {
                    highlighted.font = .system(size: 13, design: .monospaced)
                } else {
                    highlighted.font = .custom(appFontFamily, size: 13)
                }
                
                // Append the highlighted code to the prefix
                finalString.append(highlighted)
                
                self.highlightedString = finalString
                return
            }
        }
        
        // Fallback
        var fallbackStr = AttributedString(rawText)
        if appFontFamily == "System" || appFontFamily.isEmpty {
            fallbackStr.font = .system(size: 13, design: .monospaced)
        } else {
            fallbackStr.font = .custom(appFontFamily, size: 13)
        }
        self.highlightedString = fallbackStr
    }
    
    private func backgroundColor(for type: DiffLineType) -> Color {
        switch type {
        case .added: return Color.green.opacity(0.15)
        case .removed: return Color.red.opacity(0.15)
        case .hunkHeader: return Color.blue.opacity(0.1)
        case .fileHeader: return Color.gray.opacity(0.1)
        case .context: return Color.clear
        }
    }
    
    private func textColor(for type: DiffLineType) -> Color {
        switch type {
        case .hunkHeader: return .blue
        case .fileHeader: return .secondary
        default: return .primary
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DiffLineView(line: DiffLine(text: "@@ -1,3 +1,4 @@", type: .hunkHeader, oldLineNumber: nil, newLineNumber: nil), language: "swift")
        DiffLineView(line: DiffLine(text: " struct DiffLineView: View {", type: .context, oldLineNumber: 1, newLineNumber: 1), language: "swift")
        DiffLineView(line: DiffLine(text: "     let line: DiffLine", type: .context, oldLineNumber: 2, newLineNumber: 2), language: "swift")
        DiffLineView(line: DiffLine(text: "-    var body: some View {", type: .removed, oldLineNumber: 3, newLineNumber: nil), language: "swift")
        DiffLineView(line: DiffLine(text: "+    var body: some View {", type: .added, oldLineNumber: nil, newLineNumber: 3), language: "swift")
        DiffLineView(line: DiffLine(text: "+        // Added line here", type: .added, oldLineNumber: nil, newLineNumber: 4), language: "swift")
        DiffLineView(line: DiffLine(text: "         HStack(alignment: .top, spacing: 0) {", type: .context, oldLineNumber: 4, newLineNumber: 5), language: "swift")
    }
    .padding()
}
