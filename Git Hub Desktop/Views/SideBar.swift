//
//  SideBar.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct Sidebar: View {
    
    @Binding var selectedRepo: Repo?
    @Binding var selectedSection: RepoSection
    
    let repos: [Repo]
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            Text("REPOSITORIES")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                
                ForEach(repos) { repo in
                    
                    Button {
                        selectedRepo = repo
                    } label: {
                        
                        HStack {
                            Image(systemName: "folder")
                            Text(repo.name)
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            selectedRepo == repo
                            ? Color.gray.opacity(0.15)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            NSWorkspace.shared.open(URL(fileURLWithPath: repo.path))
                        } label: {
                            Label("Show in Finder", systemImage: "finder")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            viewModel.removeRepository(repo)
                        } label: {
                            Label("Remove Repository", systemImage: "trash")
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                Button {
                    coordinator.presentClone()
                } label: {
                    HStack {
                        Image(systemName: "plus.square.dashed")
                        Text("Clone Repository")
                        Spacer()
                    }
                    .padding(8)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                Button {
                    coordinator.presentAddRepo()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Add Local Repository")
                        Spacer()
                    }
                    .padding(8)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.blue)
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .padding(.vertical)
            
            Text("VIEWS")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 4) {
                
                ForEach(RepoSection.allCases) { section in
                    
                    Button {
                        selectedSection = section
                        if section == .history {
                            viewModel.historyBranch = nil
                            if let repo = viewModel.selectedRepo {
                                Task {
                                    await viewModel.loadRepositoryData(for: repo)
                                }
                            }
                        }
                    } label: {
                        
                        HStack {
                            Image(systemName: section.icon)
                            Text(section.title)
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            selectedSection == section
                            ? Color.blue.opacity(0.15)
                            : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 260)
    }
}

#Preview {
    Sidebar(
        selectedRepo: .constant(nil),
        selectedSection: .constant(.changes),
        repos: [],
        viewModel: MainViewModel(),
        coordinator: AppCoordinator()
    )
}
