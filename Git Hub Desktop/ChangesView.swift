//
//  ChangesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 23/05/26.
//

import SwiftUI

struct ChangesView: View {

    let repo: Repo?

    let changedFiles : [String] = [
        "ContentView.swift",
        "TopBar.swift",
        "ChangesView.swift",
        "README.md"
    ]
    @State private var commitMessage: String = ""
    @State private var selectedFiles = Set<String>()

    var body: some View {
        
        if changedFiles.count == 0 {
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
            TitleView(title: "Uncommitted Changes", desc: "You have \(changedFiles.count) modified files in your working directory.")
            HStack {
                TextField("Enter commit message", text: $commitMessage)
                    .textFieldStyle(.plain)
                    .font(Font.system(size: 14, weight: .regular))
                    .padding(.leading)
                SmallProminentButton(title: "Commit") {
                    
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
                        
                    }
                    SmallButton(title: "Stage Selected ") {
                        
                    }
                    SmallButton(title: "Discard All", tint: .red) {
                        
                    }
                }
                .padding()
                
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(changedFiles, id: \.self) { file in
                            HStack(spacing: 12) {
                                
                                Image(systemName: "doc.text")
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file)
                                        .font(.system(size: 13, weight: .medium))
                                    Text("Modified")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selectedFiles.contains(file) ? .blue : .secondary)
                                    .font(Font.system(size: 16))
                            }
                            .padding()
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                if selectedFiles.contains(file) {
                                    selectedFiles.remove(file)
                                } else {
                                    selectedFiles.insert(file)
                                }
                            }
                            .overlay {
                                if selectedFiles.contains(file) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .opacity(0.1)
                                }
                            }
                            
                            if file != changedFiles.last {
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
    @State var action: () -> Void
    
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
    @State var tint: Color = .black
    @State var action: () -> Void

    
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
    let repo = Repo.init(name: "tvOS-Beacon", path: "test", currentBranch: "main")
    ChangesView(repo: repo)
        .frame(width: 1000)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .padding()
}
