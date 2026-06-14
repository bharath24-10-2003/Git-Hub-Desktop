import Foundation

@Observable
final class RepoStore {
    
    var repos: [Repo] = []
    
    private let fileURL: URL
    
    init() {
        let fm = FileManager.default
        
        let appSupport = fm.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let appFolder = appSupport.appendingPathComponent("GitClient", isDirectory: true)
        
        // Create directory if needed
        if !fm.fileExists(atPath: appFolder.path) {
            try? fm.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        self.fileURL = appFolder.appendingPathComponent("repos.json")
        
        load()
    }
    
    // MARK: - Load
    
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            repos = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            repos = try JSONDecoder().decode([Repo].self, from: data)
            repos.sort { $0.lastOpened > $1.lastOpened }
        } catch {
            print("Failed to load repos:", error)
            repos = []
        }
    }
    
    // MARK: - Save
    
    private func persist() {
        do {
            let data = try JSONEncoder().encode(repos)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to save repos:", error)
        }
    }
    
    // MARK: - Add Repo
    
    func addRepo(name: String, path: String) {
        guard !repos.contains(where: { $0.path == path }) else {
            return // prevent duplicates
        }
        
        let repo = Repo(name: name, path: path, currentBranch: "main")
        repos.insert(repo, at: 0)
        persist()
    }
    
    // MARK: - Remove Repo
    
    func removeRepo(_ repo: Repo) {
        repos.removeAll { $0.id == repo.id }
        persist()
    }
    
    // MARK: - Update Last Opened
    
    func markOpened(_ repo: Repo) {
        guard let index = repos.firstIndex(of: repo) else { return }
        repos[index].lastOpened = Date()
        persist()
    }
}
