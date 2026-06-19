//
//  AppCoordinator.swift
//  Git Hub Desktop
//
//  Created by Bharath on 19/06/26.
//

import Foundation
import SwiftUI

enum AppSheet: Identifiable, Equatable {
    case clone
    case addRepo
    case newBranch(Repo)
    case pullBranch(Repo)
    case deleteBranch(Repo)
    case renameBranch(Repo)
    case rebaseAssistant(Repo)
    case mergeAssistant(Repo)
    case stash(Repo)
    case cherryPick(Repo)
    
    var id: String {
        switch self {
        case .clone: return "clone"
        case .addRepo: return "addRepo"
        case .newBranch(let repo): return "newBranch-\(repo.id)"
        case .pullBranch(let repo): return "pullBranch-\(repo.id)"
        case .deleteBranch(let repo): return "deleteBranch-\(repo.id)"
        case .renameBranch(let repo): return "renameBranch-\(repo.id)"
        case .rebaseAssistant(let repo): return "rebaseAssistant-\(repo.id)"
        case .mergeAssistant(let repo): return "mergeAssistant-\(repo.id)"
        case .stash(let repo): return "stash-\(repo.id)"
        case .cherryPick(let repo): return "cherryPick-\(repo.id)"
        }
    }
}

@Observable
final class AppCoordinator {
    var selectedRepo: Repo? = nil
    var selectedSection: RepoSection = .changes
    var activeSheet: AppSheet? = nil
    
    var viewModel: MainViewModel
    
    init(viewModel: MainViewModel = MainViewModel()) {
        self.viewModel = viewModel
        self.selectedRepo = viewModel.selectedRepo
    }
    
    func presentClone() {
        activeSheet = .clone
    }
    
    func presentAddRepo() {
        activeSheet = .addRepo
    }
    
    func presentNewBranch(for repo: Repo) {
        activeSheet = .newBranch(repo)
    }
    
    func presentPullBranch(for repo: Repo) {
        activeSheet = .pullBranch(repo)
    }
    
    func presentDeleteBranch(for repo: Repo) {
        activeSheet = .deleteBranch(repo)
    }
    
    func renameBranch(for repo: Repo) {
        activeSheet = .renameBranch(repo)
    }
    
    func presentRebaseAssistant(for repo: Repo) {
        activeSheet = .rebaseAssistant(repo)
    }
    
    func presentMergeAssistant(for repo: Repo) {
        activeSheet = .mergeAssistant(repo)
    }
    
    func presentStash(for repo: Repo) {
        activeSheet = .stash(repo)
    }
    
    func presentCherryPick(for repo: Repo) {
        activeSheet = .cherryPick(repo)
    }
    
    func dismissSheet() {
        activeSheet = nil
    }
}
