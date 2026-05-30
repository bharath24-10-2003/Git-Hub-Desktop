//
//  HistoryView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct HistoryView: View {
    
    @State var currentBranch: String = ""
    @State var commits: [Commit] = []
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "History", desc: "All commits in \(currentBranch) branch")
                BaseButton(title: "Refresh") {
                    
                }
                .padding(.trailing, 24)
            }
            
            ScrollView(.vertical, showsIndicators: false) {
                ForEach(commits, id: \.self) { commit in
                    HistoryCommitView(commit: commit)
                }
                .padding()
            }
            .padding(.bottom, 14)
        }
    }
}

struct HistoryCommitView: View {
    
    @State var commit: Commit
    
    var body: some View {
        HStack {
            Text((commit.author.split(separator: "<")[1].split(separator: "").first?.uppercased() ?? " "))
                .padding()
                .font(Font.system(size: 24, weight: .bold, design: .rounded))
                .overlay {
                    Circle()
                        .opacity(0.2)
                }
            VStack(alignment: .leading) {
                Text(commit.message)
                    .font(Font.system(size: 14,weight: .semibold))
                HStack {
                    VStack(alignment: .leading) {
                        Text (commit.displayDate)
                            .font(Font.system(size: 12,weight: .regular))
                        Text(commit.displayTime)
                            .font(Font.system(size: 12,weight: .regular))
                    }
                    .padding(.trailing, 24)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(commit.shortHash, forType: .string)
                    } label: {
                        Text (commit.shortHash)
                            .font(.caption)
                            .frame(width: 50)
                    }
                }
            }
            Spacer()
            Button {
                
            } label: {
                Text("Revert")
                    .padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buttonStyle(.glass)
            Button {
                
            } label: {
                Text("Cherry pick")
                    .padding(3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray, lineWidth: 1)
                .opacity(0.2)
        }
    }
}

#Preview {
        HistoryView(commits: Commit.previewData)
//    let commit = Commit(id: "123", shortHash: "a56afc69fd5b4a6d3da12d72fa784efd320b7109", author: "Bharath <bharath.a@tringapps.com>", date: "Thu Nov 13 14:15:59 2025 +0530", message: "Initial commit")
//    HistoryCommitView(commit: commit)
//        .padding()
}
