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

    var body: some View {
        
        if viewModel.changedFiles.isEmpty {
            NoChangesView()
        } else {
            VStack {
                commitSection
                modifiedSection
            }
        }
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
                    Task {
                        try? await viewModel.commitChanges(message: commitMessage, at: repo)
                        commitMessage = ""
                        selectedFiles.removeAll()
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
                    SmallButton(title: "Stage All") {
                        Task {
                            try? await viewModel.stageAll(at: repo)
                        }
                    }
                    SmallButton(title: "Stage Selected ") {
                        Task {
                            try? await viewModel.stageSelected(files: Array(selectedFiles), at: repo)
                            selectedFiles.removeAll()
                        }
                    }
                    SmallButton(title: "Discard All", tint: .red) {
                        Task {
                            try? await viewModel.discardAllChanges(at: repo)
                            selectedFiles.removeAll()
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
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        try? await viewModel.discardChange(for: file, at: repo)
                                    }
                                } label: {
                                    Label("Discard Changes", systemImage: "trash")
                                }
                                
                                if file.isStaged {
                                    Button {
                                        Task {
                                            try? await viewModel.unstage(file: file.path, at: repo)
                                        }
                                    } label: {
                                        Label("Unstage File", systemImage: "minus.square")
                                    }
                                } else {
                                    Button {
                                        Task {
                                            try? await viewModel.stage(file: file.path, at: repo)
                                        }
                                    } label: {
                                        Label("Stage File", systemImage: "plus.square")
                                    }
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
            Image(systemName: "nosign")
                .frame(width: 150, height: 150)
                .font(Font.system(size: 100, weight: .bold))
                .foregroundColor(.secondary)
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
//    let repo = Repo.init(name: "tvOS-Beacon", path: "test", currentBranch: "main")
//    ChangesView(repo: repo)
//        .frame(width: 1000)
//        .overlay {
//            RoundedRectangle(cornerRadius: 20)
//                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
//        }
//        .padding()
}
