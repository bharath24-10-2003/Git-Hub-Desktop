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
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Select or Add a Repository")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .colorScheme(.light)
    }
}
