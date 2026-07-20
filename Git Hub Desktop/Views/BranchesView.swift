//
//  BranchesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct BranchesView: View {
    
    let repo: Repo
    let viewModel: MainViewModel
    @Binding var selectedSection: RepoSection
    let coordinator: AppCoordinator
    
    @State var searchLocalBranch: String = ""
    @State var searchRemoteBranch: String = ""
    @State var searchTag: String = ""
    @State var selectedBranch: String? = nil
    @State private var error: String?
    
    var filteredLocalBranches: [String] {
        if searchLocalBranch.isEmpty {
            return viewModel.localBranches
        } else {
            return viewModel.localBranches.filter { $0.localizedCaseInsensitiveContains(searchLocalBranch) }
        }
    }
    
    var filteredRemoteBranches: [String] {
        if searchRemoteBranch.isEmpty {
            return viewModel.remoteBranches
        } else {
            return viewModel.remoteBranches.filter { $0.localizedCaseInsensitiveContains(searchRemoteBranch) }
        }
    }
    
    var filteredTags: [String] {
        if searchTag.isEmpty {
            return viewModel.tags
        } else {
            return viewModel.tags.filter { $0.localizedCaseInsensitiveContains(searchTag) }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "Branches", desc: "Manage your Local and Remote branches here.")
                Spacer()
                if let selected = selectedBranch, selected != viewModel.currentBranch {
                    BaseButton(title: "Switch to '\(selected)'") {
                        self.error = nil
                        Task {
                            do {
                                let result = try await viewModel.checkout(branch: selected, at: repo)
                                if result.isSuccess == true {
                                    selectedBranch = nil
                                } else {
                                    self.error = viewModel.errorMessage
                                }
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    BaseButton(title: "Merge/Rebase Branch") {
                        viewModel.selectedBranchForAction = selected
                        coordinator.presentPullBranch(for: repo)
                    }
                }
                
                ProminentBaseButton(title: "New Branch", image: Image(.plus)) {
                    viewModel.selectedBranchForAction = selectedBranch
                    coordinator.presentNewBranch(for: repo)
                }
                .padding()
            }
            
            if let error {
                ErrorBannerView(message: error, detailedError: viewModel.lastDetailedError) {
                    self.error = nil
                }
                .padding(.horizontal)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pc")
                        Text("Local Branch")
                            .appFont(size: 14, weight: .semibold)
                        Text("\(viewModel.localBranches.count)")
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .opacity(0.2)
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    CustomSearchBar(text: $searchLocalBranch, placeholder: "Search local branches...")
                    
                    ScrollView {
                        if filteredLocalBranches.contains(viewModel.currentBranch) {
                            VStack(alignment: .leading) {
                                Text("Current Branch")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                    .padding(.horizontal, 4)
                                
                                LocalBranchRow(branch: viewModel.currentBranch, repo: repo, viewModel: viewModel, coordinator: coordinator, selectedSection: $selectedSection, selectedBranch: $selectedBranch)
                                    .padding(.horizontal)
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        let otherBranches = filteredLocalBranches.filter { $0 != viewModel.currentBranch }
                        if !otherBranches.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Local Branches")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                    .padding(.horizontal, 4)
                                
                                ForEach(otherBranches, id: \.self) { branch in
                                    LocalBranchRow(branch: branch, repo: repo, viewModel: viewModel, coordinator: coordinator, selectedSection: $selectedSection, selectedBranch: $selectedBranch)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 1)
                        .opacity(0.2)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "cloud.fill")
                        Text("Remote Branch")
                            .appFont(size: 14, weight: .semibold)
                        Text("\(viewModel.remoteBranches.count)")
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .opacity(0.2)
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    CustomSearchBar(text: $searchRemoteBranch, placeholder: "Search remote branches...")
                    
                    ScrollView {
                        ForEach (filteredRemoteBranches, id: \.self) { branch in
                            // Remote branch is read-only, checkout creates local tracking branch
                            BranchText(branchName: branch, isSelected: selectedBranch == branch, isCurrent: branch == viewModel.currentBranch)
                                .onTapGesture {
                                    selectedBranch = branch
                                }
                                .contextMenu {
                                    Button {
                                        viewModel.selectedBranchForAction = branch
                                        viewModel.isRemoteBranchAction = true
                                        coordinator.renameBranch(for: repo)
                                    } label: {
                                        HStack {
                                            Image(systemName: "pencil.line")
                                            Text("Rename")
                                        }
                                    }
                                    Button {
                                        viewModel.historyBranch = branch
                                        selectedSection = .history
                                        Task {
                                            await viewModel.loadRepositoryData(for: repo)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                            Text("See History")
                                        }
                                    }
                                    Button {
                                        viewModel.selectedBranchForAction = branch
                                        viewModel.isRemoteBranchAction = true
                                        coordinator.presentDeleteBranch(for: repo)
                                    } label: {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete")
                                        }
                                    }
                                } preview: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(branch)
                                            .appFont(size: 16, weight: .semibold)
                                    }
                                    .padding(10)
                                }
                        }
                        .padding(.horizontal)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 1)
                        .opacity(0.2)
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "tag.fill")
                        Text("Tags")
                            .appFont(size: 14, weight: .semibold)
                        Text("\(viewModel.tags.count)")
                            .padding(.vertical, 2)
                            .padding(.horizontal, 10)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .opacity(0.2)
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    Divider()
                    
                    CustomSearchBar(text: $searchTag, placeholder: "Search tags...")
                    
                    ScrollView {
                        ForEach (filteredTags, id: \.self) { tag in
                            TagText(tagName: tag, isSelected: selectedBranch == tag)
                                .onTapGesture {
                                    selectedBranch = tag
                                }
                                .contextMenu {
                                    Button {
                                        viewModel.historyBranch = tag
                                        selectedSection = .history
                                        Task {
                                            await viewModel.loadRepositoryData(for: repo)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                            Text("See History")
                                        }
                                    }
                                } preview: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(tag)
                                            .appFont(size: 16, weight: .semibold)
                                    }
                                    .padding(10)
                                }
                        }
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: 200)
                .overlay {
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(lineWidth: 1)
                        .opacity(0.2)
                }
            }
        }
    }
}

