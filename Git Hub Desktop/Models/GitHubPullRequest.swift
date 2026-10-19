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
    let comments: [GitHubPullRequestComment]?
    let reviews: [GitHubPullRequestReview]?
    let files: [GitHubPullRequestFile]?

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

struct GitHubReviewer: Decodable, Identifiable {
    let login: String
    let avatarURL: URL?

    var id: String { login }

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}

struct GitHubPullRequestCommit: Decodable, Identifiable {
    let oid: String
    let messageHeadline: String

    var id: String { oid }
}

struct GitHubPullRequestComment: Decodable, Identifiable {
    let nodeID: String?
    let body: String?
    let createdAt: String?
    let author: GitHubPullRequestAuthor?
    let url: URL?

    var id: String {
        nodeID ?? "comment-\(author?.login ?? "unknown")-\(createdAt ?? "")-\(body ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case nodeID = "id"
        case body, createdAt, author, url
    }
}

struct GitHubPullRequestReview: Decodable, Identifiable {
    let nodeID: String?
    let body: String?
    let state: String
    let submittedAt: String?
    let author: GitHubPullRequestAuthor?
    let url: URL?

    var id: String {
        nodeID ?? "review-\(author?.login ?? "unknown")-\(submittedAt ?? "")-\(state)"
    }

    enum CodingKeys: String, CodingKey {
        case nodeID = "id"
        case body, state, submittedAt, author, url
    }
}

struct GitHubPullRequestReviewComment: Decodable, Identifiable {
    let id: Int
    let inReplyToID: Int?
    let body: String?
    let createdAt: String?
    let user: GitHubPullRequestAuthor?
    let htmlURL: URL?
    let path: String?

    enum CodingKeys: String, CodingKey {
        case id, body, user, path
        case inReplyToID = "in_reply_to_id"
        case createdAt = "created_at"
        case htmlURL = "html_url"
    }
}

struct GitHubPullRequestFile: Decodable, Identifiable {
    let path: String
    let additions: Int
    let deletions: Int
    let changeType: String

    var id: String { path }
}
