//
//  CustomModal.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct CloneModal: View {
    
    let viewModel: ViewModel
    
    @State private var url: String = ""
    @State private var path: String = ""
    @State private var error: String?
    
    var body: some View {
        VStack (alignment:.leading) {
            ModalDescription(title: "Clone Repository", description: "Enter the URL of the GitHub remote repository and the local path where you want to clone the repository.")
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
            
            Text("Git Repository URL")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            
            CustomTextField(url: $url, imageName: "link", placeholder: "https://github.com/user/repo.git")
                .padding(.bottom, 20)

            Text("Choose local destination path")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            HStack (alignment:.center) {
                
                CustomTextField(url: $path, imageName: "folder", placeholder: "/path/to/folder")
                BaseButton(title: "Browse") {
                    if let folder = viewModel.selectFolder() {
                        path = folder
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            if viewModel.isCloning {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Cloning repository...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 10)
            } else {
                HStack (alignment:.center) {
                    Spacer()
                    BaseButton(title: "Close") {
                        viewModel.showCloneModal = false
                    }
                    ProminentBaseButton(title: "Clone Repository") {
                        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        self.error = nil
                        Task {
                            let result = await viewModel.cloneRepo(url: url, destinationPath: path)
                            if result?.isSuccess == true {
                                viewModel.showCloneModal = false
                            } else {
                                self.error = viewModel.errorMessage
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .frame(width: 500)
        .padding()
    }
}

struct AddRepoModal: View {
    
    let viewModel: ViewModel
    
    @State private var path: String = ""
    
    var body: some View {
        VStack (alignment:.leading) {
            ModalDescription(title: "Add Local Repository", description: "Enter the local path of your repository to add it in GitHub.")
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)

            Text("Choose a path")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            HStack (alignment:.center) {
                
                CustomTextField(url: $path, imageName: "folder", placeholder: "/path/to/repo")
                BaseButton(title: "Browse") {
                    if let folder = viewModel.selectFolder() {
                        path = folder
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            HStack (alignment:.center) {
                Spacer()
                BaseButton(title: "Close") {
                    viewModel.showAddRepoModal = false
                }
                ProminentBaseButton(title: "Add Repository") {
                    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    viewModel.addExistingRepo(name: "", path: path)
                    viewModel.showAddRepoModal = false
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
    }
}

struct CustomTextField: View {
    
    @Binding var url: String
    @State var imageName: String = ""
    @State var placeholder: String = ""
    
    var body: some View {
        TextField(placeholder, text: $url)
            .padding(12)
            .padding(.leading, 30)
            .background(
                background
            )
            .textFieldStyle(.plain)
            .font(Font.system(size: 14,weight: .regular,design: .default))
    }
    
    var background: some View {
        ZStack(alignment: .leading) {
            
            Image(systemName: imageName)
                .padding(.leading, 15)
                .opacity(0.7)
            
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
    }
}

struct BaseButton: View {
    
    var title: String
    var image: Image? = nil
    var textTint: Color = .white
    var imageSize: CGSize = CGSize(width: 16, height: 16)
    var action: (() -> Void)
    
    var body: some View {
        Button {
             action()
        } label: {
            if let image = image {
                image
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .padding(.trailing, -8)
                    .padding(.leading, 16)
                    .tint(.white)
                    .font(Font.system(size: 14, weight: .bold, design: .default))
            }
            Text(title)
                .font(Font.system(size: 14, weight: .medium, design: .none))
                .padding(.horizontal,16)
                .padding(.vertical,8)
                .tint(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(height: 42)
        }
        .buttonStyle(.glass)
        .tint(.white)
    }
}
struct ProminentBaseButton: View{
    
    var title: String
    var image: Image? = nil
    var textTint: Color = .black
    var action: (() -> Void)
    
    var body: some View {
        Button {
            action()
        } label: {
            if let image = image {
                image
                    .resizable()
                    .frame(width: 16,height: 16)
                    .padding(.trailing, -8)
                    .padding(.leading, 16)
                    .tint(.white)
                    .font(Font.system(size: 14, weight: .bold, design: .default))
            }
            Text(title)
                .font(Font.system(size: 14, weight: .medium, design: .none))
                .padding(.horizontal,16)
                .padding(.vertical,8)
                .tint(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(height: 42)
        }
        .buttonStyle(.borderedProminent)
    }
}

struct ModalDescription: View {
    
    @State var title: String
    @State var description: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(Font.system(size: 24, weight: .semibold, design: .default))
                .padding(.bottom, 4)
            Text(description)
                .font(Font.system(size: 14,weight: .regular,design: .default))
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.7)
        }
        .padding(.vertical,4)
    }
}

// MARK: - Reusable Error Banner

struct ErrorBannerView: View {
    
    let message: String
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.red)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer()
            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(0.6))
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.red.opacity(0.1))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct NewBranchModal: View {
    
    let repo: Repo
    let viewModel: ViewModel
    
    @State private var branchName: String = ""
    @State private var error: String?
    
    var body: some View {
        let sourceBranch = viewModel.selectedBranchForAction ?? (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)
        VStack (alignment:.leading) {
            ModalDescription(
                title: "Create New Branch",
                description: "Enter a name for your new branch. This will branch off from '\(sourceBranch)'."
            )
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
            
            Text("Branch Name")
                .font(Font.system(size: 14, weight: .semibold))
            
            CustomTextField(url: $branchName, imageName: "arrow.trianglehead.branch", placeholder: "feature/new-design")
                .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            HStack {
                Spacer()
                BaseButton(title: "Cancel") {
                    viewModel.showNewBranchModal = false
                }
                ProminentBaseButton(title: "Create Branch") {
                    guard !branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        let result = await viewModel.createBranch(name: branchName, from: sourceBranch, at: repo)
                        if result?.isSuccess == true {
                            viewModel.showNewBranchModal = false
                        } else {
                            self.error = viewModel.errorMessage
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
        .onDisappear {
            viewModel.selectedBranchForAction = nil
        }
    }
}

struct PullBranchModal: View {
    
    let repo: Repo
    let viewModel: ViewModel
    
    @State private var error: String?
    
    var body: some View {
        let sourceBranch = viewModel.selectedBranchForAction ?? (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)
        VStack (alignment:.leading) {
            ModalDescription(
                title: "Merge into current branch",
                description: "Are you sure want to pull from '\(sourceBranch)' into the current branch '\(viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)'?"
            )
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)

            HStack {
                Spacer()
                BaseButton(title: "Cancel") {
                    viewModel.showMergeModal = false
                }
                
                BaseButton(title: "Rebase") {
                    self.error = nil
                    Task {
                        let result = await viewModel.pull(name: sourceBranch, rebase: true, at: repo)
                        if result?.isSuccess == true {
                            viewModel.showMergeModal = false
                        } else {
                            self.error = viewModel.errorMessage
                        }
                    }
                }
                
                ProminentBaseButton(title: "Merge") {
                    self.error = nil
                    Task {
                        let result = await viewModel.pull(name: sourceBranch, at: repo)
                        if result?.isSuccess == true {
                            viewModel.showMergeModal = false
                        } else {
                            self.error = viewModel.errorMessage
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
        .onDisappear {
            viewModel.selectedBranchForAction = nil
        }
    }
}

#Preview {
    PullBranchModal(repo: Repo(name: "Bharath", path: "usr/local", currentBranch: "main"), viewModel: ViewModel())
}

struct DeleteBranchModal: View {
    
    let repo: Repo
    let viewModel: ViewModel
    @State private var isDeleting: Bool = false
    
    @State private var error: String?
    @State private var forceDelete: Bool = false
    
    var body: some View {
        let branchToDelete = viewModel.selectedBranchForAction ?? ""
        VStack (alignment:.leading) {
            ModalDescription(
                title: "Delete Branch",
                description: "Are you sure you want to delete the branch '\(branchToDelete)'? This action cannot be undone."
            )
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
                
            Toggle("Force delete (unmerged changes will be lost)", isOn: $forceDelete)
                .toggleStyle(.checkbox)
                .font(Font.system(size: 14))
                .padding(.bottom, 20)

            HStack {
                Spacer()
                if isDeleting {
                    ProgressView()
                }
                BaseButton(title: "Cancel") {
                    viewModel.showDeleteBranchModal = false
                }
                
                ProminentBaseButton(title: "Delete", textTint: .white) {
                    self.error = nil
                    Task {
                        isDeleting = true
                        let result = await viewModel.deleteBranch(branch: branchToDelete, force: forceDelete, isRemote: viewModel.isRemoteBranchAction, at: repo)
                        isDeleting = false
                        if result?.isSuccess == true {
                            viewModel.showDeleteBranchModal = false
                        } else {
                            self.error = viewModel.errorMessage
                        }
                    }
                }
                .disabled(isDeleting)
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
        .onDisappear {
            viewModel.selectedBranchForAction = nil
        }
    }
}

struct RenameBranchModal: View {
    
    let repo: Repo
    let viewModel: ViewModel
    
    @State private var newBranchName: String = ""
    @State private var error: String?
    
    var body: some View {
        let oldName = viewModel.selectedBranchForAction ?? ""
        VStack(alignment: .leading, spacing: 10) {
            ModalDescription(
                title: "Rename Branch",
                description: "Enter a new name for the branch '\(oldName)'."
            )
            
            if let error {
                ErrorBannerView(message: error) {
                    self.error = nil
                }
            }
            
            TextField("New branch name", text: $newBranchName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.top, 5)
            
            HStack {
                Spacer()
                
                BaseButton(title: "Cancel") {
                    viewModel.showRenameBranchModal = false
                }
                
                ProminentBaseButton(title: "Rename", textTint: .white) {
                    guard !newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        let result = await viewModel.renameBranch(oldName: oldName, newName: newBranchName, isRemote: viewModel.isRemoteBranchAction, at: repo)
                        if result?.isSuccess == true {
                            viewModel.showRenameBranchModal = false
                        } else {
                            self.error = viewModel.errorMessage
                        }
                    }
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
        .onDisappear {
            viewModel.selectedBranchForAction = nil
        }
    }
}
