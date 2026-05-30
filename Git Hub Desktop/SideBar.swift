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
                }
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
}
