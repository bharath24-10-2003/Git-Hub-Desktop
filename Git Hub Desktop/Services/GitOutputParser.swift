import Foundation

struct GitOutputParser {
    static func parse(line: String) -> GitLogEntry {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check for explicit Info/Warning/Error markers
        if trimmed.hasPrefix("[INFO]") || trimmed.lowercased().contains("info:") {
            return GitLogEntry(kind: .info, message: trimmed.replacingOccurrences(of: "[INFO]", with: "").trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("[WARNING]") || trimmed.lowercased().contains("warning:") {
            return GitLogEntry(kind: .warning, message: trimmed.replacingOccurrences(of: "[WARNING]", with: "").trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("[ERROR]") || trimmed.lowercased().contains("error:") || trimmed.lowercased().contains("fatal:") {
            return GitLogEntry(kind: .error, message: trimmed)
        }
        
        // 2. Pre-commit hooks (e.g. Pre-push clean build........................................Passed)
        if trimmed.contains("........") {
            if trimmed.hasSuffix("Passed") {
                let name = trimmed.components(separatedBy: "........").first?.trimmingCharacters(in: .whitespaces) ?? trimmed
                return GitLogEntry(kind: .preCommitCheck, message: "\(name) Passed")
            } else if trimmed.hasSuffix("Failed") {
                let name = trimmed.components(separatedBy: "........").first?.trimmingCharacters(in: .whitespaces) ?? trimmed
                return GitLogEntry(kind: .error, message: "\(name) Failed")
            } else {
                let name = trimmed.components(separatedBy: "........").first?.trimmingCharacters(in: .whitespaces) ?? trimmed
                return GitLogEntry(kind: .preCommitRunning, message: "\(name) Running...")
            }
        }
        
        // 3. Remote lines
        if trimmed.hasPrefix("remote:") || trimmed.hasPrefix("To ") || trimmed.hasPrefix("From ") {
            return GitLogEntry(kind: .remote, message: trimmed)
        }
        
        // 4. Git Progress (e.g., Counting objects: 100% (67/67), done.)
        // Look for percentage
        if let percentRange = trimmed.range(of: #"\d+%"#, options: .regularExpression) {
            let percentString = trimmed[percentRange].dropLast() // remove '%'
            let progress = (Double(percentString) ?? 0.0) / 100.0
            
            // Clean up the message for UI
            var cleanMessage = trimmed
            if cleanMessage.hasPrefix("remote:") {
                cleanMessage = String(cleanMessage.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            }
            return GitLogEntry(kind: .gitProgress, message: cleanMessage, progress: progress)
        }
        
        // Catch other Git generic status messages
        let genericProgressWords = ["Enumerating objects:", "Counting objects:", "Compressing objects:", "Writing objects:", "Resolving deltas:"]
        if genericProgressWords.contains(where: { trimmed.hasPrefix($0) }) {
            return GitLogEntry(kind: .gitProgress, message: trimmed, progress: nil)
        }
        
        // 5. Success markers
        if trimmed.lowercased() == "done." || trimmed.lowercased() == "success" || trimmed.hasPrefix("Everything up-to-date") {
            return GitLogEntry(kind: .success, message: trimmed)
        }
        
        // Default
        return GitLogEntry(kind: .normal, message: trimmed)
    }
}
