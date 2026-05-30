//
//  ContentView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 25/04/26.
//

import SwiftUI

struct ContentView: View {

    @State private var viewModel = ViewModel()
    @State private var selectedSection: RepoSection = .changes

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationSplitView {

            Sidebar(
                selectedRepo: $viewModel.selectedRepo,
                selectedSection: $selectedSection,
                repos: viewModel.store.sortedRepos
            )

        } detail: {

            VStack(spacing: 0) {

                TopBar(
                    repo: viewModel.selectedRepo,
                    viewModel: viewModel
                )

                Divider()

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
        .onChange(of: viewModel.selectedRepo) {
            selectedSection = .changes
        }
        .colorScheme(.light)
    }
}

#Preview {
    ContentView()
}
