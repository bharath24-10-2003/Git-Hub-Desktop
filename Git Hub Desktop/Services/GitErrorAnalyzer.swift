import Foundation

final class GitErrorAnalyzer {
    
    static func analyze(result: GitResult, command: String = "git") -> GitAnalyzedError {
        let rawOutput = (result.error + "\n" + result.output).trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerOutput = rawOutput.lowercased()
        
        // 1. Nothing to commit
        if lowerOutput.contains("nothing to commit") || 
            lowerOutput.contains("nothing added to commit") || 
            lowerOutput.contains("no changes added to commit") || 
            lowerOutput.contains("working tree clean") {
            return GitAnalyzedError(
                type: .nothingToCommit,
                title: "Nothing to Commit",
                description: "No staged files were found.",
                reason: "You haven't added any modified files to the staging area yet.",
                suggestedFix: "Stage your files before committing.",
                primaryAction: .stageAllAndCommit,
                secondaryAction: .openChanges,
                rawOutput: rawOutput
            )
        }
        
        // 2. Empty Commit Message
        if lowerOutput.contains("aborting commit due to empty commit message") {
            return GitAnalyzedError(
                type: .emptyCommitMessage,
                title: "Empty Commit Message",
                description: "Commit message cannot be empty.",
                reason: "Git requires a message to explain what changes were made in this commit.",
                suggestedFix: "Provide a valid commit message.",
                primaryAction: .returnToCommitEditor,
                secondaryAction: .dismiss,
                rawOutput: rawOutput
            )
        }
        
        // 3. Push Rejected
        if lowerOutput.contains("non-fast-forward") || 
            lowerOutput.contains("fetch first") || 
            lowerOutput.contains("failed to push some refs") {
            return GitAnalyzedError(
                type: .pushRejected,
                title: "Push Rejected",
                description: "Your local branch is behind the remote branch.",
                reason: "Someone else has pushed changes to this branch since you last pulled.",
                suggestedFix: "Pull the latest changes before pushing.",
                primaryAction: .pullAndRebase,
                secondaryAction: .pullAndMerge, // Might also want Force Push, but let's stick to these.
                rawOutput: rawOutput
            )
        }
        
        // 4. Merge Conflict
        if lowerOutput.contains("conflict") && lowerOutput.contains("merge") ||
            lowerOutput.contains("automatic merge failed") {
            return GitAnalyzedError(
                type: .mergeConflict,
                title: "Merge Conflict",
                description: "Merge conflicts were detected.",
                reason: "Git could not automatically merge the changes because the same lines of code were modified differently.",
                suggestedFix: "Resolve the conflicts manually in the Merge Assistant.",
                primaryAction: .openMergeAssistant,
                secondaryAction: .abortMerge,
                rawOutput: rawOutput
            )
        }
        
        // 5. Rebase Conflict
        if lowerOutput.contains("resolve all conflicts manually") || 
            (lowerOutput.contains("could not apply") && lowerOutput.contains("rebase")) {
            return GitAnalyzedError(
                type: .rebaseConflict,
                title: "Rebase Conflict",
                description: "Rebase stopped because of conflicts.",
                reason: "Git could not automatically apply a commit because of conflicting changes.",
                suggestedFix: "Resolve the conflicts to continue the rebase.",
                primaryAction: .openRebaseAssistant,
                secondaryAction: .abortRebase,
                rawOutput: rawOutput
            )
        }
        
        // 6. Cherry Pick Conflict
        if lowerOutput.contains("after resolving the conflicts") && lowerOutput.contains("cherry-pick") {
            return GitAnalyzedError(
                type: .cherryPickConflict,
                title: "Cherry Pick Conflict",
                description: "Cherry-pick has conflicts.",
                reason: "The commit you are trying to apply conflicts with your current changes.",
                suggestedFix: "Resolve the conflicts or abort.",
                primaryAction: .openCherryPickAssistant,
                secondaryAction: .abortCherryPick,
                rawOutput: rawOutput
            )
        }
        
        // 7. Detached HEAD
        if lowerOutput.contains("head detached") || lowerOutput.contains("detached head") {
            return GitAnalyzedError(
                type: .detachedHead,
                title: "Detached HEAD State",
                description: "You are currently in a detached HEAD state.",
                reason: "You checked out a specific commit or tag instead of a branch. Any new commits will be lost when you switch away.",
                suggestedFix: "Create a new branch to keep your changes.",
                primaryAction: .createBranch,
                secondaryAction: .checkoutExistingBranch,
                rawOutput: rawOutput
            )
        }
        
        // 8. Branch Already Exists
        if lowerOutput.contains("already exists") && lowerOutput.contains("branch") {
            return GitAnalyzedError(
                type: .branchAlreadyExists,
                title: "Branch Already Exists",
                description: "A branch with that name already exists.",
                reason: "Branch names must be unique in the repository.",
                suggestedFix: "Checkout the existing branch or choose a different name.",
                primaryAction: .checkoutExistingBranch,
                secondaryAction: .renameBranch,
                rawOutput: rawOutput
            )
        }
        
        // 9. Untracked Files Blocking Checkout
        if lowerOutput.contains("would be overwritten") && lowerOutput.contains("untracked working tree files") {
            return GitAnalyzedError(
                type: .untrackedFilesBlockingCheckout,
                title: "Untracked Files in the Way",
                description: "Some untracked files would be overwritten.",
                reason: "Checking out this branch requires replacing untracked files you have in your working directory.",
                suggestedFix: "Stash your changes or discard the untracked files.",
                primaryAction: .stashChanges,
                secondaryAction: .discardFiles,
                rawOutput: rawOutput
            )
        }
        
        // 10. Authentication Failed
        if lowerOutput.contains("authentication failed") || lowerOutput.contains("403") || lowerOutput.contains("401") {
            return GitAnalyzedError(
                type: .authenticationFailed,
                title: "Authentication Failed",
                description: "Authentication failed.",
                reason: "Your Git credentials might be expired, invalid, or you lack permissions for this repository.",
                suggestedFix: "Update your credentials or personal access token.",
                primaryAction: .updateCredentials,
                secondaryAction: .retry,
                rawOutput: rawOutput
            )
        }
        
        // 11. Repository Not Found
        if lowerOutput.contains("repository not found") || lowerOutput.contains("not found") {
            return GitAnalyzedError(
                type: .repositoryNotFound,
                title: "Repository Not Found",
                description: "The remote repository could not be found.",
                reason: "The remote URL might be incorrect, or the repository was deleted or made private.",
                suggestedFix: "Verify the remote URL.",
                primaryAction: .editRemoteURL,
                secondaryAction: .retry,
                rawOutput: rawOutput
            )
        }
        
        // 12. Network Error
        if lowerOutput.contains("could not resolve host") || lowerOutput.contains("connection timed out") || lowerOutput.contains("network unreachable") {
            return GitAnalyzedError(
                type: .networkError,
                title: "Network Error",
                description: "Unable to connect to the remote server.",
                reason: "Your internet connection might be offline, or a firewall is blocking the connection.",
                suggestedFix: "Check your internet connection.",
                primaryAction: .retry,
                secondaryAction: .openNetworkSettings,
                rawOutput: rawOutput
            )
        }
        
        // 13. No Upstream Branch
        if lowerOutput.contains("has no upstream branch") {
            return GitAnalyzedError(
                type: .noUpstreamBranch,
                title: "No Upstream Branch",
                description: "This branch is not tracking a remote branch.",
                reason: "You haven't pushed this newly created local branch to the remote server yet.",
                suggestedFix: "Push the branch and set it to track the remote.",
                primaryAction: .pushAndSetUpstream,
                secondaryAction: .dismiss,
                rawOutput: rawOutput
            )
        }
        
        // 14. Hook Failed
        if lowerOutput.contains("pre-commit") || lowerOutput.contains("pre-push") || lowerOutput.contains("hook declined") || lowerOutput.contains("hook failed") {
            return GitAnalyzedError(
                type: .hookFailed,
                title: "Git Hook Failed",
                description: "A Git hook prevented the operation.",
                reason: "A script configured in this repository (like a linter or tester) failed.",
                suggestedFix: "Review the hook logs and fix the reported issues.",
                primaryAction: .viewFullLog,
                secondaryAction: .retry,
                rawOutput: rawOutput
            )
        }
        
        // 15. Permission Denied
        if lowerOutput.contains("permission denied") || lowerOutput.contains("could not read") || lowerOutput.contains("access denied") {
            return GitAnalyzedError(
                type: .permissionDenied,
                title: "Permission Denied",
                description: "The application doesn't have permission to access the repository or file.",
                reason: "macOS sandbox or file permissions are preventing Git Hub Desktop from reading the files.",
                suggestedFix: "Grant access to the folder.",
                primaryAction: .openRepository,
                secondaryAction: .retry,
                rawOutput: rawOutput
            )
        }
        
        // 16. Unknown Error
        return GitAnalyzedError(
            type: .unknown,
            title: "Git Operation Failed",
            description: "Something went wrong while running \(command).",
            reason: nil,
            suggestedFix: nil,
            primaryAction: .viewFullLog,
            secondaryAction: .dismiss,
            rawOutput: rawOutput.isEmpty ? "No output provided." : rawOutput
        )
    }
}
