import Foundation
import CryptoKit

struct Repo: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var path: String
    var currentBranch: String
    var lastOpened: Date
    
    static func == (lhs: Repo, rhs: Repo) -> Bool {
        return lhs.id == rhs.id
    }
    
    init(name: String, path: String, currentBranch: String) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.currentBranch = currentBranch
        self.lastOpened = Date()
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case home
    case movies
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .movies:
            return "Movies"
        case .settings:
            return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home:
            return "house"
        case .movies:
            return "tv"
        case .settings:
            return "gear"
        }
    }
}

enum RepoView: String, CaseIterable {
    case changes
    case history
    case branches
}

enum RepoSection: String, CaseIterable, Identifiable {
    case changes
    case history
    case branches
    case stashes
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .changes:
            return "Changes"
        case .history:
            return "History"
        case .branches:
            return "Branches"
        case .stashes:
            return "Stashes"
        }
    }
    
    var icon: String {
        switch self {
        case .changes:
            return "doc.badge.plus"
        case .history:
            return "clock.arrow.circlepath"
        case .branches:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .stashes:
            return "archivebox"
        }
    }
}

struct BranchString: Identifiable {
    let id: ObjectIdentifier
    let string: String
}

struct Commit: Identifiable, Hashable, Sendable {
    let id: String
    let shortHash: String
    let author: String
    let date: String
    let message: String
    var isPushed: Bool = true
    
    private var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy Z"
        
        return formatter.date(from: date)
    }
    
    var displayDate: String {
        guard let parsedDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        
        return formatter.string(from: parsedDate)
    }
    
    var displayTime: String {
        guard let parsedDate else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        return formatter.string(from: parsedDate)
    }
    
    var timeAgo: String {
        guard let parsedDate else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: parsedDate, relativeTo: Date())
    }
    
    var authorEmail: String {
        if let start = author.firstIndex(of: "<"), let end = author.firstIndex(of: ">"), start < end {
            let emailString = author[author.index(after: start)..<end]
            return String(emailString).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return ""
    }
    
    var authorName: String {
        let parts = author.split(separator: "<")
        if let first = parts.first {
            return String(first).trimmingCharacters(in: .whitespaces)
        }
        return author
    }
    
    var gravatarURL: URL? {
        let email = authorEmail
        guard !email.isEmpty else { return nil }
        let hash = Insecure.MD5.hash(data: email.data(using: .utf8) ?? Data())
        let hashString = hash.map { String(format: "%02hhx", $0) }.joined()
        // Using GitHub's avatar service as primary, fallback to gravatar/identicon
        return URL(string: "https://avatars.githubusercontent.com/u/e?email=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&s=88") ?? 
               URL(string: "https://www.gravatar.com/avatar/\(hashString)?s=88&d=identicon")
    }
}

extension Commit {
    static let previewData: [Commit] = [
        Commit(
            id: "1",
            shortHash: "a56afc6",
            author: "Bharath <bharath.a@tringapps.com>",
            date: "Thu Nov 13 14:15:59 2025 +0530",
            message: "Initial commit"
        ),
        Commit(
            id: "2",
            shortHash: "f8d123a",
            author: "Janani <janani@TRLCHMB207-63.local>",
            date: "Thu Nov 13 15:20:10 2025 +0530",
            message: "Added login screen"
        ),
        Commit(
            id: "3",
            shortHash: "bc91e2d",
            author: "Tring-Priya <priya.dg@tringapps.com>",
            date: "Thu Nov 13 16:05:45 2025 +0530",
            message: "Fixed websocket issue"
        ),
        Commit(
            id: "4",
            shortHash: "9ae67b1",
            author: "Bharath <bharath.a@tringapps.com>",
            date: "Fri Nov 14 09:10:11 2025 +0530",
            message: "Added dark mode"
        ),
        Commit(
            id: "5",
            shortHash: "e1245ab",
            author: "Janani <janani@TRLCHMB207-63.local>",
            date: "Fri Nov 14 11:42:18 2025 +0530",
            message: "Refactored API layer"
        )
    ]
}

struct GitStash: Identifiable, Hashable {
    let id: String
    let type: String
    let branch: String
    let message: String
}
struct ChangedFile: Identifiable, Hashable {
    var id: String { path }
    let path: String
    let status: String // e.g., "Modified", "Added", "Deleted", "Untracked"
    let isStaged: Bool
}

struct RebaseState: Codable, Equatable {
    var inProgress: Bool
    var currentCommitHash: String
    var currentCommitMessage: String
    var currentProgress: Int
    var totalProgress: Int
    var ontoBranch: String
    var headName: String
}

struct MergeState: Codable, Equatable {
    var inProgress: Bool
    var sourceBranch: String
    var targetBranch: String
    var currentCommitHash: String
    var defaultCommitMessage: String
}
