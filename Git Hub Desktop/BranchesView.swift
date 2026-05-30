//
//  BranchesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct BranchesView: View {
    
    let repo: Repo
    let viewModel: ViewModel
    
    @State var searchLocalBranch: String = ""
    @State var searchRemoteBranch: String = ""
    @State var selectedBranch: String? = nil
    
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
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "Branches", desc: "Manage your Local and Remote branches here.")
                Spacer()
                
                if let selected = selectedBranch {
                    BaseButton(title: "Switch to '\(selected)'") {
                        Task {
                            try? await viewModel.checkout(branch: selected, at: repo)
                            selectedBranch = nil
                        }
                    }
                }
                
                ProminentBaseButton(title: "New Branch", image: Image(systemName: "plus")) {
                    viewModel.showNewBranchModal = true
                }
                .padding()
            }
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pc")
                        Text("Local Branch")
                            .font(Font.system(size: 14, weight: .semibold))
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
                        ForEach (filteredLocalBranches, id: \.self) { branch in
                            BranchText(branchName: branch, isSelected: selectedBranch == branch, isCurrent: branch == viewModel.currentBranch)
                                .onTapGesture {
                                    selectedBranch = branch
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
                        Image(systemName: "cloud.fill")
                        Text("Remote Branch")
                            .font(Font.system(size: 14, weight: .semibold))
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
                        }
                        .padding(.horizontal)
                    }
                }
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
                .font(Font.system(size: 14, weight: .semibold))
            Text(branchName)
                .font(Font.system(size: 14, weight: .semibold,design: .rounded))
                .underline(color: isCurrent ? .blue : .clear)
            Spacer()
            if isCurrent {
                Text("current")
                    .font(.caption)
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
#Preview {
    @Previewable @State var text: String = ""
    CustomSearchBar(text: $text, placeholder: "Search Branch")
        .padding()
}
