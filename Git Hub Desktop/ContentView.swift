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
    @State var isLoading: Bool = false

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationSplitView {

            Sidebar(
                selectedRepo: $viewModel.selectedRepo,
                selectedSection: $selectedSection,
                repos: viewModel.store.repos,
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
                    section: $selectedSection,
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
        .sheet(isPresented: $viewModel.showDeleteBranchModal) {
            if let repo = viewModel.selectedRepo {
                DeleteBranchModal(repo: repo, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showRenameBranchModal) {
            if let repo = viewModel.selectedRepo {
                RenameBranchModal(repo: repo, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showRebaseModal) {
            if let repo = viewModel.selectedRepo {
                RebaseAssistantModal(repo: repo, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showMergeAssistantModal) {
            if let repo = viewModel.selectedRepo {
                MergeAssistantModal(repo: repo, viewModel: viewModel)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    Color(.gray).opacity(0.3)
                    AQILoaderView()
                }
            }
        }
        .dialogIcon(Image(.branch))
        .onChange(of: viewModel.selectedRepo) {
            viewModel.historyBranch = nil
            selectedSection = .changes
        }
        .task {
            if let repo = viewModel.selectedRepo {
                await viewModel.loadRepositoryData(for: repo)
            }
        }
    }
}

