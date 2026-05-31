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
                repos: viewModel.store.sortedRepos
            )

        } detail: {

            VStack(spacing: 0) {

                if let errorMessage = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.red.opacity(0.85))
                    .cornerRadius(8)
                    .padding(.bottom, 15)
                }

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
