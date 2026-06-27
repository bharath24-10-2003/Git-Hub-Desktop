//
//  MainViewModel.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import Foundation
import AppKit
import SwiftUI

@Observable
class MainViewModel {
    
    var service: GitService
    var store: RepoStore
    
    // MARK: - Reactive Repository States
    private var lastLoadedRepoId: UUID? = nil
    
    var selectedRepo: Repo? = nil {
        didSet {
            if let repo = selectedRepo {
                if repo.id != lastLoadedRepoId {
                    lastLoadedRepoId = repo.id
                    store.markOpened(repo)
                    Task {
                        await loadRepositoryData(for: repo)
                    }
                }
            }
        }
    }
    
    var currentBranch: String = ""
    var changedFiles: [ChangedFile] = []
    var commits: [Commit] = []
    var stashes: [GitStash] = []
    var localBranches: [String] = []
    var remoteBranches: [String] = []
    
    var isCloning: Bool = false
    var isLoading: Bool = false
    var loadingMessage: String = "Loading..."
    var isStreamingHooks: Bool = false
    var hookTasks: [HookTask] = []
    
    var isCherryPicking: Bool = false
    var currentGitError: GitAnalyzedError? = nil
    var historyBranch: String? = nil
    var unPushedCommits: Int = 0
    var hasUpstream: Bool = true
    var rebaseState = RebaseState(inProgress: false, currentCommitHash: "", currentCommitMessage: "", currentProgress: 0, totalProgress: 0, ontoBranch: "", headName: "")
    var mergeState = MergeState(inProgress: false, sourceBranch: "", targetBranch: "", currentCommitHash: "", defaultCommitMessage: "")
    
    // MARK: - Diff State
    var selectedFileForDiff: ChangedFile? = nil
    var currentDiff: FileDiff? = nil
    var isDiffLoading: Bool = false
    
    var selectedBranchForAction: String? = nil
    var isRemoteBranchAction: Bool = false
    var activeSection: RepoSection = .changes
    
    init () {
        self.service = GitService()
        self.store = RepoStore()
        if let initialRepo = store.repos.first {
            self.selectedRepo = initialRepo
            self.lastLoadedRepoId = initialRepo.id
        }
    }
    
    func getRepoCollection() -> [Repo] {
        return store.repos
    }
    
    // MARK: - Asynchronous Data Loader
    
    func loadRepositoryData(for repo: Repo) async {
        self.loadingMessage = "Loading repository data..."
        self.currentGitError = nil
        
        defer {
            self.isLoading = false
        }
        
        do {
            await loadCoreData(for: repo)
            
            switch activeSection {
            case .changes:
                try await loadChanges(for: repo)
            case .history:
                try await loadHistory(for: repo)
            case .branches:
                break // core data handles branches
            case .stashes:
                try await loadStashes(for: repo)
            }
            
            // Update active branch name in RepoStore so it persists
            if let index = store.repos.firstIndex(where: { $0.id == repo.id }) {
                store.repos[index].currentBranch = self.currentBranch
            }
        } catch {
            self.handleError(error)
        }
    }
    
