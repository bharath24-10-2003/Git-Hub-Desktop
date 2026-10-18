import Foundation

struct GitHubPullRequest: Decodable, Identifiable {
    let number: Int
    let title: String
    let body: String?
    let state: String
    let url: URL?
    let author: GitHubPullRequestAuthor?
    let headRefName: String
    let baseRefName: String
    let isDraft: Bool
    let createdAt: String?
    let updatedAt: String?
    let mergedAt: String?
    let reviewDecision: String?
    let mergeStateStatus: String?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let commits: [GitHubPullRequestCommit]?

    var id: Int { number }

    var displayState: String {
        if mergedAt != nil { return "Merged" }
        return state.capitalized
    }

    var displayDate: String? {
        guard let dateString = updatedAt ?? createdAt,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct GitHubPullRequestAuthor: Decodable {
    let login: String?
}

struct GitHubPullRequestCommit: Decodable, Identifiable {
    let oid: String
    let messageHeadline: String

    var id: String { oid }
}
