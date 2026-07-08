import Foundation

struct GitLogEntry: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case info
        case warning
        case error
        case success
        case gitProgress
        case preCommitCheck
        case preCommitRunning
        case remote
        case normal
    }

    let id: UUID
    let kind: Kind
    let message: String
    let progress: Double?
    let timestamp: Date

    init(id: UUID = UUID(), kind: Kind, message: String, progress: Double? = nil, timestamp: Date = Date()) {
        self.id = id
        self.kind = kind
        self.message = message
        self.progress = progress
        self.timestamp = timestamp
    }
}
