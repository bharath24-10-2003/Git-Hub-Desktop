import Foundation

nonisolated struct GitHubCLIResult {
    let output: String
    let exitCode: Int32

    var isSuccess: Bool { exitCode == 0 }
}

nonisolated final class GitHubCLIService {
    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data) {
            lock.lock()
            data.append(chunk)
            lock.unlock()
        }

        func string() -> String {
            lock.lock()
            defer { lock.unlock() }
            return String(decoding: data, as: UTF8.self)
        }
    }

    func authStatus() async throws -> GitHubCLIResult {
        try await run(["auth", "status"])
    }

    func loginWithBrowser() async throws -> GitHubCLIResult {
        try await run([
            "auth", "login",
            "--hostname", "github.com",
            "--web",
            "--clipboard",
            "--git-protocol", "https",
            "--skip-ssh-key"
        ])
    }

    func logout(host: String, account: String) async throws -> GitHubCLIResult {
        try await run(["auth", "logout", "--hostname", host, "--user", account])
    }

    func listReleases(in repositoryPath: String) async throws -> GitHubCLIResult {
        try await run([
            "release", "list",
            "--limit", "100",
            "--json", "name,tagName,isDraft,isPrerelease,isLatest,publishedAt,createdAt,isImmutable"
        ], at: repositoryPath)
    }

    func releaseDetails(tag: String, in repositoryPath: String) async throws -> GitHubCLIResult {
        try await run([
            "release", "view", tag,
            "--json", "name,tagName,isDraft,isPrerelease,isImmutable,targetCommitish,publishedAt,createdAt,author,body,assets,url,tarballUrl,zipballUrl"
        ], at: repositoryPath)
    }

    func createRelease(
        tag: String,
        title: String,
        notes: String,
        targetBranch: String,
        generateNotes: Bool,
        isDraft: Bool,
        isPrerelease: Bool,
        in repositoryPath: String
    ) async throws -> GitHubCLIResult {
        var arguments = ["release", "create", tag, "--target", targetBranch]
        if !title.isEmpty {
            arguments.append(contentsOf: ["--title", title])
        }
        if generateNotes {
            arguments.append("--generate-notes")
            if !notes.isEmpty {
                arguments.append(contentsOf: ["--notes", notes])
            }
        } else {
            arguments.append(contentsOf: ["--notes", notes])
        }
        if isDraft { arguments.append("--draft") }
        if isPrerelease { arguments.append("--prerelease") }
        return try await run(arguments, at: repositoryPath)
    }

    func editRelease(
        tag: String,
        title: String,
        notes: String,
        targetBranch: String,
        isDraft: Bool,
        isPrerelease: Bool,
        in repositoryPath: String
    ) async throws -> GitHubCLIResult {
        try await run([
            "release", "edit", tag,
            "--title", title,
            "--notes", notes,
            "--target", targetBranch,
            "--draft=\(isDraft)",
            "--prerelease=\(isPrerelease)"
        ], at: repositoryPath)
    }

    func deleteRelease(tag: String, in repositoryPath: String) async throws -> GitHubCLIResult {
        try await run(["release", "delete", tag, "--yes"], at: repositoryPath)
    }

    private func run(_ arguments: [String], at directory: String? = nil) async throws -> GitHubCLIResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["gh"] + arguments
        if let directory {
            process.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        }

        var environment = ProcessInfo.processInfo.environment
        let defaultPaths = [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ]
        let existingPath = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        var paths: [String] = []
        for path in defaultPaths + existingPath where !paths.contains(path) {
            paths.append(path)
        }
        environment["PATH"] = paths.joined(separator: ":")
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        process.environment = environment

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let output = OutputBuffer()
        let error = OutputBuffer()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { output.append(data) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { error.append(data) }
        }

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                output.append((try? outputPipe.fileHandleForReading.readToEnd()) ?? Data())
                error.append((try? errorPipe.fileHandleForReading.readToEnd()) ?? Data())
                let combinedOutput = [output.string(), error.string()]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                continuation.resume(returning: GitHubCLIResult(
                    output: combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: process.terminationStatus
                ))
            }

            do {
                try process.run()
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }
}
