//
//  BodyView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct BodyView: View {
    
    let repo: Repo?
    let section: RepoSection
    let viewModel: ViewModel
    
    var body: some View {
        Group {
            if let repo = repo {
                switch section {
                case .changes:
                    ChangesView(repo: repo, viewModel: viewModel)
                case .history:
                    HistoryView(repo: repo, viewModel: viewModel)
                case .branches:
                    BranchesView(repo: repo, viewModel: viewModel)
                case .stashes:
                    StashesView(repo: repo, viewModel: viewModel)
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

#Preview {
//    BodyView(viewModel: ViewModel())
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
