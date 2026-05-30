//
//  BranchesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct BranchesView: View {
    
    let localBranches: [String] = ["main", "dev", "feature/login", "feature/signup"]
    let remoteBranches: [String] = ["origin/main", "origin/dev", "origin/feature/login", "origin/feature/signup"]
    
    @State var searchLocalBranch: String = ""
    @State var searchRemoteBranch: String = ""
    
    @State var selectedBranch: String? = "main"
    @State var currentBranch: String?
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "Branches", desc: "Manage your Local and Remote branches here.")
                Spacer()
                BaseButton(title: "Switch Branch") {
                    
                }
                ProminentBaseButton(title: "New Branch", image: Image(.plus)) {
                    
                }
                .padding()
            }
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pc")
                        Text("Local Branch")
                            .font(Font.system(size: 14, weight: .semibold))
                        Text("2")
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
                    
                    ScrollView {
                        ForEach (localBranches, id: \.self) { branch in
                            BranchText(branchName: branch, isSelected: selectedBranch == "", isCurrent: branch == currentBranch)
                                .onTapGesture {
                                    selectedBranch = ""
                                }
                        }
                        .padding(.horizontal)
                    }
                    .searchable(text: $searchLocalBranch)
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
                        Text("2")
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
                    
                    ScrollView {
                        ForEach (remoteBranches, id: \.self) { branch in
                            BranchText(branchName: branch, isSelected: selectedBranch == branch, isCurrent: branch == currentBranch)
                                .onTapGesture {
                                    selectedBranch = branch
                                }
                        }
                        .padding(.horizontal)
                    }
                    .searchable(text: $searchRemoteBranch)
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

struct BranchText: View {
    
    let branchName: String
    @State var isSelected: Bool
    @State var isCurrent: Bool
    
    var body: some View {
        HStack {
            Image(.branch)
                .font(Font.system(size: 14, weight: .semibold))
            Text(branchName)
                .font(Font.system(size: 14, weight: .semibold,design: .rounded))
                .underline(color: isCurrent ? .blue : .clear)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(lineWidth: 1)
                    .padding(1)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.1)
            }
        }
    }
}
#Preview {
    BranchesView()
}
