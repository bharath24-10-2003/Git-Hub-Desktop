//
//  TopBar.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import AppKit
import SwiftUI

struct TopBar: View {

    let repo: Repo?
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State private var error: String?
    @State private var showForcePushAlert = false
    @State private var pushErrorMessage = ""

    var body: some View {
        if let repo = repo {
            VStack(spacing: 8) {
                HStack (alignment: .center){
                    Text(repo.name)
                        .appFont(size: 18, weight: .semibold)
                    Text("/")
                        .appFont(size: 14, weight: .light)
                        .opacity(0.5)
                    Menu {
                        ForEach(viewModel.recentLocalBranches, id: \.self) { branch in
                            Button {
                                Task {
                                    do {
                                        if try await viewModel.requestBranchSwitch(branch: branch, at: repo) {
                                            coordinator.presentBranchSwitch(branch: branch, for: repo)
                                        }
                                    } catch {
                                        self.error = error.localizedDescription
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(branch)
                                        .appFont(.subheadline)
                                    if branch == (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.trianglehead.branch")
                            Text(viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)
                                .appFont(.subheadline)
                        }
                    }
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(
                            viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch,
                            forType: .string
                        )
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("Copy branch name")
                    .accessibilityLabel("Copy branch name")
                    Spacer()
                    
                    HStack(spacing: 4) {
                        if viewModel.isBackgroundFetching {
                            ProgressView()
                                .controlSize(.small)
                        } else if viewModel.lastFetchError != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .onTapGesture {
                                    viewModel.lastDetailedError = viewModel.lastFetchError
                                    self.error = "Background fetch failed."
                                }
                        }
                        
                        BaseButton(title: "Fetch", image: Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90"),imageSize: CGSize(width: 19, height: 16)) {
                            self.error = nil
                            Task {
                                do {
                                    _ = try await viewModel.fetch(at: repo)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                    }
                    
                    BaseButton(title: "Pull" + (viewModel.behindCommits > 0 ? " ↓\(viewModel.behindCommits)" : ""), image: Image(.pull)) {
                        self.error = nil
                        Task {
                            do {
                                _ = try await viewModel.pull(at: repo)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    .disabled(!viewModel.hasUpstream)
                    ProminentBaseButton(title: (!viewModel.hasUpstream ? "Publish branch" : "Push") + (viewModel.unPushedCommits != 0 ? " (\(viewModel.unPushedCommits))" : ""), image: Image(.push), keyboardShortcut: nil) {
                        self.error = nil
                        Task {
                            do {
                                _ = try await viewModel.push(at: repo)
                            } catch {
                                self.pushErrorMessage = error.localizedDescription
                                self.showForcePushAlert = true
                            }
                        }
                    }
                }
                
                if let error {
                    ErrorBannerView(message: error, detailedError: viewModel.lastDetailedError) {
                        self.error = nil
                    }
                }
            }
            .alert(
                "Push Failed",
                isPresented: $showForcePushAlert
            ) {
                Button("Force Push", role: .destructive) {
                    self.error = nil
                    Task {
                        do {
                            _ = try await viewModel.forcePush(at: repo)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    self.error = pushErrorMessage
                }
            } message: {
                Text("\(pushErrorMessage)\n\nWould you like to force push to overwrite the remote branch?")
            }
        } else {
            HStack (alignment: .center){
                Text("Clone or Choose a repository")
                    .appFont(size: 18, weight: .semibold)
                Spacer()
                BaseButton(title: "Clone a Repo") {
                    coordinator.presentClone()
                }
                BaseButton(title: "Add Local Repo") {
                    coordinator.presentAddRepo()
                }
            }
        }
    }
}
