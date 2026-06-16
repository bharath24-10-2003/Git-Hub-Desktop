//
//  ChangesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct ChangesView: View {

    let repo: Repo
    let viewModel: ViewModel

    @State private var commitMessage: String = ""
    @State private var selectedFiles = Set<String>()
    @State private var error: String?
    @State private var stashMessage: String?
    @State private var isStashPresented: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            if viewModel.isCherryPicking {
                if let error {
                    ErrorBannerView(message: error) {
                        self.error = nil
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                cherryPickSection
                    .padding(.top, error == nil ? 16 : 0)
            }
            
            if viewModel.changedFiles.isEmpty {
                NoChangesView()
            } else {
                VStack {
                    commitSection
                    if !viewModel.isCherryPicking, let error {
                        ErrorBannerView(message: error) {
                            self.error = nil
                        }
                        .padding(.horizontal)
                    }
                    modifiedSection
                }
            }
        }
        .sheet(isPresented: $isStashPresented) {
            stashModal(viewModel: viewModel, repo: repo, onDismiss: {
                isStashPresented = false
            })
        }
    }
    
    var cherryPickSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Cherry Pick in Progress")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Resolve conflicts and stage files to continue, or abort/skip.")
                    .font(.caption)
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
    
    var commitSection: some View {
        HStack {
            TitleView(title: "Uncommitted Changes", desc: "You have \(viewModel.changedFiles.count) modified files in your working directory.")
            HStack {
                TextField("Enter commit message", text: $commitMessage)
                    .textFieldStyle(.plain)
                    .font(Font.system(size: 14, weight: .regular))
                    .padding(.leading)
                SmallProminentButton(title: "Commit") {
                    guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        do {
                            _ = try await viewModel.commitChanges(message: commitMessage, at: repo)
                            commitMessage = ""
                            selectedFiles.removeAll()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(8)
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
                        .font(.headline)
                    Spacer()
                    SmallButton(title: "Stash") {
                        isStashPresented = true
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
                }
                .padding()
                
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.changedFiles) { file in
                            let isSelected = selectedFiles.contains(file.path)
                            
                            HStack(spacing: 12) {
                                
                                Image(systemName: "doc.text")
                                    .foregroundStyle(statusColor(for: file.status))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.path)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(file.status + (file.isStaged ? " (Staged)" : " (Unstaged)"))
                                        .font(.caption)
                                        .foregroundStyle(statusColor(for: file.status).opacity(0.8))
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
                                    .font(Font.system(size: 16))
                            }
                            .padding()
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                if isSelected {
                                    selectedFiles.remove(file.path)
                                } else {
                                    selectedFiles.insert(file.path)
                                }
                            }
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 10)
                                        .opacity(0.1)
                                }
                            }
                            
                            if file.path != viewModel.changedFiles.last?.path {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .padding(.horizontal)
        .padding(.bottom)
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
    var body: some View {
    
        VStack {
            Text("No changes done yet for commit")
                .font(Font.system(size: 50, weight: .bold))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke()
                .opacity(0.2)
        }
        
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
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .font(Font.system(size: 14, weight: .regular))
        }
        .buttonStyle(.borderedProminent)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct SmallButton : View {
    
    let title: String
    var tint: Color = .black
    let action: () -> Void

    
    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .font(Font.system(size: 14, weight: .regular))
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
                .font(Font.system(size: 24, weight: .semibold))
                .padding(.bottom,4)
            Text(desc)
                .font(Font.system(size: 14, weight: .regular))
                .opacity(0.7)
        }
        .padding(.vertical, 24)
        .padding(.leading, 24)
        Spacer()
    }
}
#Preview {
    let repo = Repo.init(name: "tvOS-Beacon", path: "test", currentBranch: "main")
    ChangesView(repo: repo, viewModel: ViewModel())
        .frame(width: 500)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .padding()
}
