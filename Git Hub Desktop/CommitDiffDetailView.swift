//
//  CommitDiffDetailView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 17/06/26.
//

import SwiftUI

struct CommitDiffDetailView: View {
    let hash: String
    let title: String
    let repo: Repo
    let viewModel: ViewModel
    var onBack: (() -> Void)? = nil
    
    @State private var changedFiles: [ChangedFile] = []
    @State private var selectedFileForDiff: ChangedFile? = nil
    @State private var currentDiff: FileDiff? = nil
    @State private var isLoading: Bool = true
    @State private var error: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if let onBack = onBack {
                // Header with Back Button
                HStack(spacing: 16) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .clipShape(Circle())
                    .buttonStyle(.glass)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title3)
                            .bold()
                        Text("Hash: \(hash)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                
                Divider()
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                VStack {
                    ErrorBannerView(message: error) {
                        self.error = nil
                    }
                    Spacer()
                }
                .padding()
            } else {
                HSplitView {
                    // Left Pane: File List
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(changedFiles) { file in
                                CommitFileRowView(
                                    file: file,
                                    isSelected: selectedFileForDiff?.id == file.id
                                )
                                .onTapGesture {
                                    loadDiff(for: file)
                                }
                                
                                if file.path != changedFiles.last?.path {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 400)
                    
                    // Right Pane: Diff
                    if selectedFileForDiff != nil {
                        VStack {
                            if let selectedFile = selectedFileForDiff {
                                if let diff = currentDiff {
                                    DiffRendererView(diff: diff, file: selectedFile)
                                        .padding()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                } else {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            } else {
                                NoStashView()
                            }
                        }
                        .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.controlBackgroundColor))
                        .transition(.move(edge: .trailing))
                    }
                }
                .id(selectedFileForDiff == nil)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle(title)
        .navigationSubtitle("Hash: \(hash)")
        .task {
            await loadFiles()
        }
    }
    
    private func loadFiles() async {
        isLoading = true
        error = nil
        do {
            changedFiles = try await viewModel.getCommitFiles(hash: hash, at: repo)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    private func loadDiff(for file: ChangedFile) {
        selectedFileForDiff = file
        currentDiff = nil
        
        Task {
            do {
                let diff = try await viewModel.loadCommitDiff(hash: hash, file: file.path, at: repo)
                if selectedFileForDiff?.id == file.id {
                    currentDiff = diff
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct CommitFileRowView: View {
    let file: ChangedFile
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(statusColor)
            Text(file.path.split(separator: "/").last ?? "")
                .lineLimit(1)
                .truncationMode(.middle)
            Text(file.status)
                .font(.caption2)
                .bold()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var statusColor: Color {
        switch file.status {
        case "Added", "A": return .green
        case "Modified", "M": return .blue
        case "Deleted", "D": return .red
        case "Renamed", "R": return .purple
        default: return .gray
        }
    }
}
