//
//  ContentView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 25/04/26.
//

import SwiftUI

struct ContentView: View {

    var viewModel: ViewModel
    @State private var selectedSection: RepoSection = .changes

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationSplitView {

            Sidebar(
                selectedRepo: $viewModel.selectedRepo,
                selectedSection: $selectedSection,
                repos: viewModel.store.sortedRepos,
                viewModel: viewModel
            )

        } detail: {

            VStack(spacing: 0) {

                TopBar(
                    repo: viewModel.selectedRepo,
                    viewModel: viewModel
                )

                Divider()
                    .padding(.vertical)

                BodyView(
                    repo: viewModel.selectedRepo,
                    section: selectedSection,
                    viewModel: viewModel
                )
            }
            .padding()
        }
        .sheet(isPresented: $viewModel.showCloneModal) {
            CloneModal(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showAddRepoModal) {
            AddRepoModal(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showNewBranchModal) {
            if let repo = viewModel.selectedRepo {
                NewBranchModal(repo: repo, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showMergeModal) {
            if let repo = viewModel.selectedRepo {
                PullBranchModal(repo: repo, viewModel: viewModel)
            }
        }
        .dialogIcon(Image(.branch))
        .onChange(of: viewModel.selectedRepo) {
            selectedSection = .changes
        }
        .task {
            if let repo = viewModel.selectedRepo {
                await viewModel.loadRepositoryData(for: repo)
            }
        }
    }
}

#Preview {
    ContentView(viewModel: ViewModel())
}
