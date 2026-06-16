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
            output: output.trimmingCharacters(in: .newlines),
            error: error.trimmingCharacters(in: .newlines),
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
    func push(at repo: String, branch: String? = nil) async throws -> GitResult {
        if let branch {
            return try await run(["push", "origin", branch], at: repo)
        } else {
            return try await run(["push"], at: repo)
        }
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
    func log(branch: String? = nil, at repo: String) async throws -> [Commit] {
        var args = [
            "log",
            "--pretty=format:%H|%h|%an <%ae>|%ad|%s",
            "--date=format:%a %b %d %H:%M:%S %Y %z"
        ]
        if let branch = branch {
            args.append(branch)
        }
        let result = try await run(args, at: repo)
        return parseLog(result.output)
    }
    
    // Get unpushed commits
    func getUnpushedCommits(branch: String, at repo: String) async -> Set<String> {
        let result = try? await run(["log", branch, "--not", "--remotes", "--format=%H"], at: repo)
        guard let output = result?.output, result?.isSuccess == true else {
            return []
        }
        let hashes = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Set(hashes)
    }
    
    @discardableResult
    func fetch(at repo:String) async throws -> GitResult {
        try await run(["fetch"], at: repo)
    }
    @discardableResult
    func checkout(branch: String, trackRemote: Bool = false, at repo: String) async throws -> GitResult {
        if trackRemote {
            return try await run(["checkout", "-t", branch], at: repo)
        } else {
            return try await run(["checkout", branch], at: repo)
        }
    }
    
    @discardableResult
    func createBranch(branch: String, from sourceBranch: String? = nil, at repo: String) async throws -> GitResult {
        if let sourceBranch = sourceBranch, !sourceBranch.isEmpty {
            return try await run(["checkout", "-b", branch, sourceBranch], at: repo)
        } else {
            return try await run(["checkout", "-b", branch], at: repo)
        }
    }
    
    @discardableResult
    func deleteBranch(branch: String, force: Bool = false, isRemote: Bool = false, at repo: String) async throws -> GitResult {
        if isRemote {
            let parts = branch.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { throw GitError.executionFailed("Invalid remote branch name") }
            let remote = String(parts[0])
            let remoteBranch = String(parts[1])
            return try await run(["push", remote, "--delete", remoteBranch], at: repo)
        } else {
            if force {
                return try await run(["branch", "-D", branch], at: repo)
            } else {
                return try await run(["branch", "-d", branch], at: repo)
            }
        }
    }
    
    @discardableResult
    func renameBranch(oldName: String, newName: String, isRemote: Bool = false, at repo: String) async throws -> GitResult {
        if isRemote {
            let parts = oldName.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { throw GitError.executionFailed("Invalid remote branch name") }
            let remote = String(parts[0])
            let remoteBranch = String(parts[1])
            _ = try await run(["push", remote, "\(oldName):refs/heads/\(newName)"], at: repo)
            return try await run(["push", remote, "--delete", remoteBranch], at: repo)
        } else {
            return try await run(["branch", "-m", oldName, newName], at: repo)
        }
    }
    
    func getLocalBranches(at repo: String) async throws -> [String] {
        let result = try await run(["branch", "-l"], at: repo)
        return result.output.split(separator: "\n").map(String.init)
    }
    
    func getRemoteBranches(at repo: String) async throws -> [String] {
        let result = try await run(["branch", "-r"], at: repo)
        return result.output.split(separator: "\n")
            .map(String.init)
            .filter { !$0.contains("->") }
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
    
    func stash(at repo: String, message: String? = nil) async throws -> GitResult {
        if let message {
            return try await run(["stash","-m", message], at: repo)
        } else {
            return try await run(["stash"], at: repo)
        }
    }
    
    func popStash(at repo: String, index: Int? = nil) async throws -> GitResult {
        if let index {
            return try await run(["stash", "pop", "stash@{\(index)}"], at: repo)
        } else {
            return try await run(["stash", "pop"], at: repo)
        }
    }
    
    func applyStash(at repo: String, index: Int? = nil) async throws -> GitResult {
        if let index {
            return try await run(["stash", "apply", "stash@{\(index)}"], at: repo)
        } else {
            return try await run(["stash", "apply"], at: repo)
        }
    }
    
    func dropStash(at repo: String, index: Int? = nil) async throws -> GitResult {
        if let index {
            return try await run(["stash", "drop", "stash@{\(index)}"], at: repo)
        } else {
            return try await run(["stash", "drop"], at: repo)
        }
    }

    func showStashList(at repo: String) async throws -> [GitStash] {
        let result = try await run(["stash", "list"], at: repo)
        
        let results = result.output
            .split(separator: "\n")
            .compactMap { parseStash(String($0)) }
        dump(results)
        return results
    }

    private func parseStash(_ line: String) -> GitStash? {
        let pattern = #"^(stash@\{\d+\}):\s+(WIP on|On)\s+(.+?):\s*(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: line,
                  range: NSRange(line.startIndex..., in: line)
              ) else {
            return nil
        }

        func value(at index: Int) -> String {
            guard let range = Range(match.range(at: index), in: line) else {
                return ""
            }
            return String(line[range])
        }

        return GitStash(
            id: value(at: 1),
            type: value(at: 2),
            branch: value(at: 3),
            message: value(at: 4)
        )
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
    
    // MARK: - Revert & Reset
    
    @discardableResult
    func revert(commit: String, at repo: String) async throws -> GitResult {
        try await run(["revert", "--no-edit", commit], at: repo)
    }
    
    @discardableResult
    func reset(commit: String, hard: Bool = false, at repo: String) async throws -> GitResult {
        if hard {
            return try await run(["reset", "--hard", commit], at: repo)
        } else {
            return try await run(["reset", "--soft", commit], at: repo)
        }
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
