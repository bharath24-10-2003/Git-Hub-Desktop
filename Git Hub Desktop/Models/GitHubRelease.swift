import Foundation

struct GitHubRelease: Decodable, Identifiable {
    var id: String { tagName }

    let name: String?
    let tagName: String
    let isDraft: Bool?
    let isPrerelease: Bool?
    let isLatest: Bool?
    let isImmutable: Bool?
    let targetCommitish: String?
    let publishedAt: String?
    let createdAt: String?
    let author: GitHubReleaseAuthor?
    let body: String?
    let assets: [GitHubReleaseAsset]?
    let url: URL?
    let tarballUrl: URL?
    let zipballUrl: URL?

    var displayTitle: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? tagName : trimmedName
    }

    var displayDate: String? {
        guard let dateString = publishedAt ?? createdAt,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

struct GitHubReleaseAuthor: Decodable {
    let login: String?
    let name: String?

    var displayName: String? {
        name ?? login
    }
}

struct GitHubReleaseAsset: Decodable, Identifiable {
    var id: String { name }

    let name: String
    let size: Int?
    let downloadCount: Int?
    let contentType: String?
    let state: String?
    let browserDownloadUrl: URL?

    var formattedSize: String? {
        guard let size else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
