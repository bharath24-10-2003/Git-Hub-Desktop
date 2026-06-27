import os
import re

filepath = 'ViewModels/MainViewModel.swift'
with open(filepath, 'r') as f:
    content = f.read()

# 1. Replace errorMessage declaration
content = re.sub(
    r'@Published var errorMessage: String\? = nil',
    r'@Published var currentGitError: GitAnalyzedError? = nil',
    content
)

# 2. Replace extractErrorMessage usages throwing errors
content = re.sub(
    r'throw GitError\.executionFailed\(extractErrorMessage\(from:\s*result\)\)',
    r'throw GitErrorAnalyzer.analyze(result: result)',
    content
)

# 3. Replace direct errorMessage assignments from result
content = re.sub(
    r'self\.errorMessage = extractErrorMessage\(from:\s*result\)',
    r'self.currentGitError = GitErrorAnalyzer.analyze(result: result)',
    content
)

# 4. Replace self.errorMessage = nil
content = re.sub(
    r'self\.errorMessage = nil',
    r'self.currentGitError = nil',
    content
)

# 5. Replace simple error assignments in catch blocks
# self.errorMessage = error.localizedDescription -> self.handleError(error)
content = re.sub(
    r'self\.errorMessage = error\.localizedDescription',
    r'self.handleError(error)',
    content
)

# 6. Add handleError helper and handleRecoveryAction at the end of the class
# We will just append it before the last closing brace.
helper_funcs = """
    // MARK: - Smart Error Handling
    
    @MainActor
    func handleError(_ error: Error) {
        if let gitError = error as? GitAnalyzedError {
            self.currentGitError = gitError
        } else if let gitError = error as? GitError {
            self.currentGitError = GitAnalyzedError(type: .unknown, title: "Git Error", description: gitError.localizedDescription, reason: nil, suggestedFix: nil, primaryAction: .dismiss, secondaryAction: nil, rawOutput: "")
        } else {
            self.currentGitError = GitAnalyzedError(type: .unknown, title: "Error", description: error.localizedDescription, reason: nil, suggestedFix: nil, primaryAction: .dismiss, secondaryAction: nil, rawOutput: "")
        }
    }
    
    @MainActor
    func handleRecoveryAction(_ action: GitRecoveryAction) {
        self.currentGitError = nil
        
        Task {
            switch action {
            case .stageAllAndCommit:
                if let repo = selectedRepo {
                    do {
                        try await gitService.run(["add", "."], at: repo.path)
                        // Trigger commit view or commit directly if we have a message?
                        // For safety, let's just open changes so user can commit.
                    } catch {}
                }
            case .openChanges:
                // Do nothing, UI is already there or we just dismiss
                break
            case .returnToCommitEditor:
                break
            case .pullAndRebase:
                if let repo = selectedRepo, let branch = selectedBranch {
                    do {
                        try await pull(repo: repo, branchName: branch.name, useRebase: true)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .pullAndMerge:
                if let repo = selectedRepo, let branch = selectedBranch {
                    do {
                        try await pull(repo: repo, branchName: branch.name, useRebase: false)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .forcePush:
                if let repo = selectedRepo, let branch = selectedBranch {
                    do {
                        let remote = "origin"
                        _ = try await gitService.run(["push", remote, branch.name, "--force"], at: repo.path)
                        await loadRepositoryData(for: repo)
                    } catch {
                        await self.handleError(error)
                    }
                }
            case .openMergeAssistant, .openRebaseAssistant, .openCherryPickAssistant:
                break
            case .abortMerge:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["merge", "--abort"], at: repo.path) } catch {}
                }
            case .abortRebase:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["rebase", "--abort"], at: repo.path) } catch {}
                }
            case .skipCommit:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["rebase", "--skip"], at: repo.path) } catch {}
                }
            case .abortCherryPick:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["cherry-pick", "--abort"], at: repo.path) } catch {}
                }
            case .createBranch, .checkoutExistingBranch, .renameBranch:
                break
            case .stashChanges:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["stash"], at: repo.path) } catch {}
                }
            case .discardFiles:
                if let repo = selectedRepo {
                    do { _ = try await gitService.run(["reset", "--hard"], at: repo.path) } catch {}
                }
            case .updateCredentials, .retry, .editRemoteURL, .openNetworkSettings, .pushAndSetUpstream, .viewFullLog, .openRepository, .dismiss:
                break
            }
            
            // Reload if needed
            if let repo = selectedRepo {
                await loadRepositoryData(for: repo)
            }
        }
    }
"""

content = content.replace('\n    private func extractErrorMessage(from result: GitResult) -> String {', '\n    // MARK: - Smart Error Handling (removed extractErrorMessage)\n    /*')
content = content.replace('        return result.error.isEmpty ? result.output : result.error\n    }', '        */\n')

# Insert the helper funcs before the last closing brace
last_brace_index = content.rfind('}')
if last_brace_index != -1:
    content = content[:last_brace_index] + helper_funcs + '\n' + content[last_brace_index:]

with open(filepath, 'w') as f:
    f.write(content)

print("Updated MainViewModel")
