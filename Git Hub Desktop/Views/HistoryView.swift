//
//  HistoryView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct HistoryView: View {
    
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State var changesViewPresented: Bool = false
    @State var SelectedCommit: Commit?
    @State var height: CGFloat = 0
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "History", desc: "All commits in \(viewModel.historyBranch ?? (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)) branch")
                BaseButton(title: "Cherry pick") {
                    coordinator.presentCherryPick(for: repo)
                }
                BaseButton(title: "Refresh") {
                    Task {
                        await viewModel.loadRepositoryData(for: repo)
                    }
                }
                .padding(.trailing, 24)
            }
            .onChange(of: changesViewPresented) { oldValue, newValue in
                if !newValue {
                    SelectedCommit = nil
                }
            }
            ZStack {
                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.commits) { commit in
                                HistoryCommitView(commit: commit, repo: repo, viewModel: viewModel)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        SelectedCommit = commit
                                        changesViewPresented = true
                                    }
                                    .padding(-10)
                              }
                              .padding()
                        }
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .padding(.bottom, 14)
                    .onAppear {
                        self.height = proxy.size.height
                    }
                }

                if let commit = SelectedCommit {
                    CommitDiffDetailView(
                        hash: commit.id,
                        title: commit.message,
                        repo: repo,
                        viewModel: viewModel,
                        onBack: {
                            changesViewPresented = false
                        }
                    )
                    .frame(height: height)
                }
            }
        }
    }
}

struct HistoryCommitView: View {
    
    let commit: Commit
    let repo: Repo
    let viewModel: MainViewModel
    @State private var revertError: String?
    @State private var resetError: String?
    @State private var showResetModal: Bool = false
    
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commit.timeAgo)
                                .font(Font.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text(commit.displayDate)
                                Text("•")
                                Text(commit.displayTime)
                            }
                            .font(Font.system(size: 10, weight: .regular))
                            .foregroundStyle(.tertiary)
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
                if !commit.isPushed {
                    Image(systemName: "icloud.slash.fill")
                }
                if isCurrentBranch {
                    Button {
                        self.showResetModal = true
                    } label: {
                        Text("Make Head")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glass)
                }
                
                Button {
                    self.revertError = nil
                    Task {
                        do {
                            try await viewModel.revertCommit(commit.id, at: repo)
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
            if let resetError {
                ErrorBannerView(message: resetError) {
                    self.resetError = nil
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
        .sheet(isPresented: $showResetModal) {
            resetModal
        }
    }
    
    private var isCurrentBranch: Bool {
        return (viewModel.historyBranch == nil) || (viewModel.historyBranch == viewModel.currentBranch)
    }
    
    private var resetModal: some View {
        VStack(alignment: .leading, spacing: 20) {
            ModalDescription(title: "Reset Commit", description: "Choose how you want to reset to commit \(commit.shortHash)")
                .padding()
            
            Divider()
            
            HStack {
                BaseButton(title: "Soft Reset") {
                    self.resetError = nil
                    Task {
                        do {
                            try await viewModel.resetCommit(commit.id, hard: false, at: repo)
                            showResetModal = false
                        } catch {
                            self.resetError = error.localizedDescription
                            showResetModal = false
                        }
                    }
                }
                .padding(.trailing, 24)
                
                BaseButton(title: "Hard Reset") {
                    self.resetError = nil
                    Task {
                        do {
                            try await viewModel.resetCommit(commit.id, hard: true, at: repo)
                            showResetModal = false
                        } catch {
                            self.resetError = error.localizedDescription
                            showResetModal = false
                        }
                    }
                }
                .padding(.trailing, 24)
                
                BaseButton(title: "Cancel") {
                    showResetModal = false
                    resetError = nil
                }
            }
            .padding()
        }
    }
    
    private var authorInitial: String {
        let name = commit.author.split(separator: "<")[1].split(separator: "").first ?? ""
        return String(name.prefix(1)).uppercased()
    }
}
