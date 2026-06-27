import Foundation
import SwiftUI

enum GitRecoveryAction: Equatable {
    case stageAllAndCommit
    case openChanges
    case returnToCommitEditor
    case pullAndRebase
    case pullAndMerge
    case forcePush
    case openMergeAssistant
    case openRebaseAssistant
    case abortMerge
    case abortRebase
    case skipCommit
    case openCherryPickAssistant
    case abortCherryPick
    case createBranch
    case checkoutExistingBranch
    case renameBranch
    case stashChanges
    case discardFiles
    case updateCredentials
    case retry
    case editRemoteURL
    case openNetworkSettings
    case pushAndSetUpstream
    case viewFullLog
    case openRepository
    case dismiss
    
    var title: String {
        switch self {
        case .stageAllAndCommit: return "Stage All & Commit"
        case .openChanges: return "Open Changes"
        case .returnToCommitEditor: return "Return to Editor"
        case .pullAndRebase: return "Pull & Rebase"
        case .pullAndMerge: return "Pull & Merge"
        case .forcePush: return "Force Push"
        case .openMergeAssistant: return "Open Merge Assistant"
        case .openRebaseAssistant: return "Open Rebase Assistant"
        case .abortMerge: return "Abort Merge"
        case .abortRebase: return "Abort Rebase"
        case .skipCommit: return "Skip Commit"
        case .openCherryPickAssistant: return "Open Cherry Pick Assistant"
        case .abortCherryPick: return "Abort Cherry Pick"
        case .createBranch: return "Create Branch"
        case .checkoutExistingBranch: return "Checkout Branch"
        case .renameBranch: return "Rename Branch"
        case .stashChanges: return "Stash Changes"
        case .discardFiles: return "Discard Files"
        case .updateCredentials: return "Update Credentials"
        case .retry: return "Retry"
        case .editRemoteURL: return "Edit Remote URL"
        case .openNetworkSettings: return "Network Settings"
        case .pushAndSetUpstream: return "Push & Set Upstream"
        case .viewFullLog: return "View Full Log"
        case .openRepository: return "Open Repository"
        case .dismiss: return "Dismiss"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .forcePush, .discardFiles, .abortMerge, .abortRebase, .abortCherryPick:
            return true
        default:
            return false
        }
    }
}

enum GitErrorType: Equatable {
    case nothingToCommit
    case emptyCommitMessage
    case pushRejected
    case mergeConflict
    case rebaseConflict
    case cherryPickConflict
    case detachedHead
    case branchAlreadyExists
    case untrackedFilesBlockingCheckout
    case authenticationFailed
    case repositoryNotFound
    case networkError
    case noUpstreamBranch
    case hookFailed
    case permissionDenied
    case unknown
    
    var icon: String {
        switch self {
        case .nothingToCommit: return "checkmark.circle"
        case .emptyCommitMessage: return "text.badge.xmark"
        case .pushRejected: return "arrow.up.circle.badge.xmark"
        case .mergeConflict: return "arrow.triangle.merge"
        case .rebaseConflict: return "arrow.triangle.swap"
        case .cherryPickConflict: return "cherry"
        case .detachedHead: return "link.badge.plus"
        case .branchAlreadyExists: return "doc.on.doc"
        case .untrackedFilesBlockingCheckout: return "exclamationmark.triangle"
        case .authenticationFailed: return "lock.trianglebadge.exclamationmark"
        case .repositoryNotFound: return "server.rack"
        case .networkError: return "wifi.exclamationmark"
        case .noUpstreamBranch: return "arrow.up.right.circle"
        case .hookFailed: return "terminal.fill"
        case .permissionDenied: return "hand.raised"
        case .unknown: return "xmark.octagon"
        }
    }
    
    var color: Color {
        switch self {
        case .nothingToCommit, .noUpstreamBranch: return .blue
        case .emptyCommitMessage, .branchAlreadyExists, .detachedHead: return .orange
        case .pushRejected, .authenticationFailed, .repositoryNotFound, .networkError, .hookFailed, .permissionDenied, .unknown: return .red
        case .mergeConflict, .rebaseConflict, .cherryPickConflict, .untrackedFilesBlockingCheckout: return .yellow
        }
    }
}

struct GitAnalyzedError: Identifiable, Equatable, Error, LocalizedError {
    let id = UUID()
    let type: GitErrorType
    let title: String
    let description: String
    let reason: String?
    let suggestedFix: String?
    let primaryAction: GitRecoveryAction?
    let secondaryAction: GitRecoveryAction?
    let rawOutput: String
    
    var errorDescription: String? {
        return description
    }
    
    // For Equatable
    static func == (lhs: GitAnalyzedError, rhs: GitAnalyzedError) -> Bool {
        lhs.id == rhs.id
    }
}
