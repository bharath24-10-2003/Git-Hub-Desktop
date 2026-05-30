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
    var selectedRepo: Repo? = nil {
        didSet {
            if let repo = selectedRepo {
                store.markOpened(repo)
                Task {
                    await loadRepositoryData(for: repo)
                }
            }
        }
    }
    
    var currentBranch: String = ""
    var changedFiles: [ChangedFile] = []
    var commits: [Commit] = []
    var localBranches: [String] = []
    var remoteBranches: [String] = []
    
    var isCloning: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    // MARK: - Presentation Flags
    var showCloneModal: Bool = false
    var showAddRepoModal: Bool = false
    var showNewBranchModal: Bool = false
    
    init () {
        self.service = GitService()
        self.store = RepoStore()
        self.selectedRepo = store.sortedRepos.first
    }
    
    func getRepoCollection() -> [Repo] {
        return store.repos
    }
    
    // MARK: - Asynchronous Data Loader
    
    func loadRepositoryData(for repo: Repo) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
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
            
            await MainActor.run {
                self.localBranches = cleanLocal
                self.remoteBranches = cleanRemote
                self.currentBranch = detectedCurrentBranch
                self.changedFiles = files
                self.commits = commitHistory
                
                // Update active branch name in RepoStore so it persists
                if let index = store.repos.firstIndex(where: { $0.id == repo.id }) {
                    store.repos[index].currentBranch = detectedCurrentBranch
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            print("Failed to load repo data:", error)
        }
    }
    
    // MARK: - Asynchronous Git Actions
    
    func cloneRepo(url: String, destinationPath: String) async throws {
        await MainActor.run {
            self.isCloning = true
            self.errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                self.isCloning = false
            }
        }
        
        // Asynchronously clone through GitService
        try await service.clone(url: url, to: destinationPath)
        
        let repoName = extractRepoName(from: url)
        
        await MainActor.run {
            store.addRepo(name: repoName, path: destinationPath)
            self.selectedRepo = store.repos.first(where: { $0.path == destinationPath })
        }
    }
    
    func addExistingRepo(name: String, path: String) {
        if let path = selectFolder() {
            let name = URL(fileURLWithPath: path).lastPathComponent
            store.addRepo(name: name, path: path)
            self.selectedRepo = store.repos.first(where: { $0.path == path })
        }
    }
    
    func stageAll(at repo: Repo) async throws {
        try await service.addAll(at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func stage(file: String, at repo: Repo) async throws {
        try await service.add(file: file, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func unstage(file: String, at repo: Repo) async throws {
        try await service.restoreStaged(file: file, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func stageSelected(files: [String], at repo: Repo) async throws {
        for file in files {
            try await service.add(file: file, at: repo.path)
        }
        await loadRepositoryData(for: repo)
    }
    
    func discardAllChanges(at repo: Repo) async throws {
        try await service.discardChanges(at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func discardChange(for file: ChangedFile, at repo: Repo) async throws {
        try await service.discardChange(for: file, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func commitChanges(message: String, at repo: Repo) async throws {
        try await service.commit(message: message, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func fetch(at repo: Repo) async throws {
        try await service.fetch(at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func pull(at repo: Repo) async throws {
        try await service.pull(at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func push(at repo: Repo) async throws {
        try await service.push(at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func checkout(branch: String, at repo: Repo) async throws {
        try await service.checkout(branch: branch, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func createBranch(name: String, at repo: Repo) async throws {
        try await service.createBranch(branch: name, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func revertCommit(_ hash: String, at repo: Repo) async throws {
        try await service.revert(commit: hash, at: repo.path)
        await loadRepositoryData(for: repo)
    }
    
    func cherryPickCommit(_ hash: String, at repo: Repo) async throws {
        try await service.cherryPick(commit: hash, at: repo.path)
        await loadRepositoryData(for: repo)
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
