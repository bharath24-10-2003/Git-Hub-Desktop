//
//  HistoryView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct HistoryView: View {
    
    let repo: Repo
    let viewModel: ViewModel
    @State var showCherryPickModal: Bool = false
    @State var cherryPickHash: String = ""
    @State var cherryPickError: String?
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "History", desc: "All commits in \(viewModel.historyBranch ?? (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)) branch")
                BaseButton(title: "Cherry pick") {
                    showCherryPickModal = true
                }
                BaseButton(title: "Refresh") {
                    Task {
                        await viewModel.loadRepositoryData(for: repo)
                    }
                }
                .padding(.trailing, 24)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.commits) { commit in
                        HistoryCommitView(commit: commit, repo: repo, viewModel: viewModel)
                            .padding(-10)
                    }
                    .padding()
                }
            }
            .padding(.bottom, 14)
            .sheet(isPresented: $showCherryPickModal) {
                cherryPickModal
            }
        }
    }
    
    public var cherryPickModal: some View {
        VStack(alignment: .leading ,spacing: 20) {
            ModalDescription(title: "Cherry Pick", description: "Enter the commit hash")
                .padding()
            
            if let cherryPickError {
                ErrorBannerView(message: cherryPickError) {
                    self.cherryPickError = nil
                }
                .padding(.horizontal)
            }
            
            Divider()
            CustomTextField(url: $cherryPickHash,imageName: "number", placeholder: "Enter the commit hash")
                .padding(.horizontal)
            Divider()
            HStack {
                BaseButton(title: "Cherry Pick") {
                    self.cherryPickError = nil
                    Task {
                        do {
                            _ = try await viewModel.cherryPickCommit(cherryPickHash, at: repo)
                            showCherryPickModal = false
                            cherryPickHash = ""
                        } catch {
                            self.cherryPickError = error.localizedDescription
                        }
                    }
                }
                .padding(.trailing, 24)
                BaseButton(title: "Close") {
                    showCherryPickModal = false
                    cherryPickError = nil
                }
            }
            .padding()
        }
    }
}
struct HistoryCommitView: View {
    
    let commit: Commit
    let repo: Repo
    let viewModel: ViewModel
    @State private var revertError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(authorInitial)
                    .frame(width: 44, height: 44)
                    .font(Font.system(size: 18, weight: .bold, design: .rounded))
                    .background(Circle().opacity(0.15))
                VStack(alignment: .leading) {
                    Text(commit.message)
                        .font(Font.system(size: 14,weight: .semibold))
                    HStack {
                        VStack(alignment: .leading) {
                            Text (commit.displayDate)
                                .font(Font.system(size: 11,weight: .regular))
                            Text(commit.displayTime)
                                .font(Font.system(size: 11,weight: .regular))
                        }
                        .padding(.trailing, 24)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(commit.id, forType: .string)
                        } label: {
                            Text (commit.shortHash)
                                .font(.caption)
                                .frame(width: 60)
                        }
                    }
                }
                Spacer()
                Button {
                    self.revertError = nil
                    Task {
                        do {
                            _ = try await viewModel.revertCommit(commit.id, at: repo)
                        } catch {
                            self.revertError = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Revert")
                        .padding(3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            if let revertError {
                ErrorBannerView(message: revertError) {
                    self.revertError = nil
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
    
    private var authorInitial: String {
        let name = commit.author.split(separator: "<")[1].split(separator: "").first ?? ""
        return String(name.prefix(1)).uppercased()
    }
}

#Preview {
//        HistoryView(commits: Commit.previewData)
//    let commit = Commit(id: "123", shortHash: "a56afc69fd5b4a6d3da12d72fa784efd320b7109", author: "Bharath <bharath.a@tringapps.com>", date: "Thu Nov 13 14:15:59 2025 +0530", message: "Initial commit")
//    HistoryCommitView(commit: commit)
//        .padding()
}
