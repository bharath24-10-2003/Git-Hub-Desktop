//
//  DiffRendererView.swift
//  Git Hub Desktop
//

import SwiftUI

struct DiffRendererView: View {
    let diff: FileDiff
    let file: ChangedFile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(file.path)
                    .font(.headline)
                    .padding()
                Spacer()
                if diff.isNewFile {
                    Text("New File")
                        .font(.caption)
                        .padding(4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.trailing)
                }
                if diff.isDeletedFile {
                    Text("Deleted File")
                        .font(.caption)
                        .padding(4)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                        .padding(.trailing)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(diff.lines) { line in
                        DiffLineView(line: line)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DiffLineView: View {
    let line: DiffLine
    
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
            .font(.system(size: 12, design: .monospaced))
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            // Code
            Text(line.text)
                .font(.system(size: 13, design: .monospaced))
                .padding(.leading, 8)
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor(for: line.type))
                .foregroundColor(textColor(for: line.type))
        }
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
        DiffLineView(line: DiffLine(text: "@@ -1,3 +1,4 @@", type: .hunkHeader, oldLineNumber: nil, newLineNumber: nil))
        DiffLineView(line: DiffLine(text: " struct DiffLineView: View {", type: .context, oldLineNumber: 1, newLineNumber: 1))
        DiffLineView(line: DiffLine(text: "     let line: DiffLine", type: .context, oldLineNumber: 2, newLineNumber: 2))
        DiffLineView(line: DiffLine(text: "-    var body: some View {", type: .removed, oldLineNumber: 3, newLineNumber: nil))
        DiffLineView(line: DiffLine(text: "+    var body: some View {", type: .added, oldLineNumber: nil, newLineNumber: 3))
        DiffLineView(line: DiffLine(text: "+        // Added line here", type: .added, oldLineNumber: nil, newLineNumber: 4))
        DiffLineView(line: DiffLine(text: "         HStack(alignment: .top, spacing: 0) {", type: .context, oldLineNumber: 4, newLineNumber: 5))
    }
    .padding()
}
