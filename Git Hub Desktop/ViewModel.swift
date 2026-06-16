//
//  ViewModel.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import Foundation
import AppKit

@Observable
class ViewModel {
    
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
    var isCherryPicking: Bool = false
    var errorMessage: String? = nil
    
    // MARK: - Presentation Flags
    var showCloneModal: Bool = false
    var showAddRepoModal: Bool = false
    var showNewBranchModal: Bool = false
    var showMergeModal: Bool = false
    var showRebaseModal: Bool = false
    var showDeleteBranchModal: Bool = false
    var showRenameBranchModal: Bool = false
    
    var selectedBranchForAction: String? = nil
    var isRemoteBranchAction: Bool = false
    
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
        self.isLoading = true
        self.errorMessage = nil
        
        defer {
            self.isLoading = false
        }
        
        do {
            let path = repo.path
            
            // 1. Local branches & active branch identification
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
            
            // 2. Remote branches
            let rawRemoteBranches = try await service.getRemoteBranches(at: path)
            let cleanRemote = rawRemoteBranches.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            
            // 3. Status changes
            let files = try await service.status(at: path)
            
            // 4. Log history
            let commitHistory = try await service.log(at: path)
            
            // 5. Check if cherry-pick is in progress
            let cherryPickPath = URL(fileURLWithPath: path).appendingPathComponent(".git/CHERRY_PICK_HEAD").path
            let isCherryPickInProgress = FileManager.default.fileExists(atPath: cherryPickPath)
            
            // 6. Stashes
            let stashes = try await service.showStashList(at: path)
            
            self.localBranches = cleanLocal
            self.remoteBranches = cleanRemote
            self.currentBranch = detectedCurrentBranch
            self.changedFiles = files
            self.commits = commitHistory
            self.isCherryPicking = isCherryPickInProgress
            self.stashes = stashes
            
            // Update active branch name in RepoStore so it persists
            if let index = store.repos.firstIndex(where: { $0.id == repo.id }) {
                store.repos[index].currentBranch = detectedCurrentBranch
            }
        } catch {
            self.errorMessage = error.localizedDescription
            print("Failed to load repo data:", error)
        }
    }
    
    // MARK: - Asynchronous Git Actions
    
    private func extractErrorMessage(from result: GitResult) -> String {
        if !result.error.isEmpty { return result.error }
        if !result.output.isEmpty { return result.output }
        return "Unknown Git error"
    }
    
    @discardableResult
    func cloneRepo(url: String, destinationPath: String) async -> GitResult? {
        self.isCloning = true
        self.errorMessage = nil
        
        defer {
            self.isCloning = false
        }
        
        do {
            let result = try await service.clone(url: url, to: destinationPath)
            
            if !result.isSuccess {
                self.errorMessage = extractErrorMessage(from: result)
                return result
            }
            
            let repoName = extractRepoName(from: url)
            store.addRepo(name: repoName, path: destinationPath)
            self.selectedRepo = store.repos.first(where: { $0.path == destinationPath })
            return result
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func addExistingRepo(name: String, path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        store.addRepo(name: name, path: path)
        self.selectedRepo = store.repos.first(where: { $0.path == path })
    }
    
    @discardableResult
    func stageAll(at repo: Repo) async throws -> GitResult {
        let result = try await service.addAll(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func stage(file: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.add(file: file, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func unstage(file: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.restoreStaged(file: file, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func stageSelected(files: [String], at repo: Repo) async throws -> GitResult {
        guard !files.isEmpty else { return GitResult(output: "", error: "", exitCode: 0) }
        var lastResult: GitResult? = nil
        for file in files {
            let result = try await service.add(file: file, at: repo.path)
            lastResult = result
            if !result.isSuccess {
                throw GitError.executionFailed(extractErrorMessage(from: result))
            }
        }
        await loadRepositoryData(for: repo)
        return lastResult!
    }
    
    @discardableResult
    func discardAllChanges(at repo: Repo) async throws -> GitResult {
        let result = try await service.discardChanges(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func discardChange(for file: ChangedFile, at repo: Repo) async throws -> GitResult {
        let result = try await service.discardChange(for: file, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func commitChanges(message: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.commit(message: message, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func fetch(at repo: Repo) async throws -> GitResult {
        let result = try await service.fetch(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func pull(at repo: Repo) async throws -> GitResult {
        let result = try await service.pull(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func pull(name: String, rebase: Bool = false, at repo: Repo) async throws -> GitResult {
        let result: GitResult
            if rebase {
                result = try await service.pull(branch: name, rebase: true, at: repo.path)
            } else {
                result = try await service.pull(branch: name, at: repo.path)
            }
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func push(at repo: Repo) async throws -> GitResult {
        let result: GitResult
        if !currentBranch.isEmpty {
            result = try await service.push(at: repo.path, branch: currentBranch)
        } else {
            result = try await service.push(at: repo.path)
        }
        if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    @discardableResult
    func checkout(branch: String, at repo: Repo) async throws -> GitResult {
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
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    func showStash(at repo: Repo) async throws -> [GitStash] {
        try await service.showStashList(at: repo.path)
    }
    
    func stash(at repo: Repo) async throws -> GitResult {
        try await service.stash(at: repo.path)
    }
    
    func applyStash(at repo: Repo) async throws -> GitResult {
        let result = try await service.applyStash(at: repo.path)
        if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    func popStash(at repo: Repo) async throws -> GitResult {
        let result = try await service.popStash(at: repo.path)
        if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
        await loadRepositoryData(for: repo)
        return result
    }
    
    func dropStash(at repo: Repo) async throws -> GitResult {
        try await service.dropStash(at: repo.path)
    }
    
    @discardableResult
    func revertCommit(_ hash: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.revert(commit: hash, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickCommit(_ hash: String, at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPick(commit: hash, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickContinue(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickContinue(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickAbort(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickAbort(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func cherryPickSkip(at repo: Repo) async throws -> GitResult {
        let result = try await service.cherryPickSkip(at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func deleteBranch(branch: String, force: Bool = false, isRemote: Bool = false, at repo: Repo) async throws -> GitResult {
        let result = try await service.deleteBranch(branch: branch, force: force, isRemote: isRemote, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
        }
            await loadRepositoryData(for: repo)
            return result
    }
    
    @discardableResult
    func renameBranch(oldName: String, newName: String, isRemote: Bool = false, at repo: Repo) async throws -> GitResult {
        let result = try await service.renameBranch(oldName: oldName, newName: newName, isRemote: isRemote, at: repo.path)
            if !result.isSuccess {
            throw GitError.executionFailed(extractErrorMessage(from: result))
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
}
