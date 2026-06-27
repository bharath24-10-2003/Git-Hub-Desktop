//
//  TopBar.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct TopBar: View {

    let repo: Repo?
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    


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
                        ForEach(viewModel.localBranches, id: \.self) { branch in
                            Button {
                                Task {
                                    do {
                                        try await viewModel.checkout(branch: branch, at: repo)
                                    } catch {
                                        viewModel.handleError(error)
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
                        .background {
                            RoundedRectangle(cornerRadius: 10)
                                .frame(height: 28)
                                .padding(-8)
                                .tint(.gray)
                                .opacity(0.2)
                        }
                        .padding(8)
                    }
                    Spacer()
                    
                    BaseButton(title: "Fetch", image: Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90"),imageSize: CGSize(width: 19, height: 16)) {
                        Task {
                            do {
                                _ = try await viewModel.fetch(at: repo)
                            } catch {
                                viewModel.handleError(error)
                            }
                        }
                    }
                    BaseButton(title: "Pull", image: Image(.pull)) {
                        Task {
                            do {
                                _ = try await viewModel.pull(at: repo)
                            } catch {
                                viewModel.handleError(error)
                            }
                        }
                    }
                    ProminentBaseButton(title: (!viewModel.hasUpstream ? "Publish branch" : "Push") + (viewModel.unPushedCommits != 0 ? " (\(viewModel.unPushedCommits))" : ""), image: Image(.push)) {
                        Task {
                            do {
                                _ = try await viewModel.push(at: repo)
                            } catch {
                                viewModel.handleError(error)
                            }
                        }
                    }
                }
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
