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
    func run(_ args: [String], at repoPath: String? = nil, stdin: Data? = nil, onOutput: (@Sendable (String) -> Void)? = nil) async throws -> GitResult {
        print("GitService: Running '/usr/bin/git \(args.joined(separator: " "))' at path: '\(repoPath ?? "default")'")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: gitPath)
        
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["GIT_EDITOR"] = "true"
        process.environment = env
        
        if let repoPath = repoPath {
            process.currentDirectoryURL = URL(fileURLWithPath: repoPath)
        }
        
        process.arguments = args
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if let stdin = stdin {
            let inputPipe = Pipe()
            process.standardInput = inputPipe
            do {
                try process.run()
                inputPipe.fileHandleForWriting.write(stdin)
                inputPipe.fileHandleForWriting.closeFile()
            } catch {
                print("GitService: Failed to start process: \(error.localizedDescription)")
                throw error
            }
        } else {
            do {
                try process.run()
            } catch {
                print("GitService: Failed to start process: \(error.localizedDescription)")
                throw error
            }
        }
        
        let outputTask = Task { () -> Data in
            var allData = Data()
            for try await line in outputPipe.fileHandleForReading.bytes.lines {
                let text = line + "\n"
                if let onOutput {
                    await MainActor.run { onOutput(text) }
                }
                if let data = text.data(using: .utf8) {
                    allData.append(data)
                }
            }
            return allData
        }
        
        let errorTask = Task { () -> Data in
            var allData = Data()
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                let text = line + "\n"
                if let onOutput {
                    await MainActor.run { onOutput(text) }
                }
                if let data = text.data(using: .utf8) {
                    allData.append(data)
                }
            }
            return allData
        }
        
        let outputData = (try? await outputTask.value) ?? Data()
        let errorData = (try? await errorTask.value) ?? Data()
        
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
    
    // Global Config
    func getGlobalConfig(key: String) async -> String? {
        let result = try? await run(["config", "--global", key])
        if let output = result?.output, !output.isEmpty, result?.isSuccess == true {
            return output
        }
        return nil
    }
    
    @discardableResult
    func setGlobalConfig(key: String, value: String) async throws -> GitResult {
        if value.isEmpty {
            return try await run(["config", "--global", "--unset", key])
        } else {
            return try await run(["config", "--global", key, value])
        }
    }
    
    // Authentication
    @discardableResult
    func registerPAT(username: String, token: String) async throws -> GitResult {
        // Ensure credential helper is osxkeychain globally
        try await setGlobalConfig(key: "credential.helper", value: "osxkeychain")
        
        let inputString = "protocol=https\nhost=github.com\nusername=\(username)\npassword=\(token)\n\n"
        if let data = inputString.data(using: .utf8) {
            return try await run(["credential", "approve"], stdin: data)
        }
        throw GitError.executionFailed("Failed to encode credentials")
    }

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
    func commit(message: String, at repo: String, onOutput: (@Sendable (String) -> Void)? = nil) async throws -> GitResult {
        try await run(["commit", "-m", message], at: repo, onOutput: onOutput)
    }
    
    // Push / Pull
    @discardableResult
    func push(at repo: String, branch: String? = nil, setUpstream: Bool = false, onOutput: (@Sendable (String) -> Void)? = nil) async throws -> GitResult {
        if let branch {
            if setUpstream {
                return try await run(["push", "-u", "origin", branch], at: repo, onOutput: onOutput)
            } else {
                return try await run(["push", "origin", branch], at: repo, onOutput: onOutput)
            }
        } else {
            return try await run(["push"], at: repo, onOutput: onOutput)
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
    
    @discardableResult
    func merge(branch: String, at repo: String) async throws -> GitResult {
        try await run(["merge", branch], at: repo)
    }
    
    @discardableResult
    func rebase(branch: String, at repo: String) async throws -> GitResult {
        try await run(["rebase", branch], at: repo)
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
    
    func hasUpstream(branch: String, at repo: String) async -> Bool {
        let result = try? await run(["rev-parse", "--abbrev-ref", "\(branch)@{u}"], at: repo)
        return result?.isSuccess == true
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
    
    // Commit Diff Files
    func getCommitFiles(hash: String, at repo: String) async throws -> [ChangedFile] {
        let args: [String]
        if hash.hasPrefix("stash@{") {
            args = ["diff", "--name-status", "\(hash)^1", hash]
        } else {
            args = ["diff-tree", "--no-commit-id", "--name-status", "-r", hash]
        }
        let result = try await run(args, at: repo)
        if !result.isSuccess && result.output.isEmpty {
            throw GitError.executionFailed(result.error)
        }
        return parseCommitFiles(result.output)
    }
    
    // Commit Diff
    func getCommitDiff(hash: String, file: String, at repo: String) async throws -> FileDiff {
        let args: [String]
        if hash.hasPrefix("stash@{") {
            args = ["diff", "\(hash)^1", hash, "--", file]
        } else {
            args = ["show", "--format=", hash, "--", file]
        }
        let result = try await run(args, at: repo)
        if !result.isSuccess && result.output.isEmpty {
            throw GitError.executionFailed(result.error)
        }
        return parseDiff(result.output)
    }
    
    // Diff
    func getDiff(for file: String, isStaged: Bool, at repo: String) async throws -> FileDiff {
        var args = ["diff"]
        if isStaged {
            args.append("--cached")
        }
        args.append(file)
        let result = try await run(args, at: repo)
        
        // If there's an error and no output, throw it
        if !result.isSuccess && result.output.isEmpty {
            throw GitError.executionFailed(result.error)
        }
        
        return parseDiff(result.output)
    }
    
    private func parseDiff(_ output: String) -> FileDiff {
        let lines = output.components(separatedBy: .newlines)
        var diffLines: [DiffLine] = []
        var oldLine: Int? = nil
        var newLine: Int? = nil
        var isNewFile = false
        var isDeletedFile = false
        
        for line in lines {
            if line.hasPrefix("diff --git") {
                diffLines.append(DiffLine(text: line, type: .fileHeader, oldLineNumber: nil, newLineNumber: nil))
            } else if line.hasPrefix("new file mode") {
                isNewFile = true
                diffLines.append(DiffLine(text: line, type: .fileHeader, oldLineNumber: nil, newLineNumber: nil))
            } else if line.hasPrefix("deleted file mode") {
                isDeletedFile = true
                diffLines.append(DiffLine(text: line, type: .fileHeader, oldLineNumber: nil, newLineNumber: nil))
            } else if line.hasPrefix("index") || line.hasPrefix("---") || line.hasPrefix("+++") {
                diffLines.append(DiffLine(text: line, type: .fileHeader, oldLineNumber: nil, newLineNumber: nil))
            } else if line.hasPrefix("@@") {
                // Parse hunk header
                // @@ -oldStart,oldLines +newStart,newLines @@
                diffLines.append(DiffLine(text: line, type: .hunkHeader, oldLineNumber: nil, newLineNumber: nil))
                
                // Extract line numbers using regex
                if let regex = try? NSRegularExpression(pattern: #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    if let oldRange = Range(match.range(at: 1), in: line), let oldStart = Int(line[oldRange]) {
                        oldLine = oldStart
                    }
                    if let newRange = Range(match.range(at: 2), in: line), let newStart = Int(line[newRange]) {
                        newLine = newStart
                    }
                }
            } else if line.hasPrefix("+") {
                diffLines.append(DiffLine(text: String(line.dropFirst()), type: .added, oldLineNumber: nil, newLineNumber: newLine))
                if newLine != nil { newLine! += 1 }
            } else if line.hasPrefix("-") {
                diffLines.append(DiffLine(text: String(line.dropFirst()), type: .removed, oldLineNumber: oldLine, newLineNumber: nil))
                if oldLine != nil { oldLine! += 1 }
            } else if line.hasPrefix(" ") {
                diffLines.append(DiffLine(text: String(line.dropFirst()), type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                if oldLine != nil { oldLine! += 1 }
                if newLine != nil { newLine! += 1 }
            } else if line.hasPrefix("\\ No newline at end of file") {
                diffLines.append(DiffLine(text: line, type: .context, oldLineNumber: nil, newLineNumber: nil))
            }
        }
        
        return FileDiff(lines: diffLines, isNewFile: isNewFile, isDeletedFile: isDeletedFile)
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
    
    func popStash(at repo: String,  id: String? = nil) async throws -> GitResult {
        if let id {
            return try await run(["stash", "pop", id], at: repo)
        } else {
            return try await run(["stash", "pop"], at: repo)
        }
    }
    
    func applyStash(at repo: String,  id: String? = nil) async throws -> GitResult {
        if let id {
            return try await run(["stash", "apply", id], at: repo)
        } else {
            return try await run(["stash", "apply"], at: repo)
        }
    }
    
    func dropStash(at repo: String, id: String? = nil) async throws -> GitResult {
        if let id {
            print(id)
            return try await run(["stash", "drop", id], at: repo)
        } else {
            return try await run(["stash", "drop"], at: repo)
        }
    }

    func showStashList(at repo: String) async throws -> [GitStash] {
        let result = try await run(["stash", "list"], at: repo)
        
        let results = result.output
            .split(separator: "\n")
            .compactMap { parseStash(String($0)) }
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

    private func parseCommitFiles(_ output: String) -> [ChangedFile] {
        var files: [ChangedFile] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            var parts = trimmed.components(separatedBy: "\t")
            if parts.count < 2 {
                parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            }
            guard parts.count >= 2 else { continue }
            
            let statusCode = parts[0]
            let filePath = parts.count > 2 && statusCode.hasPrefix("R") ? parts[2] : parts[1]
            
            var cleanPath = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanPath.hasPrefix("\"") && cleanPath.hasSuffix("\"") {
                cleanPath = String(cleanPath.dropFirst().dropLast())
            }
            
            var status = "Modified"
            let firstChar = statusCode.first.map(String.init) ?? "M"
            switch firstChar.uppercased() {
            case "A":
                status = "Added"
            case "D":
                status = "Deleted"
            case "M":
                status = "Modified"
            case "R":
                status = "Renamed"
            default:
                status = "Modified"
            }
            
            files.append(ChangedFile(path: cleanPath, status: status, isStaged: false))
        }
        return files
    }
    
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
            case ("U", _), (_, "U"), ("A", "A"), ("D", "D"):
                status = "Conflicted"
                isStaged = false
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
    
    // MARK: - Rebase Assistant helpers
    
    func getRebaseState(at repo: String) async -> RebaseState {
        let fileManager = FileManager.default
        let gitDir = (repo as NSString).appendingPathComponent(".git")
        
        let rebaseMergeDir = (gitDir as NSString).appendingPathComponent("rebase-merge")
        let rebaseApplyDir = (gitDir as NSString).appendingPathComponent("rebase-apply")
        
        let isMerge = fileManager.fileExists(atPath: rebaseMergeDir)
        let isApply = fileManager.fileExists(atPath: rebaseApplyDir)
        
        guard isMerge || isApply else {
            return RebaseState(
                inProgress: false,
                currentCommitHash: "",
                currentCommitMessage: "",
                currentProgress: 0,
                totalProgress: 0,
                ontoBranch: "",
                headName: ""
            )
        }
        
        let rebaseDir = isMerge ? rebaseMergeDir : rebaseApplyDir
        
        func readFile(_ name: String) -> String {
            let path = (rebaseDir as NSString).appendingPathComponent(name)
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                return ""
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let msgnum = Int(readFile("msgnum")) ?? 0
        let end = Int(readFile("end")) ?? 0
        let onto = readFile("onto")
        let headName = readFile("head-name")
        let stoppedSha = readFile("stopped-sha")
        
        var commitMsg = ""
        if !stoppedSha.isEmpty {
            let result = try? await run(["log", "--format=%s", "-n", "1", stoppedSha], at: repo)
            if let output = result?.output, !output.isEmpty {
                commitMsg = output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return RebaseState(
            inProgress: true,
            currentCommitHash: stoppedSha,
            currentCommitMessage: commitMsg,
            currentProgress: msgnum,
            totalProgress: end,
            ontoBranch: onto,
            headName: headName
        )
    }
    
    func setRebaseMessage(_ message: String, at repo: String) throws {
        let fileManager = FileManager.default
        let gitDir = (repo as NSString).appendingPathComponent(".git")
        
        let rebaseMergeDir = (gitDir as NSString).appendingPathComponent("rebase-merge")
        let rebaseApplyDir = (gitDir as NSString).appendingPathComponent("rebase-apply")
        
        let isMerge = fileManager.fileExists(atPath: rebaseMergeDir)
        let rebaseDir = isMerge ? rebaseMergeDir : rebaseApplyDir
        
        let path = (rebaseDir as NSString).appendingPathComponent("message")
        try message.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    func isConflictResolved(file: String, at repo: String) -> Bool {
        let filePath = (repo as NSString).appendingPathComponent(file)
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return true
        }
        return !content.contains("<<<<<<<") && !content.contains("=======") && !content.contains(">>>>>>>")
    }
    
    @discardableResult
    func continueRebase(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--continue"], at: repo)
    }
    
    @discardableResult
    func skipRebase(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--skip"], at: repo)
    }
    
    @discardableResult
    func abortRebase(at repo: String) async throws -> GitResult {
        try await run(["rebase", "--abort"], at: repo)
    }
    
    // MARK: - Merge Assistant helpers
    
    func getMergeState(at repo: String) async -> MergeState {
        let fileManager = FileManager.default
        let gitDir = (repo as NSString).appendingPathComponent(".git")
        let mergeHeadPath = (gitDir as NSString).appendingPathComponent("MERGE_HEAD")
        
        guard fileManager.fileExists(atPath: mergeHeadPath) else {
            return MergeState(
                inProgress: false,
                sourceBranch: "",
                targetBranch: "",
                currentCommitHash: "",
                defaultCommitMessage: ""
            )
        }
        
        let mergeHead = (try? String(contentsOfFile: mergeHeadPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        let mergeMsgPath = (gitDir as NSString).appendingPathComponent("MERGE_MSG")
        let mergeMsg = (try? String(contentsOfFile: mergeMsgPath, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        var targetBranch = ""
        if let result = try? await run(["rev-parse", "--abbrev-ref", "HEAD"], at: repo), result.isSuccess {
            targetBranch = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var sourceBranch = ""
        if let result = try? await run(["name-rev", "--name-only", mergeHead], at: repo), result.isSuccess {
            let name = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            sourceBranch = name.components(separatedBy: "/").last ?? name
        }
        
        if sourceBranch.isEmpty || sourceBranch.hasPrefix("undefined") {
            if let firstLine = mergeMsg.components(separatedBy: .newlines).first {
                let pattern = "'([^']+)'"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
                   let range = Range(match.range(at: 1), in: firstLine) {
                    sourceBranch = String(firstLine[range])
                }
            }
        }
        
        if sourceBranch.isEmpty {
            sourceBranch = String(mergeHead.prefix(7))
        }
        
        return MergeState(
            inProgress: true,
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            currentCommitHash: mergeHead,
            defaultCommitMessage: mergeMsg
        )
    }
    
    func setMergeMessage(_ message: String, at repo: String) throws {
        let gitDir = (repo as NSString).appendingPathComponent(".git")
        let path = (gitDir as NSString).appendingPathComponent("MERGE_MSG")
        try message.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    @discardableResult
    func continueMerge(at repo: String) async throws -> GitResult {
        try await run(["merge", "--continue"], at: repo)
    }
    
    @discardableResult
    func abortMerge(at repo: String) async throws -> GitResult {
        try await run(["merge", "--abort"], at: repo)
    }
}
