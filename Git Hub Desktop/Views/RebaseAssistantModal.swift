//
//  RebaseAssistantModal.swift
//  Git Hub Desktop
//
//  Created by Bharath on 18/06/26.
//

import SwiftUI

struct RebaseAssistantModal: View {
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State private var selectedFile: ChangedFile? = nil
    @State private var editedMessage: String = ""
    @State private var error: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Banner: Rebase in Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.trianglehead.branch")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Rebase in Progress")
                            .font(.title2)
                            .bold()
                    }
                    Spacer()
                    Button(action: {
                        coordinator.dismissSheet()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text("Rebasing branch '\(viewModel.rebaseState.headName)' onto '\(viewModel.rebaseState.ontoBranch.isEmpty ? repo.currentBranch : viewModel.rebaseState.ontoBranch)'")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.08))
            
            Divider()
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
                .padding()
            }
            
            // Progress Visualizer Card
            rebaseProgressCard
                .padding()
            
            // HSplitView for Conflict Resolution
            HSplitView {
                // Left: Conflicted Files List
                VStack(alignment: .leading, spacing: 0) {
                    Text("Conflicted Files")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    Divider()
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if viewModel.changedFiles.isEmpty {
                                VStack(spacing: 10) {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.green)
                                    Text("No conflicted files found")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .frame(minHeight: 180)
                            } else {
                                ForEach(viewModel.changedFiles) { file in
                                    conflictedFileRow(for: file)
                                        .onTapGesture {
                                            selectedFile = file
                                            Task {
                                                try? await viewModel.loadDiff(for: file, at: repo)
                                            }
                                        }
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 250, idealWidth: 300)
                
                // Right: Diff & Conflict Editor
                VStack(spacing: 0) {
                    if let file = viewModel.selectedFileForDiff {
                        selectedFileDetailPane(for: file)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("Select a file to resolve conflicts")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 350, idealWidth: 450)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .id(viewModel.selectedFileForDiff == nil)
            .animation(.snappy(duration: 0.38, extraBounce: 0.05), value: viewModel.selectedFileForDiff)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Commit Message Customizer Section
            if allConflictsStaged {
                commitMessageSection
                    .padding()
                Divider()
            }
            
            // Footer Toolbar Actions
            footerToolbar
                .padding()
        }
        .frame(width: 1000, height: 700)
        .onAppear {
            editedMessage = viewModel.rebaseState.currentCommitMessage
            selectedFile = nil
            viewModel.selectedFileForDiff = nil
            viewModel.currentDiff = nil
        }
        .onChange(of: viewModel.rebaseState.currentCommitMessage) { _, newValue in
            editedMessage = newValue
        }
    }
    
    private var allConflictsStaged: Bool {
        return !viewModel.changedFiles.isEmpty && viewModel.changedFiles.allSatisfy { $0.isStaged }
    }
    
    private var rebaseProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Replaying Commit:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !viewModel.rebaseState.currentCommitHash.isEmpty {
                    Text(viewModel.rebaseState.currentCommitHash.prefix(7))
                        .font(.system(.caption, design: .monospaced))
                        .bold()
                }
                Spacer()
                Text("Step \(viewModel.rebaseState.currentProgress) of \(viewModel.rebaseState.totalProgress)")
                    .font(.caption)
                    .bold()
            }
            
            // Progress Bar
            ProgressView(value: Double(viewModel.rebaseState.currentProgress), total: Double(max(1, viewModel.rebaseState.totalProgress)))
                .progressViewStyle(.linear)
                .tint(.orange)
            
            HStack {
                Image(systemName: "quote.opening")
                    .foregroundStyle(.secondary)
                Text(viewModel.rebaseState.currentCommitMessage)
                    .font(.subheadline)
                    .lineLimit(1)
                    .italic()
                Spacer()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func conflictedFileRow(for file: ChangedFile) -> some View {
        let isResolved = viewModel.isConflictResolved(file: file.path, at: repo)
        let isSelected = selectedFile?.id == file.id
        
        return HStack {
            Image(systemName: "doc.text")
                .foregroundStyle(isResolved ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                    .font(.system(size: 13, weight: .semibold))
                Text(file.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            
            // Status Pill
            if file.isStaged {
                Text("Staged")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            } else if isResolved {
                Text("Resolved")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            } else {
                Text("Unresolved")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private func selectedFileDetailPane(for file: ChangedFile) -> some View {
        let isResolved = viewModel.isConflictResolved(file: file.path, at: repo)
        
        return VStack(spacing: 0) {
            // Panel Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.path.split(separator: "/").last.map(String.init) ?? file.path)
                        .font(.headline)
                    Text(file.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Stage button inside header if resolved and not staged
                if isResolved && !file.isStaged {
                    SmallButton(title: "Stage File", tint: .blue) {
                        Task {
                            do {
                                _ = try await viewModel.stage(file: file.path, at: repo)
                                selectedFile = viewModel.changedFiles.first(where: { $0.id == file.id })
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                }
                
                Button("Open in Editor") {
                    let fileURL = URL(fileURLWithPath: repo.path).appendingPathComponent(file.path)
                    NSWorkspace.shared.open(fileURL)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Diff Content
            ZStack {
                if let diff = viewModel.currentDiff {
                    DiffRendererView(diff: diff, file: file)
                        .opacity(viewModel.isDiffLoading ? 0.45 : 1.0)
                        .blur(radius: viewModel.isDiffLoading ? 0.8 : 0)
                        .id(file.id + "_" + (file.isStaged ? "staged" : "unstaged"))
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
    
    private var commitMessageSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Commit Message Customizer")
                .font(.headline)
                .foregroundStyle(.green)
            Text("All conflicted files have been resolved and staged. Customize the commit message before continuing if needed:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField("Commit Message", text: $editedMessage)
                .textFieldStyle(.plain)
                .font(Font.system(size: 13, weight: .regular))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .onChange(of: editedMessage) { _, newValue in
                    viewModel.setRebaseMessage(newValue, at: repo)
                }
        }
        .padding(10)
        .background(Color.green.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var footerToolbar: some View {
        HStack {
            // Destructive: Abort Rebase
            Button("Abort Rebase") {
                Task {
                    await viewModel.abortRebase(at: repo)
                }
            }
            .buttonStyle(.bordered)
            .tint(.red)
            
            Spacer()
            
            // Secondary: Skip Commit
            Button("Skip Commit") {
                Task {
                    await viewModel.skipRebase(at: repo)
                }
            }
            .buttonStyle(.bordered)
            
            // Primary: Continue Rebase
            Button("Continue Rebase") {
                Task {
                    await viewModel.continueRebase(at: repo)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!allConflictsStaged) // Disable Continue until all files resolved and staged
        }
    }
}