struct CustomSearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .padding(.vertical, 1)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(lineWidth: 1)
                .opacity(0.2)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

struct BranchText: View {
    
    let branchName: String
    let isSelected: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.trianglehead.branch")
                .appFont(size: 14, weight: .semibold)
            Text(branchName)
                .appFont(size: 14, weight: .semibold, design: .rounded)
                .underline(color: isCurrent ? .blue : .clear)
            Spacer()
            if isCurrent {
                Text("current")
                    .appFont(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 10).opacity(0.1))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .padding(1)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.1)
            }
        }
    }
}

struct LocalBranchRow: View {
    let branch: String
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    @Binding var selectedSection: RepoSection
    @Binding var selectedBranch: String?

    var body: some View {
        BranchText(branchName: branch, isSelected: selectedBranch == branch, isCurrent: branch == viewModel.currentBranch)
            .onTapGesture {
                selectedBranch = branch
            }
            .contextMenu {
                Button {
                    viewModel.selectedBranchForAction = branch
                    viewModel.isRemoteBranchAction = false
                    coordinator.renameBranch(for: repo)
                } label: {
                    HStack {
                        Image(systemName: "pencil.line")
                        Text("Rename")
                    }
                }
                Button {
                    viewModel.historyBranch = branch
                    selectedSection = .history
                    Task {
                        await viewModel.loadRepositoryData(for: repo)
                    }
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("See History")
                    }
                }
                Button {
                    viewModel.selectedBranchForAction = branch
                    viewModel.isRemoteBranchAction = false
                    coordinator.presentDeleteBranch(for: repo)
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                }
            } preview: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(branch)
                        .appFont(size: 16, weight: .semibold)
                }
                .padding(10)
            }
    }
}

struct TagText: View {
    let tagName: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "tag")
                .appFont(size: 14, weight: .semibold)
            Text(tagName)
                .appFont(size: 14, weight: .semibold, design: .rounded)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .padding(1)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.1)
            }
        }
    }
}
