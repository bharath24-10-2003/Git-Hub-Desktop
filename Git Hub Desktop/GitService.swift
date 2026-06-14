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

nonisolated final class GitService {
    
    private let gitPath = "/usr/bin/git"
    
    // Core runner
    @discardableResult
    func run(_ args: [String], at repoPath: String? = nil) async throws -> GitResult {
        print("GitService: Running '/usr/bin/git \(args.joined(separator: " "))' at path: '\(repoPath ?? "default")'")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = env
        
        if let repoPath = repoPath {
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        }
        
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            print("GitService: Failed to start process: \(error.localizedDescription)")
            throw error
        }
        
        let outputTask = Task {
            outputPipe.fileHandleForReading.readDataToEndOfFile()
        }
        
        let errorTask = Task {
            errorPipe.fileHandleForReading.readDataToEndOfFile()
        }
        
        let outputData = await outputTask.value
        let errorData = await errorTask.value
        
        process.waitUntilExit()
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""
        
        let result = GitResult(
            output: output.trimmingCharacters(in: .whitespacesAndNewlines),
            error: error.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus
        )
        
        print("GitService: Finished with exitCode: \(result.exitCode)")
        if !result.isSuccess {
            print("GitService: Error Output: '\(result.error)'")
        }
        
        return result
    }
}

// MARK: - High-Level APIs

