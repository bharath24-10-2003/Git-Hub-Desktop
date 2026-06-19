//
//  ContentView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 25/04/26.
//

import SwiftUI

struct ContentView: View {

    @Bindable var coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationSplitView {
            Sidebar(
                selectedRepo: $coordinator.selectedRepo,
                selectedSection: $coordinator.viewModel.activeSection,
                repos: coordinator.viewModel.store.repos,
                viewModel: coordinator.viewModel,
                coordinator: coordinator
            )
        } detail: {
            VStack(spacing: 0) {
                TopBar(
                    repo: coordinator.selectedRepo,
                    viewModel: coordinator.viewModel,
                    coordinator: coordinator
                )

                Divider()
                    .padding(.vertical)

                BodyView(
                    repo: coordinator.selectedRepo,
                    section: $coordinator.viewModel.activeSection,
                    viewModel: coordinator.viewModel,
                    coordinator: coordinator
                )
            }
            .padding()
        }
        .sheet(item: $coordinator.activeSheet) { sheet in
            switch sheet {
            case .clone:
                CloneModal(viewModel: coordinator.viewModel, coordinator: coordinator)
            case .addRepo:
                AddRepoModal(viewModel: coordinator.viewModel, coordinator: coordinator)
            case .newBranch(let repo):
                NewBranchModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .pullBranch(let repo):
                PullBranchModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .deleteBranch(let repo):
                DeleteBranchModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .renameBranch(let repo):
                RenameBranchModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .rebaseAssistant(let repo):
                RebaseAssistantModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .mergeAssistant(let repo):
                MergeAssistantModal(repo: repo, viewModel: coordinator.viewModel, coordinator: coordinator)
            case .stash(let repo):
                stashModal(viewModel: coordinator.viewModel, repo: repo, onDismiss: {
                    coordinator.dismissSheet()
                })
            case .cherryPick(let repo):
                HistoryCherryPickModal(viewModel: coordinator.viewModel, repo: repo, coordinator: coordinator)
            }
        }
        .sheet(isPresented: $coordinator.viewModel.isLoading) {
            LoadingView(loadingMessage: coordinator.viewModel.loadingMessage, isLoading: coordinator.viewModel.isLoading)
        }
        .dialogIcon(Image(.branch))
        .onChange(of: coordinator.selectedRepo) {
            coordinator.viewModel.historyBranch = nil
            coordinator.viewModel.activeSection = .changes
            if let repo = coordinator.selectedRepo {
                Task {
                    await coordinator.viewModel.loadRepositoryData(for: repo)
                    if coordinator.viewModel.rebaseState.inProgress {
                        coordinator.presentRebaseAssistant(for: repo)
                    } else if coordinator.viewModel.mergeState.inProgress {
                        coordinator.presentMergeAssistant(for: repo)
                    }
                }
            }
        }
        .task {
            if let repo = coordinator.selectedRepo {
                await coordinator.viewModel.loadRepositoryData(for: repo)
                if coordinator.viewModel.rebaseState.inProgress {
                    coordinator.presentRebaseAssistant(for: repo)
                } else if coordinator.viewModel.mergeState.inProgress {
                    coordinator.presentMergeAssistant(for: repo)
                }
            }
        }
        .onChange(of: coordinator.viewModel.rebaseState.inProgress) { _, newValue in
            if !newValue, let repo = coordinator.selectedRepo, coordinator.activeSheet == .rebaseAssistant(repo) {
                coordinator.dismissSheet()
            }
        }
        .onChange(of: coordinator.viewModel.mergeState.inProgress) { _, newValue in
            if !newValue, let repo = coordinator.selectedRepo, coordinator.activeSheet == .mergeAssistant(repo) {
                coordinator.dismissSheet()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if let repo = coordinator.selectedRepo {
                    Task {
                        await coordinator.viewModel.loadRepositoryData(for: repo)
                    }
                }
            }
        }
    }
}
