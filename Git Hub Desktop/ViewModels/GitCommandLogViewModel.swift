import Foundation
import SwiftUI

@Observable
class GitCommandLogViewModel {
    var entries: [GitLogEntry] = []
    var rawLogText: String = ""
    var isRunning: Bool = false
    var title: String = "Git Operation"
    
    private var lastIncompleteEntryId: UUID? = nil
    
    private var parser: LogParser?
    
    init() {
        self.parser = LogParser(onFlush: { [weak self] rawText, lines, incompleteLine in
            await self?.handleFlush(rawText: rawText, lines: lines, incompleteLine: incompleteLine)
        })
    }

    func start(title: String) {
        self.title = title
        self.entries = []
        self.lastIncompleteEntryId = nil
        self.rawLogText = ""
        self.isRunning = true
        Task {
            await self.parser?.reset()
        }
    }

    func finish() {
        self.isRunning = false
        Task {
            await self.parser?.flush()
        }
    }
    
    nonisolated func parseAndAppend(_ text: String) {
        Task {
            await self.parser?.append(text)
        }
    }
    
    @MainActor
    private func handleFlush(rawText: String, lines: [String], incompleteLine: String) {
        self.rawLogText += rawText
        
        // Remove old incomplete entry
        if let lastId = self.lastIncompleteEntryId, let idx = self.entries.lastIndex(where: { $0.id == lastId }) {
            self.entries.remove(at: idx)
            self.lastIncompleteEntryId = nil
        }
        
        for line in lines {
            self.processLine(line)
        }
        
        // Add new incomplete entry
        let trimmedIncomplete = incompleteLine.trimmingCharacters(in: .whitespaces)
        if !trimmedIncomplete.isEmpty {
            let entry = GitOutputParser.parse(line: trimmedIncomplete)
            self.entries.append(entry)
            self.lastIncompleteEntryId = entry.id
        }
    }
    
    private func processLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let entry = GitOutputParser.parse(line: trimmed)
        
        // If it's a progress update for the SAME message as the last one, update it instead of appending
        if entry.kind == .gitProgress {
            let key = self.getProgressKey(from: entry.message)
            // Check if we already have a progress entry for this key
            if let existingIndex = self.entries.lastIndex(where: { $0.kind == .gitProgress && self.getProgressKey(from: $0.message) == key }) {
                self.entries[existingIndex] = entry
                return
            }
        }
        
        self.entries.append(entry)
    }
    
    private func getProgressKey(from message: String) -> String {
        if let colonIndex = message.firstIndex(of: ":") {
            return String(message[..<colonIndex])
        }
        return message
    }
}

// MARK: - LogParser Actor

actor LogParser {
    private var bgBuffer: String = ""
    private var bgRawAppend: String = ""
    private var isFlushScheduled = false
    
    private let onFlush: @Sendable (String, [String], String) async -> Void
    
    init(onFlush: @escaping @Sendable (String, [String], String) async -> Void) {
        self.onFlush = onFlush
    }
    
    func append(_ text: String) {
        bgBuffer += text
        bgRawAppend += text
        
        if !isFlushScheduled {
            isFlushScheduled = true
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                await flush()
            }
        }
    }
    
    func flush() async {
        let rawText = bgRawAppend
        bgRawAppend = ""
        isFlushScheduled = false
        
        var linesToProcess: [String] = []
        while let range = bgBuffer.rangeOfCharacter(from: CharacterSet(charactersIn: "\n\r")) {
            let completeLine = String(bgBuffer[..<range.lowerBound])
            bgBuffer = String(bgBuffer[bgBuffer.index(after: range.lowerBound)...])
            linesToProcess.append(completeLine)
        }
        
        if !rawText.isEmpty || !linesToProcess.isEmpty || !bgBuffer.isEmpty {
            await onFlush(rawText, linesToProcess, bgBuffer)
        }
    }
    
    func reset() {
        bgBuffer = ""
        bgRawAppend = ""
        isFlushScheduled = false
    }
}