    private func loadCoreData(for repo: Repo) async {
        let path = repo.path
        do {
            let rawLocalBranches = try await service.getLocalBranches(at: path)
            var cleanLocal: [String] = []
            var detectedCurrentBranch = "main"
            
            for raw in rawLocalBranches {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("* ") {
                    let branchName = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    detectedCurrentBranch = branchName
                    cleanLocal.append(branchName)
                } else {
                    let clean = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        cleanLocal.append(clean)
                    }
                }
            }
            
            let rawRemoteBranches = try await service.getRemoteBranches(at: path)
            let cleanRemote = rawRemoteBranches.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            
            let cherryPickPath = URL(fileURLWithPath: path).appendingPathComponent(".git/CHERRY_PICK_HEAD").path
            let isCherryPickInProgress = FileManager.default.fileExists(atPath: cherryPickPath)
            
            let rebaseState = await service.getRebaseState(at: path)
            let mergeState = await service.getMergeState(at: path)
            
            let unpushedCount = await service.getUnpushedCommits(branch: detectedCurrentBranch, at: path).count
            let hasUpstream = await service.hasUpstream(branch: detectedCurrentBranch, at: path)
            
            self.localBranches = cleanLocal
            self.remoteBranches = cleanRemote
            self.currentBranch = detectedCurrentBranch
            self.isCherryPicking = isCherryPickInProgress
            self.rebaseState = rebaseState
            self.mergeState = mergeState
            self.unPushedCommits = unpushedCount
            self.hasUpstream = hasUpstream
        } catch {
            self.handleError(error)
            print("Failed to load repo core data:", error)
        }
    }
    
    private func loadChanges(for repo: Repo) async throws {
        let path = repo.path
        let files = try await service.status(at: path)
        self.changedFiles = files
        
        // Clear diff if selected file no longer exists or select first file
        if let selected = self.selectedFileForDiff {
            if let updatedFile = files.first(where: { $0.id == selected.id }) {
                self.selectedFileForDiff = updatedFile
                Task {
                    try? await self.loadDiff(for: updatedFile, at: repo)
                }
            } else {
                if let firstFile = files.first {
                    self.selectedFileForDiff = firstFile
                    Task {
                        try? await self.loadDiff(for: firstFile, at: repo)
                    }
                } else {
                    self.selectedFileForDiff = nil
                    self.currentDiff = nil
                }
            }
        } else {
            if let firstFile = files.first {
                self.selectedFileForDiff = firstFile
                Task {
                    try? await self.loadDiff(for: firstFile, at: repo)
                }
            }
        }
    }
    
    private func loadHistory(for repo: Repo) async throws {
        let path = repo.path
        let branchForLog = self.historyBranch ?? self.currentBranch
        var commitHistory = try await service.log(branch: branchForLog, at: path)
        let unpushedCommits = await service.getUnpushedCommits(branch: branchForLog, at: path)
        self.unPushedCommits = unpushedCommits.count
        for i in 0..<commitHistory.count {
            if unpushedCommits.contains(commitHistory[i].id) {
                commitHistory[i].isPushed = false
            }
        }
        self.commits = commitHistory
    }
    
    private func loadStashes(for repo: Repo) async throws {
        let path = repo.path
        self.stashes = try await service.showStashList(at: path)
    }
    
    // MARK: - Diff
    
    func loadDiff(for file: ChangedFile, at repo: Repo) async throws {
        self.isDiffLoading = true
        
        do {
            let diff = try await service.getDiff(for: file.path, isStaged: file.isStaged, at: repo.path)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                self.selectedFileForDiff = file
                self.currentDiff = diff
                self.isDiffLoading = false
            }
        } catch {
            self.isDiffLoading = false
            self.handleError(error)
            throw error
        }
    }
    
    func getCommitFiles(hash: String, at repo: Repo) async throws -> [ChangedFile] {
        return try await service.getCommitFiles(hash: hash, at: repo.path)
    }
    
    func loadCommitDiff(hash: String, file: String, at repo: Repo) async throws -> FileDiff {
        return try await service.getCommitDiff(hash: hash, file: file, at: repo.path)
    }
    
    // MARK: - Asynchronous Git Actions
    
    // MARK: - Smart Error Handling (removed extractErrorMessage)
    @discardableResult
    func cloneRepo(url: String, destinationPath: String) async -> GitResult? {
        self.isCloning = true
        self.currentGitError = nil
        
        defer {
            self.isCloning = false
        }
        
        do {
            let repoName = extractRepoName(from: url)
            var finalPath = destinationPath
            let pathURL = URL(fileURLWithPath: destinationPath)
            if pathURL.lastPathComponent != repoName {
                finalPath = pathURL.appendingPathComponent(repoName).path
            }
            
            let result = try await service.clone(url: url, to: finalPath)
            
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
                return result
            }
            
            store.addRepo(name: repoName, path: finalPath)
            self.selectedRepo = store.repos.first(where: { $0.path == finalPath })
            return result
        } catch {
            self.handleError(error)
            return nil
        }
    }
    
    func addExistingRepo(name: String, path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        store.addRepo(name: name, path: path)
        self.selectedRepo = store.repos.first(where: { $0.path == path })
    }
    
    func removeRepository(_ repo: Repo) {
        store.removeRepo(repo)
        if selectedRepo?.id == repo.id {
            selectedRepo = store.repos.first
        }
    }
    
    @discardableResult
    func stageAll(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Staging all changes..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.addAll(at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func stage(file: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Staging file..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.add(file: file, at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func unstage(file: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Unstaging file..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.restoreStaged(file: file, at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func stageSelected(files: [String], at repo: Repo) async throws -> GitResult {
        guard !files.isEmpty else { return GitResult(output: "", error: "", exitCode: 0) }
        self.loadingMessage = "Staging selected changes..."
        self.isLoading = true
        defer { self.isLoading = false }
        var lastResult: GitResult? = nil
        for file in files {
            let result = try await service.add(file: file, at: repo.path)
            lastResult = result
            if !result.isSuccess {
                throw GitErrorAnalyzer.analyze(result: result)
            }
        }
        await loadRepositoryData(for: repo)
        return lastResult!
    }
    
    @discardableResult
    func discardAllChanges(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Discarding all changes..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.discardChanges(at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func discardChange(for file: ChangedFile, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Discarding change..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.discardChange(for: file, at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func commitChanges(message: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Committing changes..."
        self.isLoading = true
        self.isStreamingHooks = false
        self.hookTasks = []
        defer {
            self.isLoading = false
            self.isStreamingHooks = false
        }
        let result = try await service.commit(message: message, at: repo.path) { @Sendable [weak self] line in
            Task { @MainActor in
                self?.parseHookOutput(line: line)
            }
        }
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func fetch(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Fetching updates..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.fetch(at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func pull(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Pulling changes..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result: GitResult
        if !currentBranch.isEmpty {
            result = try await service.pull(branch: currentBranch, at: repo.path)
        } else {
            result = try await service.pull(at: repo.path)
        }
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func pull(name: String, rebase: Bool = false, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Pulling changes..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result: GitResult
        if rebase {
            result = try await service.pull(branch: name, rebase: true, at: repo.path)
        } else {
            result = try await service.pull(branch: name, at: repo.path)
        }
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func mergeBranch(name: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Merging branch..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.merge(branch: name, at: repo.path)
        await loadRepositoryData(for: repo)
        if !result.isSuccess {
            if mergeState.inProgress || rebaseState.inProgress {
                return result
            }
            throw GitErrorAnalyzer.analyze(result: result)
        }
        return result
    }
    
    @discardableResult
    func rebaseBranch(name: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Rebasing branch..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.rebase(branch: name, at: repo.path)
        await loadRepositoryData(for: repo)
        if !result.isSuccess {
            if rebaseState.inProgress || mergeState.inProgress {
                return result
            }
            throw GitErrorAnalyzer.analyze(result: result)
        }
        return result
    }
    
    @discardableResult
    func push(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Pushing commits..."
        self.isLoading = true
        self.isStreamingHooks = false
        self.hookTasks = []
        defer {
            self.isLoading = false
            self.isStreamingHooks = false
        }
        let result: GitResult
        if !currentBranch.isEmpty {
            result = try await service.push(at: repo.path, branch: currentBranch, setUpstream: !hasUpstream) { @Sendable [weak self] line in
                Task { @MainActor in
                    self?.parseHookOutput(line: line)
                }
            }
        } else {
            result = try await service.push(at: repo.path) { @Sendable [weak self] line in
                Task { @MainActor in
                    self?.parseHookOutput(line: line)
                }
            }
        }
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func forcePush(at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Force pushing commits..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result = try await service.forcePush(at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func checkout(branch: String, at repo: Repo) async throws -> GitResult {
        self.loadingMessage = "Checking out branch..."
        self.isLoading = true
        defer { self.isLoading = false }
        let result: GitResult
        if remoteBranches.contains(branch) && !localBranches.contains(branch) {
            result = try await service.checkout(branch: branch, trackRemote: true, at: repo.path)
        } else {
            result = try await service.checkout(branch: branch, at: repo.path)
        }
        
        if !result.isSuccess {
            throw GitError.executionFailed(result.error)
        }
        
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func createBranch(name: String, from sourceBranch: String? = nil, at repo: Repo) async throws -> GitResult {
        let result = try await service.createBranch(branch: name, from: sourceBranch, at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    func showStash(at repo: Repo) async throws -> [GitStash] {
        let result = try await service.showStashList(at: repo.path)
        await loadRepositoryData(for: repo)
        return result
    }
    
    func stash(at repo: Repo, message: String? = nil) async throws -> GitResult {
        let result = try await service.stash(at: repo.path, message: message)
        await loadRepositoryData(for: repo)
        return result
    }
    
    func applyStash(at repo: Repo, id: String? = nil) async throws -> GitResult {
        let result = try await service.applyStash(at: repo.path, id: id)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    func popStash(at repo: Repo, id: String? = nil) async throws -> GitResult {
        let result = try await service.popStash(at: repo.path, id: id)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    func dropStash(at repo: Repo, id: String? = nil) async throws -> GitResult {
        let result = try await service.dropStash(at: repo.path, id: id)
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func revertCommit(_ hash: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.revert(commit: hash, at: repo.path)
            if !result.isSuccess {
                throw GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func resetCommit(_ hash: String, hard: Bool = false, at repo: Repo) async throws -> GitResult {
        let result = try await service.reset(commit: hash, hard: hard, at: repo.path)
        if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func cherryPickCommit(_ hash: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPick(commit: hash, at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickContinue(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickContinue(at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickAbort(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickAbort(at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickSkip(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickSkip(at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func deleteBranch(branch: String, force: Bool = false, isRemote: Bool = false, at repo: Repo) async throws -> GitResult {
        let result = try await service.deleteBranch(branch: branch, force: force, isRemote: isRemote, at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func renameBranch(oldName: String, newName: String, isRemote: Bool = false, at repo: Repo) async throws -> GitResult {
        let result = try await service.renameBranch(oldName: oldName, newName: newName, isRemote: isRemote, at: repo.path)
            if !result.isSuccess {
            throw GitErrorAnalyzer.analyze(result: result)
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    // MARK: - Helper Methods
    
    func selectFolder() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        let response = panel.runModal()
        
        if response == .OK {
            return panel.url?.path
        }
        
        return nil
    }
    
    func extractRepoName(from url: String) -> String {
        var urlString = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if urlString.hasSuffix(".git") {
            urlString = String(urlString.dropLast(4))
        }
        
        if let lastSlash = urlString.lastIndex(of: "/") {
            let nextIndex = urlString.index(after: lastSlash)
            return String(urlString[nextIndex...])
        }
        
        if let lastColon = urlString.lastIndex(of: ":") {
            let nextIndex = urlString.index(after: lastColon)
            return String(urlString[nextIndex...])
        }
        
        return urlString
    }
    
    // MARK: - Rebase Actions
    
    func continueRebase(at repo: Repo) async {
        self.loadingMessage = "Continuing rebase..."
        self.isLoading = true
        self.currentGitError = nil
        do {
            let result = try await service.continueRebase(at: repo.path)
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
        } catch {
            self.handleError(error)
            self.isLoading = false
        }
    }
    
    func skipRebase(at repo: Repo) async {
        self.loadingMessage = "Skipping commit..."
        self.isLoading = true
        self.currentGitError = nil
        do {
            let result = try await service.skipRebase(at: repo.path)
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
        } catch {
            self.handleError(error)
            self.isLoading = false
        }
    }
    
    func abortRebase(at repo: Repo) async {
        self.loadingMessage = "Aborting rebase..."
        self.isLoading = true
        self.currentGitError = nil
        do {
            let result = try await service.abortRebase(at: repo.path)
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
        } catch {
            self.handleError(error)
            self.isLoading = false
        }
    }
    
    func setRebaseMessage(_ message: String, at repo: Repo) {
        do {
            try service.setRebaseMessage(message, at: repo.path)
            // Refresh rebaseState details locally
            self.rebaseState.currentCommitMessage = message
        } catch {
            self.handleError(error)
        }
    }
    
    func isConflictResolved(file: String, at repo: Repo) -> Bool {
        return service.isConflictResolved(file: file, at: repo.path)
    }
    
    // MARK: - Merge Actions
    
    func continueMerge(at repo: Repo) async {
        self.loadingMessage = "Continuing merge..."
        self.isLoading = true
        self.currentGitError = nil
        do {
            let result = try await service.continueMerge(at: repo.path)
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
        } catch {
            self.handleError(error)
            self.isLoading = false
        }
    }
    
    func abortMerge(at repo: Repo) async {
        self.loadingMessage = "Aborting merge..."
        self.isLoading = true
        self.currentGitError = nil
        do {
            let result = try await service.abortMerge(at: repo.path)
            if !result.isSuccess {
                self.currentGitError = GitErrorAnalyzer.analyze(result: result)
            }
            await loadRepositoryData(for: repo)
        } catch {
            self.handleError(error)
            self.isLoading = false
        }
    }
    
    func setMergeMessage(_ message: String, at repo: Repo) {
        do {
            try service.setMergeMessage(message, at: repo.path)
            self.mergeState.defaultCommitMessage = message
        } catch {
            self.handleError(error)
        }
    }
}

// MARK: - Git Hook Parsing
extension MainViewModel {
    func parseHookOutput(line: String) {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        
        // Ensure we switch to streaming view
        if !isStreamingHooks {
            isStreamingHooks = true
        }
        
        let lower = text.lowercased()
        
        // Heuristics for finding task names
        var taskName = text
        var status: HookStatus = .running
        
        if let dotIndex = text.range(of: "...") {
            taskName = String(text[..<dotIndex.lowerBound]).trimmingCharacters(in: .whitespaces)
        } else if text.hasPrefix("Running ") {
            taskName = text
        } else {
            // Keep it simple if it's just raw output
        }
        
        if lower.hasSuffix("passed") {
            status = .passed
        } else if lower.hasSuffix("failed") {
            status = .failed
        } else if lower.hasSuffix("skipped") {
            status = .skipped
        } else if lower.contains("running") {
            status = .running
        } else {
            // If we don't detect a clear status at the end, and we already know this task, keep it running.
            // Wait, if it has no dots and doesn't match above, it's just arbitrary log output.
            if !hookTasks.isEmpty {
                hookTasks[hookTasks.count - 1].rawOutput.append(text)
                return
            }
        }
        
        // Find existing or create new
        if let idx = hookTasks.firstIndex(where: { $0.name == taskName }) {
            hookTasks[idx].status = status
            hookTasks[idx].rawOutput.append(text)
        } else {
            let newTask = HookTask(name: taskName, status: status, rawOutput: [text])
            hookTasks.append(newTask)
        }
    }

    // MARK: - Smart Error Handling
    
    @MainActor
    func handleError(_ error: Error) {
        if let gitError = error as? GitAnalyzedError {
            self.currentGitError = gitError
        } else if let gitError = error as? GitError {
            self.currentGitError = GitAnalyzedError(type: .unknown, title: "Git Error", description: gitError.localizedDescription, reason: nil, suggestedFix: nil, primaryAction: .dismiss, secondaryAction: nil, rawOutput: "")
        } else {
            self.currentGitError = GitAnalyzedError(type: .unknown, title: "Error", description: error.localizedDescription, reason: nil, suggestedFix: nil, primaryAction: .dismiss, secondaryAction: nil, rawOutput: "")
        }
    }
    
    @MainActor
    func handleRecoveryAction(_ action: GitRecoveryAction) {
        self.currentGitError = nil
        
        Task {
            switch action {
            case .stageAllAndCommit:
                if let repo = selectedRepo {
                    do {
                        try await service.run(["add", "."], at: repo.path)
                        // Trigger commit view or commit directly if we have a message?
                        // For safety, let's just open changes so user can commit.
                    } catch {}
                }
            case .openChanges:
                // Do nothing, UI is already there or we just dismiss
                break
            case .returnToCommitEditor:
                break
            case .pullAndRebase:
                if let repo = selectedRepo {
                    let branchName = self.currentBranch.isEmpty ? repo.currentBranch : self.currentBranch
                    do {
                        _ = try await pull(name: branchName, rebase: true, at: repo)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .pullAndMerge:
                if let repo = selectedRepo {
                    let branchName = self.currentBranch.isEmpty ? repo.currentBranch : self.currentBranch
                    do {
                        _ = try await pull(name: branchName, rebase: false, at: repo)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .forcePush:
                if let repo = selectedRepo {
                    let branchName = self.currentBranch.isEmpty ? repo.currentBranch : self.currentBranch
                    do {
                        let remote = "origin"
                        _ = try await service.run(["push", remote, branchName, "--force"], at: repo.path)
                        await loadRepositoryData(for: repo)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .openMergeAssistant, .openRebaseAssistant, .openCherryPickAssistant:
                break
            case .abortMerge:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["merge", "--abort"], at: repo.path) } catch {}
                }
            case .abortRebase:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["rebase", "--abort"], at: repo.path) } catch {}
                }
            case .skipCommit:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["rebase", "--skip"], at: repo.path) } catch {}
                }
            case .abortCherryPick:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["cherry-pick", "--abort"], at: repo.path) } catch {}
                }
            case .createBranch, .checkoutExistingBranch, .renameBranch:
                break
            case .stashChanges:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["stash"], at: repo.path) } catch {}
                }
            case .discardFiles:
                if let repo = selectedRepo {
                    do { _ = try await service.run(["reset", "--hard"], at: repo.path) } catch {}
                }
            case .updateCredentials, .retry, .editRemoteURL, .openNetworkSettings, .pushAndSetUpstream, .viewFullLog, .openRepository, .dismiss:
                break
            }
            
            // Reload if needed
            if let repo = selectedRepo {
                await loadRepositoryData(for: repo)
            }
        }
    }

}
