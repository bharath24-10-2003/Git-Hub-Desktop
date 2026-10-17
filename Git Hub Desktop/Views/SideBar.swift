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
    @Environment(\.openSettings) private var openSettings
    
    let repos: [Repo]
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading)  {
                Text("REPOSITORIES")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView([.vertical]) {
                    VStack(alignment: .leading, spacing: 4) {
                        
                        ForEach(repos) { repo in
                            
                            Button {
                                selectedRepo = repo
                            } label: {
                                
                                HStack {
                                    Image(systemName: "folder")
                                    Text(repo.name)
                                        .appFont(.body)
                                    Spacer()
                                }
                                .padding(10)
                                .contentShape(Rectangle())
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
                            .contentShape(Rectangle())
                            .appFont(.subheadline)
                            .fontWeight(.medium)
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
                            .contentShape(Rectangle())
                            .appFont(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                            .background(Color.blue.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(0)
                }
            }
            .frame(maxHeight: 300)
 
            
            Divider()
                .padding(.vertical)
            
            ForEach(RepoSection.Group.allCases, id: \.self) { group in
                Text(group.title.uppercased())
                    .appFont(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(RepoSection.allCases.filter { $0.group == group }) { section in
                        Button {
                            selectedSection = section
                            if section == .history {
                                viewModel.historyBranch = nil
                            }
                            if group == .git, let repo = viewModel.selectedRepo {
                                Task {
                                    await viewModel.loadRepositoryData(for: repo)
                                }
                            }
                        } label: {
                            HStack {
                                if section == .pullRequests {
                                    Image("pull-request")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundStyle(.white)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: section.icon)
                                }
                                Text(section.title)
                                    .appFont(.body)
                                Spacer()
                            }
                            .padding(10)
                            .contentShape(Rectangle())
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
            }
            Spacer()

            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings")
                        .appFont(.body)
                    Spacer()
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

#Preview {
    let vm = MainViewModel()
    return Sidebar(
        selectedRepo: .constant(nil),
        selectedSection: .constant(.changes),
        repos: vm.store.repos,
        viewModel: vm,
        coordinator: AppCoordinator(viewModel: vm)
    )
    .frame(height: 600)
}
