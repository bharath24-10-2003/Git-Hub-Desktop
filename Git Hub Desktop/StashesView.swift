//
//  StashesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 15/06/26.
//

import SwiftUI

struct StashesView: View {
    
    let repo: Repo
    let viewModel: ViewModel
    @State var error: String? = nil
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                HStack {
                    TitleView(title: "Stash", desc: "All Stashes in the repository is shown here. Apply, discard or restore the stash to the current branch.")
                }
                
                if let error {
                    ErrorBannerView(message: error ) {
                        self.error = nil
                    }
                    .padding(.horizontal)
                }
                if !viewModel.stashes.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.stashes) { stash in
                                SingleStashView(stash: stash, applyStash: {
                                    Task {
                                        do {
                                            let result = try await viewModel.applyStash(at: repo)
                                            if !result.isSuccess {
                                                self.error = result.error
                                            }
                                        } catch {
                                            self.error = error.localizedDescription
                                        }
                                    }
                                }, popStash: {
                                    Task {
                                        do {
                                            let result = try await viewModel.popStash(at: repo)
                                            if !result.isSuccess {
                                                self.error = result.error
                                            }
                                        } catch {
                                            self.error = error.localizedDescription
                                        }
                                    }
                                }, deleteStash: {
                                    Task {
                                        do {
                                            let result = try await viewModel.dropStash(at: repo)
                                            if !result.isSuccess {
                                                self.error = result.error
                                            }
                                        } catch {
                                            self.error = error.localizedDescription
                                        }
                                    }
                                })
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    path.append(stash)
                                }
                                .padding(-10)
                            }
                            .padding()
                        }
                    }
                    .padding(.bottom, 14)
                } else {
                    NoStashView()
                }
            }
            .navigationDestination(for: GitStash.self) { stash in
                CommitDiffDetailView(
                    hash: stash.id,
                    title: stash.message,
                    repo: repo,
                    viewModel: viewModel
                )
            }
        }
    }
}

struct SingleStashView: View {

    let stash: GitStash

    @State private var stashError: String?
    @State var applyStash: () -> Void
    @State var popStash: () -> Void
    @State var deleteStash: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {

                Text(stashIndex)
                    .frame(width: 44, height: 44)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .background(Circle().opacity(0.15))

                VStack(alignment: .leading, spacing: 4) {

                    Text(stash.message)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {

                        Text(stash.branch)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(stash.type)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(stash.type == "WIP on" ? .orange : .blue)
                    }
                }

                Spacer()

                HStack(spacing: 8) {

                    Button {
                        stashError = nil
                        applyStash()
                    } label: {
                        Text("Apply")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glassProminent)

                    Button {
                        stashError = nil
                        popStash()
                    } label: {
                        Text("Pop")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glass)
                    
                    Button {
                        stashError = nil
                        deleteStash()
                    } label: {
                        Text("Delete")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glass)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if let stashError {
                ErrorBannerView(message: stashError) {
                    self.stashError = nil
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray, lineWidth: 1)
                .opacity(0.2)
        }
    }

    private var stashIndex: String {
        stash.id
            .replacingOccurrences(of: "stash@{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }
}

struct NoStashView : View {
    var body: some View {
    
        VStack {
            Image(systemName: "xmark.bin")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Text("No stashes found in this Repository")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
}

#Preview {
    StashesView(repo: Repo(name: "tvOS-App", path: "/Users/bharath/Documents/Projects/tvOS-App", currentBranch: "develop"), viewModel: ViewModel())
}
