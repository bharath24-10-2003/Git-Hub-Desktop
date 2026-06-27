//
//  CustomModal.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct CloneModal: View {
    
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
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
                .appFont(.headline)
            
            CustomTextField(url: $url, imageName: "link", placeholder: "https://github.com/user/repo.git")
                .padding(.bottom, 20)

            Text("Choose local destination path")
                .appFont(.headline)
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
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 10)
            } else {
                HStack (alignment:.center) {
                    Spacer()
                    BaseButton(title: "Close") {
                        coordinator.dismissSheet()
                    }
                    ProminentBaseButton(title: "Clone Repository") {
                        guard !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        self.error = nil
                        Task {
                            await viewModel.cloneRepo(url: url, destinationPath: path)
                            coordinator.dismissSheet()
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

struct StashModal: View {
    
    let viewModel: MainViewModel
    let repo: Repo
    
    @State private var error: String?
    @State private var stashMessage: String = ""
    
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            ModalDescription(title: "Stash", description: "Enter Stash message")
                .padding(.leading)
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
            
            CustomTextField(url: $stashMessage,imageName: "archivebox", placeholder: "Enter Stash message")
                .padding()
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
            
            HStack {
                
                Spacer()
                
                if let error {
                    ErrorBannerView(message: error)
                }
                
                BaseButton(title: "Cancel") {
                    onDismiss()
                }
                
                ProminentBaseButton(title: "Stash") {
                    Task {
                        do {
                            let result = try await viewModel.stash(at: repo, message: stashMessage.isEmpty ? nil : stashMessage)
                            if !result.isSuccess {
                                self.error = result.error
                            } else {
                                onDismiss()
                            }
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct AddRepoModal: View {
    
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State private var path: String = ""
    
    var body: some View {
        VStack (alignment:.leading) {
            ModalDescription(title: "Add Local Repository", description: "Enter the local path of your repository to add it in GitHub.")
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)

            Text("Choose a path")
                .appFont(.headline)
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
                    coordinator.dismissSheet()
                }
                ProminentBaseButton(title: "Add Repository") {
                    guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    viewModel.addExistingRepo(name: "", path: path)
                    coordinator.dismissSheet()
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
            .appFont(.body)
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
    var textTint: Color = .primary
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
                    .padding(.trailing, -6)
                    .padding(.leading, 13)
                    .appFont(.headline)
            }
            Text(title)
                .appFont(.subheadline, weight: .medium)
                .padding(.horizontal,13)
                .padding(.vertical,6)
                .foregroundColor(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .controlSize(.regular)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .buttonStyle(.bordered)
    }
}

struct ProminentBaseButton: View{
    
    var title: String
    var image: Image? = nil
    var textTint: Color = .white
    var action: (() -> Void)
    
    var body: some View {
        Button {
            action()
        } label: {
            if let image = image {
                image
                    .resizable()
                    .frame(width: 16,height: 16)
                    .padding(.trailing, -6)
                    .padding(.leading, 13)
                    .tint(.white)
                    .appFont(.headline)
            }
            Text(title)
                .appFont(.subheadline, weight: .medium)
                .padding(.horizontal,13)
                .padding(.vertical,6)
                .foregroundColor(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .controlSize(.regular)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
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
                .appFont(.title2, weight: .semibold)
                .padding(.bottom, 4)
            Text(description)
                .appFont(.body)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.7)
        }
        .padding(.vertical,4)
    }
}

struct ErrorBannerView: View {
    
    let message: String
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .appFont(.body)
            Text(message)
                .appFont(.subheadline, weight: .medium)
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
                        .appFont(.body)
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
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
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
                .appFont(.headline)
            
            CustomTextField(url: $branchName, imageName: "arrow.trianglehead.branch", placeholder: "feature/new-design")
                .padding(.bottom, 20)
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            HStack {
                Spacer()
                BaseButton(title: "Cancel") {
                    coordinator.dismissSheet()
                }
                ProminentBaseButton(title: "Create Branch") {
                    guard !branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        do {
                            _ = try await viewModel.createBranch(name: branchName, from: sourceBranch, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.error = error.localizedDescription
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
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State private var error: String?
    
    var body: some View {
        let sourceBranch = viewModel.selectedBranchForAction ?? (viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)
        VStack (alignment:.leading) {
            ModalDescription(
                title: "Merge into current branch",
                description: "Are you sure want to merge '\(sourceBranch)' into the current branch '\(viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)'?"
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
                    coordinator.dismissSheet()
                }
                
                BaseButton(title: "Rebase") {
                    self.error = nil
                    Task {
                        do {
                            try await viewModel.rebaseBranch(name: sourceBranch, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                }
                
                ProminentBaseButton(title: "Merge") {
                    self.error = nil
                    Task {
                        do {
                            try await viewModel.mergeBranch(name: sourceBranch, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.error = error.localizedDescription
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

struct DeleteBranchModal: View {
    
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
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
                .appFont(.body)
                .padding(.bottom, 20)

            HStack {
                Spacer()
                if isDeleting {
                    ProgressView()
                }
                BaseButton(title: "Cancel") {
                    coordinator.dismissSheet()
                }
                
                ProminentBaseButton(title: "Delete", textTint: .white) {
                    self.error = nil
                    Task {
                        isDeleting = true
                        do {
                            _ = try await viewModel.deleteBranch(branch: branchToDelete, force: forceDelete, isRemote: viewModel.isRemoteBranchAction, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        isDeleting = false
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
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
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
                    coordinator.dismissSheet()
                }
                
                ProminentBaseButton(title: "Rename", textTint: .white) {
                    guard !newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    self.error = nil
                    Task {
                        do {
                            _ = try await viewModel.renameBranch(oldName: oldName, newName: newBranchName, isRemote: viewModel.isRemoteBranchAction, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.error = error.localizedDescription
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

struct HistoryCherryPickModal: View {
    let viewModel: MainViewModel
    let repo: Repo
    let coordinator: AppCoordinator
    
    @State private var cherryPickHash: String = ""
    @State private var cherryPickError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ModalDescription(title: "Cherry Pick", description: "Enter the commit hash")
                .padding()
            
            if let cherryPickError {
                ErrorBannerView(message: cherryPickError) {
                    self.cherryPickError = nil
                }
                .padding(.horizontal)
            }
            
            Divider()
            CustomTextField(url: $cherryPickHash, imageName: "number", placeholder: "Enter the commit hash")
                .padding(.horizontal)
            Divider()
            HStack {
                Spacer()
                BaseButton(title: "Close") {
                    coordinator.dismissSheet()
                }
                ProminentBaseButton(title: "Cherry Pick") {
                    self.cherryPickError = nil
                    Task {
                        do {
                            _ = try await viewModel.cherryPickCommit(cherryPickHash, at: repo)
                            coordinator.dismissSheet()
                        } catch {
                            self.cherryPickError = error.localizedDescription
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 500)
    }
}
