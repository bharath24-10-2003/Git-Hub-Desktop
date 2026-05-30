//
//  ViewModel.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import Foundation
import AppKit

@Observable
class ViewModel {
    
    var service: GitService
    var store: RepoStore
    
    init () {
        self.service = GitService()
        self.store = RepoStore()
    }
    
    func getRepoCollection() -> [Repo] {
        return store.repos
    }
    
    func cloneRepo(url: String, destinationPath: String) {
        
        let repoName = extractRepoName(from: url)
        store.addRepo(name: repoName, path: destinationPath)
        
    }
    
    func addExistingRepo(name: String, path: String) {
        
        if let path = selectFolder() {
            
            let name = URL(fileURLWithPath: path).lastPathComponent
            store.addRepo(name: name, path: path)
            
        }
        
    }
    
    func selectFolder() -> String? {
        
        let panel = NSOpenPanel()
        panel.title = "Select Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        
        let response = panel.runModal()
        
        if response == .OK {
            return panel.url?.path
        }
        
        return nil
    }
    
    
    func extractRepoName(from url: String) -> String {
        
        let url = URL(string: url)
        
        guard let host = url?.host else {
            return url?.absoluteString ?? ""
        }
        
        return host
    }
}