nonisolated extension GitService {
    
    // Clone
    @discardableResult
    func clone(url: String, to path: String) async throws -> GitResult {
        try await run(["clone", url, path])
    }
    
    // Status
    func status(at repo: String) async throws -> [ChangedFile] {
        let result = try await run(["status", "--porcelain"], at: repo)
        return parseStatus(result.output)
    }
    
    // Add
    @discardableResult
    func addAll(at repo: String) async throws -> GitResult {
        try await run(["add", "."], at: repo)
    }
    
    @discardableResult
    func add(file: String, at repo: String) async throws -> GitResult {
        try await run(["add", file], at: repo)
    }
    
    // Commit
    @discardableResult
    func commit(message: String, at repo: String) async throws -> GitResult {
        try await run(["commit", "-m", message], at: repo)
    }
    
    // Push / Pull
    @discardableResult
    func push(at repo: String) async throws -> GitResult {
        try await run(["push"], at: repo)
    }
    
    @discardableResult
    func forcePush(at repo: String) async throws -> GitResult {
        try await run(["push", "--force"], at: repo)
    }
    
    @discardableResult
    func pull(at repo: String) async throws -> GitResult {
        try await run(["pull"], at: repo)
    }
    
    @discardableResult
    func pull(branch: String, rebase: Bool = false, at repo: String) async throws -> GitResult {
        if rebase {
            return try await run(["pull", "--rebase", "origin", branch], at: repo)
        } else {
            return try await run(["pull", "origin", branch], at: repo)
        }
    }
    // Log
    func log(at repo: String) async throws -> [Commit] {
        let result = try await run([
            "log",
            "--pretty=format:%H|%h|%an <%ae>|%ad|%s",
            "--date=format:%a %b %d %H:%M:%S %Y %z"
        ], at: repo)
        return parseLog(result.output)
    }
    
    @discardableResult
    func fetch(at repo:String) async throws -> GitResult {
        try await run(["fetch"], at: repo)
    }
    
    @discardableResult
    func checkout(branch: String, at repo: String) async throws -> GitResult {
        try await run(["checkout", branch], at: repo)
    }
    
    @discardableResult
    func createBranch(branch: String, at repo: String) async throws -> GitResult {
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
    
    @discardableResult
    func rebaseContinue(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--continue"], at: repo)
    }
    
    @discardableResult
    func rebaseAbort(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--abort"], at: repo)
    }
    
    @discardableResult
    func rebaseSkip(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--skip"], at: repo)
    }
    // MARK: - Cherry-pick
    
    func cherryPick(commit: String, at repo: String) async throws -> GitResult {
        try await run(["cherry-pick", commit], at: repo)
    }
    
    @discardableResult
    func cherryPickContinue(at repo: String) async throws -> GitResult {
        try await run(["cherry-pick", "--continue"], at: repo)
    }
    
    @discardableResult
    func cherryPickAbort(at repo: String) async throws -> GitResult {
        try await run(["cherry-pick", "--abort"], at: repo)
    }
    
    @discardableResult
    func cherryPickSkip(at repo: String) async throws -> GitResult {
        try await run(["cherry-pick", "--skip"], at: repo)
    }
    
    // MARK: - Tags
    
    @discardableResult
    func createTag(name: String, at repo: String) async throws -> GitResult {
        try await run(["tag", name], at: repo)
    }
    
    @discardableResult
    func pushTag(name: String, at repo: String) async throws -> GitResult {
        try await run(["push", "origin", name], at: repo)
    }
    
    func listTags(at repo: String) async throws -> [String] {
        let result = try await run(["tag"], at: repo)
        return result.output.components(separatedBy: "\n")
    }
    
    // MARK: - Parsers
    
    private func parseStatus(_ output: String) -> [ChangedFile] {
        var files: [ChangedFile] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            guard line.count >= 4 else { continue }
            
            let indexStatus = line[line.startIndex]
            let worktreeStatus = line[line.index(line.startIndex, offsetBy: 1)]
            let filePath = String(line.suffix(from: line.index(line.startIndex, offsetBy: 3))).trimmingCharacters(in: .whitespacesAndNewlines)
            
            var cleanPath = filePath
            if cleanPath.hasPrefix("\"") && cleanPath.hasSuffix("\"") {
                cleanPath = String(cleanPath.dropFirst().dropLast())
            }
            
            var status = "Modified"
            var isStaged = false
            
            if indexStatus != " " && indexStatus != "?" {
                isStaged = true
            }
            
            switch (indexStatus, worktreeStatus) {
            case ("?", "?"):
                status = "Untracked"
            case ("A", _):
                status = "Added"
            case ("D", _), (_, "D"):
                status = "Deleted"
            case ("M", _), (_, "M"):
                status = "Modified"
            case ("R", _):
                status = "Renamed"
            default:
                status = "Modified"
            }
            
            files.append(ChangedFile(path: cleanPath, status: status, isStaged: isStaged))
        }
        return files
    }
    
    private func parseLog(_ output: String) -> [Commit] {
        var commits: [Commit] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let fields = line.components(separatedBy: "|")
            guard fields.count >= 5 else { continue }
            
            let id = fields[0]
            let shortHash = fields[1]
            let author = fields[2]
            let date = fields[3]
            
            // Reconstruct the message in case it contains '|' characters
            let message = fields[4...].joined(separator: "|")
            
            commits.append(Commit(
                id: id,
                shortHash: shortHash,
                author: author,
                date: date,
                message: message
            ))
        }
        return commits
    }
    
    // MARK: - Revert
    
    @discardableResult
    func revert(commit: String, at repo: String) async throws -> GitResult {
        try await run(["revert", "--no-edit", commit], at: repo)
    }
    
    // MARK: - Discard and Unstage
    
    @discardableResult
    func restoreStaged(file: String, at repo: String) async throws -> GitResult {
        try await run(["restore", "--staged", file], at: repo)
    }
    
    @discardableResult
    func discardChanges(at repo: String) async throws -> GitResult {
        let restoreResult = try await run(["restore", "."], at: repo)
        guard restoreResult.isSuccess else { return restoreResult }
        return try await run(["clean", "-df"], at: repo)
    }
    
    @discardableResult
    func discardChange(for file: ChangedFile, at repo: String) async throws -> GitResult {
        if file.isStaged {
            let unstageResult = try await restoreStaged(file: file.path, at: repo)
            guard unstageResult.isSuccess else { return unstageResult }
        }
        if file.status == "Untracked" {
            let fileURL = URL(fileURLWithPath: repo).appendingPathComponent(file.path)
            try? FileManager.default.removeItem(at: fileURL)
            return GitResult(output: "", error: "", exitCode: 0)
        } else {
            return try await run(["restore", file.path], at: repo)
        }
    }
}
