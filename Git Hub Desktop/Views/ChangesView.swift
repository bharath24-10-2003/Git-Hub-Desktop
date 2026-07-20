//
//  ChangesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct ChangesView: View {

    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator

    @State private var commitMessage: String = ""
    @State private var selectedFiles = Set<String>()
    @State private var error: String?
    @State private var stashMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.rebaseState.inProgress {
                rebaseWarningSection
                    .padding(.top, 16)
            }
            if viewModel.mergeState.inProgress {
                mergeWarningSection
                    .padding(.top, 16)
            }
            if viewModel.isCherryPicking {
                if let error {
                    ErrorBannerView(message: error, detailedError: viewModel.lastDetailedError) {
                        self.error = nil
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                cherryPickSection
                    .padding(.top, error == nil ? 16 : 0)
            }
            
            if viewModel.changedFiles.isEmpty {
                NoChangesView(viewModel: viewModel, repo: repo)
            } else {
                VStack {
                    commitSection
                    if !viewModel.isCherryPicking, let error {
                        ErrorBannerView(message: error, detailedError: viewModel.lastDetailedError) {
                            self.error = nil
                        }
                        .padding(.horizontal)
                    }
                    modifiedSection
                }
            }
        }
        .task {
            await viewModel.loadRepositoryData(for: repo)
        }
    }
    
    var cherryPickSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Cherry Pick in Progress")
                    .appFont(.headline)
                    .foregroundStyle(.orange)
                Text("Resolve conflicts and stage files to continue, or abort/skip.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SmallButton(title: "Abort", tint: .red) {
                self.error = nil
                Task {
                    do {
                        _ = try await viewModel.cherryPickAbort(at: repo)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            SmallButton(title: "Skip", tint: .orange) {
                self.error = nil
                Task {
                    do {
                        _ = try await viewModel.cherryPickSkip(at: repo)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            SmallProminentButton(title: "Continue") {
                self.error = nil
                Task {
                    do {
                        _ = try await viewModel.cherryPickContinue(at: repo)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    var rebaseWarningSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Rebase in Progress")
                        .appFont(.headline)
                }
                Text("This repository is currently in a rebasing state. Click the assistant button to resolve conflicts and continue.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SmallProminentButton(title: "Open Rebase Assistant") {
                coordinator.presentRebaseAssistant(for: repo)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    var mergeWarningSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Merge in Progress")
                        .appFont(.headline)
                }
                Text("This repository is currently in a merging state. Click the assistant button to resolve conflicts and continue.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SmallProminentButton(title: "Open Merge Assistant") {
                coordinator.presentMergeAssistant(for: repo)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    var commitSection: some View {
        HStack {
            TitleView(title: "Uncommitted Changes", desc: "You have \(viewModel.changedFiles.count) modified files in your working directory.")
            HStack {
                TextField("Enter commit message", text: $commitMessage)
                    .textFieldStyle(.plain)
                    .appFont(size: 14, weight: .regular)
                    .padding(.leading)
                SmallProminentButton(title: "Commit") {
                    guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        do {
                            try await viewModel.commitChanges(message: commitMessage, at: repo)
                            commitMessage = ""
                            selectedFiles.removeAll()
                        } catch {
                            if error.localizedDescription.contains("Changes not staged for commit") {
                                self.error = "Stage changes to commit."
                            } else {
                                self.error = error.localizedDescription
                            }
                            
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(6)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(lineWidth: 1)
                    .opacity(0.3)
            }
        }
    }
    
    var modifiedSection: some View {
        
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Modified Changes")
                        .appFont(.title2)
                        .padding(.leading, 8)
                    Spacer()
                    SmallButton(title: "Stash") {
                        coordinator.presentStash(for: repo)
                    }
                    SmallButton(title: "Stage All") {
                        self.error = nil
                        Task {
                            do {
                                _ = try await viewModel.stageAll(at: repo)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    SmallButton(title: "Stage Selected ") {
                        self.error = nil
                        Task {
                            do {
                                _ = try await viewModel.stageSelected(files: Array(selectedFiles), at: repo)
                                selectedFiles.removeAll()
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    if viewModel.changedFiles.contains(where: { $0.isStaged }) {
                        SmallButton(title: "Unstage All") {
                            self.error = nil
                            Task {
                                do {
                                    _ = try await viewModel.unstageAll(at: repo)
                                    selectedFiles.removeAll()
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                    }
                    if selectedFiles.contains(where: { path in viewModel.changedFiles.first(where: { $0.path == path })?.isStaged == true }) {
                        SmallButton(title: "Unstage Selected") {
                            self.error = nil
                            Task {
                                do {
                                    _ = try await viewModel.unstageSelected(files: Array(selectedFiles), at: repo)
                                    selectedFiles.removeAll()
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                    }
                    SmallButton(title: "Discard All", tint: .red) {
                        self.error = nil
                        Task {
                            do {
                                _ = try await viewModel.discardAllChanges(at: repo)
                                selectedFiles.removeAll()
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    SmallButton(title: "Refresh") {
                        Task {
                            await viewModel.loadRepositoryData(for: repo)
                        }
                    }
                }
                .padding(10)
                
                Divider()
                HSplitView {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.changedFiles) { file in
                                ChangedFileRowView(
                                    file: file,
                                    repo: repo,
                                    viewModel: viewModel,
                                    isSelected: selectedFiles.contains(file.path),
                                    isViewingDiff: viewModel.selectedFileForDiff?.id == file.id,
                                    error: $error,
                                    toggleSelection: {
                                        if selectedFiles.contains(file.path) {
                                            selectedFiles.remove(file.path)
                                        } else {
                                            selectedFiles.insert(file.path)
                                        }
                                    }
                                )
                                
                                if file.path != viewModel.changedFiles.last?.path {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(minWidth: 350,maxWidth: 500)
                    
                    if viewModel.selectedFileForDiff != nil {
                        // Right: Diff View
                        VStack {
                            if let selectedFile = viewModel.selectedFileForDiff {
                                ZStack {
                                    if let diff = viewModel.currentDiff {
                                        DiffRendererView(diff: diff, file: selectedFile)
                                            .padding()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                            .opacity(viewModel.isDiffLoading ? 0.45 : 1.0)
                                            .blur(radius: viewModel.isDiffLoading ? 0.8 : 0)
                                            .animation(.easeInOut, value: viewModel.isDiffLoading)
                                            .id(selectedFile.id)
                                            .transition(.asymmetric(
                                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)
                                            ))
                                    }
                                    
                                    if viewModel.isDiffLoading {
                                        ProgressView()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .transition(.opacity)
                                    }
                                }
                            }
                        }
                        .frame(minWidth: 500)
                        .background(Color(NSColor.controlBackgroundColor))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Untracked", "Added":
            return .green
        case "Deleted":
            return .red
        case "Renamed":
            return .purple
        default:
            return .orange
        }
    }
}

struct NoChangesView : View {
    let viewModel: MainViewModel
    let repo: Repo
    
    var body: some View {
    
        VStack {
            Image(systemName: "book.pages")
                .appFont(.largeTitle)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Text("No changes done yet for commit")
                .appFont(.headline)
                .foregroundColor(.secondary)
                
            SmallButton(title: "Refresh") {
                Task {
                    await viewModel.loadRepositoryData(for: repo)
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
}
    
struct SmallProminentButton : View {
    
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .appFont(size: 12, weight: .regular)
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct SmallButton : View {
    
    let title: String
    var tint: Color = .primary
    let action: () -> Void

    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .appFont(size: 14, weight: .regular)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .tint(tint)
    }
}

struct TitleView: View {
    
    let title: String
    let desc: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .appFont(size: 24, weight: .semibold)
                .padding(.bottom,4)
            Text(desc)
                .appFont(size: 14, weight: .regular)
                .opacity(0.7)
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        Spacer()
    }
}
#Preview {
    let repo = Repo.init(name: "tvOS-Beacon", path: "test", currentBranch: "main")
    ChangesView(repo: repo, viewModel: MainViewModel(), coordinator: AppCoordinator())
        .frame(width: 500)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .padding()
}

struct ChangedFileRowView: View {
    let file: ChangedFile
    let repo: Repo
    let viewModel: MainViewModel
    let isSelected: Bool
    let isViewingDiff: Bool
    @Binding var error: String?
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Accent Strip
            RoundedRectangle(cornerRadius: 2)
                .fill(file.isStaged ? Color.green : Color.red)
                .frame(width: 4)
                .padding(.vertical, 6)
                .padding(.leading, 6)
            
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .foregroundStyle(statusColor(for: file.status))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                        .appFont(.subheadline)
                        .fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(file.status)
                            .appFont(.caption)
                            .foregroundStyle(statusColor(for: file.status).opacity(0.8))
                        
                        Text(file.isStaged ? "● Staged" : "○ Unstaged")
                            .appFont(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(file.isStaged ? Color.green : Color.red)
                    }
                }
                Spacer()
                
                if file.isStaged {
                    SmallButton(title: "Unstage") {
                        Task {
                            do {
                                _ = try await viewModel.unstage(file: file.path, at: repo)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                } else {
                    SmallButton(title: "Stage", tint: .blue) {
                        Task {
                            do {
                                _ = try await viewModel.stage(file: file.path, at: repo)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                }
                
                SmallButton(title: "Discard", tint: .red) {
                    Task {
                        do {
                            _ = try await viewModel.discardChange(for: file, at: repo)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .appFont(size: 16)
                    .padding(4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleSelection()
                    }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .background(
            isViewingDiff
            ? (file.isStaged ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
            : (file.isStaged ? Color.green.opacity(0.08) : Color.red.opacity(0.06))
        )
        .onTapGesture {
            Task {
                try? await viewModel.loadDiff(for: file, at: repo)
            }
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Untracked", "Added":
            return .green
        case "Deleted":
            return .red
        case "Renamed":
            return .purple
        default:
            return .orange
        }
    }
}

