import Foundation

// MARK: - Result Model
nonisolated struct GitResult {
    let output: String
    let error: String
    let exitCode: Int32
    
    var isSuccess: Bool {
        return exitCode == 0
    }
}

// MARK: - Errors

enum GitError: Error, LocalizedError {
    case invalidRepository
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRepository:
            return "Invalid Git repository path."
        case .executionFailed(let message):
            return message
        }
    }
}

// MARK: - Git Service

final class GitService {
    
    private let gitPath = "/usr/bin/git"
    
    // Core runner
    @discardableResult
    func run(_ args: [String], at repoPath: String? = nil) async throws -> GitResult {
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        
        if let repoPath = repoPath {
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        }
        
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                let result = GitResult(
                    output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                    error: error.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: process.terminationStatus
                )
                
                if result.isSuccess {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: GitError.executionFailed(result.error.isEmpty ? result.output : result.error))
                }
            }
        }
    }
}

// MARK: - High-Level APIs

extension GitService {
    
    // Clone
    func clone(url: String, to path: String) async throws {
        try await run(["clone", url, path])
    }
    
    // Status
    func status(at repo: String) async throws -> String {
        let result = try await run(["status", "--porcelain"], at: repo)
        return result.output
    }
    
    // Add
    func addAll(at repo: String) async throws {
        try await run(["add", "."], at: repo)
    }
    
    func add(file: String, at repo: String) async throws {
        try await run(["add", file], at: repo)
    }
    
    // Commit
    func commit(message: String, at repo: String) async throws {
        try await run(["commit", "-m", message], at: repo)
    }
    
    // Push / Pull
    func push(at repo: String) async throws {
        try await run(["push"], at: repo)
    }
    
    func forcePush(at repo: String) async throws {
        try await run(["push", "--force"], at: repo)
    }
    
    func pull(at repo: String) async throws {
        try await run(["pull"], at: repo)
    }
    
    // Log
    func log(at repo: String) async throws -> String {
        let result = try await run(
            ["log", "--oneline", "--graph", "--decorate"],
            at: repo
        )
        return result.output
    }
    
    func fetch(at repo:String) async throws {
        try await run(["fetch"], at: repo)
    }
    
    func checkout(branch: String, at repo: String) async throws {
        try await run(["checkout", branch], at: repo)
    }
    
    func createBranch(branch: String, at repo: String) async throws {
        try await run(["checkout", "-b", branch], at: repo)
    }
    
    func getLocalBranches(at repo: String) async throws -> [String] {
        let result = try await run(["branch", "-l"], at: repo)
        return result.output.split(separator: "\n").map(String.init)
    }
    
    func getRemoteBranches(at repo: String) async throws -> [String] {
        let result = try await run(["branch", "-r"], at: repo)
        return result.output.split(separator: "\n").map(String.init)
    }
    // MARK: - Rebase
    
    func startRebase(branch: String, at repo: String) async throws {
        try await run(["rebase", branch], at: repo)
    }
    
    func rebaseContinue(at repo: String) async throws {
        try await run(["rebase", "--continue"], at: repo)
    }
    
    func rebaseAbort(at repo: String) async throws {
        try await run(["rebase", "--abort"], at: repo)
    }
    
    func rebaseSkip(at repo: String) async throws {
        try await run(["rebase", "--skip"], at: repo)
    }
    // MARK: - Cherry-pick
    
    func cherryPick(commit: String, at repo: String) async throws {
        try await run(["cherry-pick", commit], at: repo)
    }
    
    func cherryPickContinue(at repo: String) async throws {
        try await run(["cherry-pick", "--continue"], at: repo)
    }
    
    func cherryPickAbort(at repo: String) async throws {
        try await run(["cherry-pick", "--abort"], at: repo)
    }
    
    func cherryPickSkip(at repo: String) async throws {
        try await run(["cherry-pick", "--skip"], at: repo)
    }
    
    // MARK: - Tags
    
    func createTag(name: String, at repo: String) async throws {
        try await run(["tag", name], at: repo)
    }
    
    func pushTag(name: String, at repo: String) async throws {
        try await run(["push", "origin", name], at: repo)
    }
    
    func listTags(at repo: String) async throws -> [String] {
        let result = try await run(["tag"], at: repo)
        return result.output.components(separatedBy: "\n")
    }
}
