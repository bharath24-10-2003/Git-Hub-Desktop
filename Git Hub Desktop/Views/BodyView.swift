//
//  BodyView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct BodyView: View {
    
    let repo: Repo?
    @Binding var section: RepoSection
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    var body: some View {
        Group {
            if let repo = repo {
                switch section {
                case .changes:
                    ChangesView(repo: repo, viewModel: viewModel, coordinator: coordinator)
                case .history:
                    HistoryView(repo: repo, viewModel: viewModel, coordinator: coordinator)
                case .branches:
                    BranchesView(repo: repo, viewModel: viewModel, selectedSection: $section, coordinator: coordinator)
                case .stashes:
                    StashesView(repo: repo, viewModel: viewModel, coordinator: coordinator)
                case .releases:
                    GitHubReleasesView(repo: repo)
                case .pullRequests:
                    GitHubPullRequestsView(repo: repo)
                case .actions, .repositories:
                    GitHubSectionPlaceholder(section: section)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.questionmark")
                        .appFont(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select or Add a Repository")
                        .appFont(.title2)
                        .bold()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct GitHubSectionPlaceholder: View {
    let section: RepoSection

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: section.icon)
                .appFont(.largeTitle)
                .foregroundStyle(.secondary)
            Text(section.title)
                .appFont(.title2)
                .fontWeight(.semibold)
            Text("GitHub CLI integration is coming soon.")
                .appFont(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
