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
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "History", desc: "All commits in \(viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch) branch")
                BaseButton(title: "Refresh") {
                    Task {
                        await viewModel.loadRepositoryData(for: repo)
                    }
                }
                .padding(.trailing, 24)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                ForEach(viewModel.commits) { commit in
                    HistoryCommitView(commit: commit, repo: repo, viewModel: viewModel)
                }
                .padding()
            }
            .padding(.bottom, 14)
        }
    }
}

struct HistoryCommitView: View {
    
    let commit: Commit
    let repo: Repo
    let viewModel: ViewModel
    
    var body: some View {
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
                Task {
                    try? await viewModel.revertCommit(commit.id, at: repo)
                }
            } label: {
                Text("Revert")
                    .padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buttonStyle(.glass)
            
            Button {
                Task {
                    try? await viewModel.cherryPickCommit(commit.id, at: repo)
                }
            } label: {
                Text("Cherry pick")
                    .padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
