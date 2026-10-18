import SwiftUI
import AppKit
import MarkdownUI

struct GitHubPullRequestsView: View {
    let repo: Repo
    @State private var pullRequests: [GitHubPullRequest] = []
    @State private var selectedNumber: Int?
    @State private var selectedPullRequest: GitHubPullRequest?
    @State private var stateFilter = "open"
    @State private var isLoading = false
    @State private var isLoadingDetails = false
    @State private var errorMessage: String?
    @State private var detailsError: String?
    @State private var showingCreateSheet = false
    @State private var pendingCreatedNumber: Int?

    private let service = GitHubCLIService()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(.pullRequest)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .frame(width: 20, height: 20)
                Text("Pull Requests")
                    .appFont(.title)
                    .fontWeight(.semibold)
                Spacer()
                statePicker
                .frame(maxWidth: 300)
                ProminentBaseButton(title: "New Pull Request", image: Image(.plus)) {
                    showingCreateSheet = true
                }
                BaseButton(title: "Refresh", image: Image(systemName: "arrow.clockwise")) {
                    Task { await loadPullRequests() }
                }
                .disabled(isLoading)
            }
            .frame(height: 56)
            .padding(.horizontal)

            Divider()

            if let errorMessage, !pullRequests.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .appFont(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }

            if isLoading && pullRequests.isEmpty {
                ProgressView("Loading pull requests…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, pullRequests.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load Pull Requests", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                        .textSelection(.enabled)
                } actions: {
                    BaseButton(title: "Try Again") {
                        Task { await loadPullRequests() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pullRequests.isEmpty {
                ContentUnavailableView {
                    Text("No Pull Requests")
                } description: {
                    Text("Pull requests for this repository will appear here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    pullRequestList
                        .frame(minWidth: 280, idealWidth: 360, maxWidth: 440)
                    pullRequestDetails
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: stateFilter) {
            await loadPullRequests(selecting: pendingCreatedNumber)
            pendingCreatedNumber = nil
        }
        .animation(nil, value: stateFilter)
        .task(id: selectedNumber) {
            guard let selectedNumber else { return }
            await loadDetails(for: selectedNumber)
        }
        .sheet(isPresented: $showingCreateSheet) {
            GitHubPullRequestEditorSheet(repo: repo) { createdNumber in
                if stateFilter == "open" {
                    await loadPullRequests(selecting: createdNumber)
                } else {
                    pendingCreatedNumber = createdNumber
                    stateFilter = "open"
                }
            }
        }
    }

    private var pullRequestList: some View {
        List(selection: $selectedNumber) {
                ForEach(pullRequests) { pullRequest in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center, spacing: 6) {
                            Text("#\(pullRequest.number)")
                                .appFont(.title2)
                                .fontWeight(.bold)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(.secondary.opacity(0.2), in: Capsule())
                            Text(pullRequest.title)
                                .appFont(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(3)
                        }
                        Divider()
                        HStack(spacing: 6) {
                            Label(pullRequest.displayState, systemImage: stateIcon(for: pullRequest))
                                .foregroundStyle(stateColor(for: pullRequest))
                            if pullRequest.isDraft {
                                Text("Draft")
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(pullRequest.headRefName) → \(pullRequest.baseRefName)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .appFont(.callout)
                        HStack(spacing: 8) {
                            if let author = pullRequest.author?.login {
                                Text("by @\(author)")
                            }
                            if let date = pullRequest.displayDate {
                                Text(date)
                            }
                        }
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .background {
                        if selectedNumber != pullRequest.number {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.07))
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture { selectedNumber = pullRequest.number }
                    .tag(pullRequest.number)
                }
        }
        .listStyle(.inset)
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        Color.secondary
                            .opacity(0.2)
                    }
            }
        }
    }

    @ViewBuilder
    private var statePicker: some View {
        if #available(macOS 27.0, *) {
            statePickerContent
                .pickerStyle(.tabs)
        } else {
            statePickerContent
                .pickerStyle(.segmented)
        }
    }

    private var statePickerContent: some View {
        Picker("", selection: $stateFilter) {
            Text("Open").tag("open")
            Text("Closed").tag("closed")
            Text("Merged").tag("merged")
            Text("All").tag("all")
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private var pullRequestDetails: some View {
        if isLoadingDetails && selectedPullRequest == nil {
            ProgressView("Loading pull request…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let pullRequest = selectedPullRequest {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("#\(pullRequest.number)")
                                    .appFont(.title)
                                    .fontWeight(.bold)
                                    .underline()
                                    .foregroundStyle(.blue)
                                Text(pullRequest.title)
                                    .appFont(.title)
                                    .fontWeight(.bold)
                            }
                            Text("· \(pullRequest.displayState)")
                                .appFont(.subheadline)
                                .foregroundStyle(stateColor(for: pullRequest))
                        }
                        .textSelection(.enabled)
                        Spacer()
                        if let url = pullRequest.url {
                            BaseButton(title: "View on GitHub", image: Image(systemName: "arrow.up.right.square")) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.secondary)
                        Text(pullRequest.headRefName)
                            .fontDesign(.monospaced)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Text(pullRequest.baseRefName)
                            .fontDesign(.monospaced)
                    }
                    .appFont(.subheadline)
                    .textSelection(.enabled)

                    HStack(spacing: 14) {
                        if let author = pullRequest.author?.login {
                            Label(author, systemImage: "person")
                        }
                        if let date = pullRequest.displayDate {
                            Label(date, systemImage: "calendar")
                        }
                        if let review = pullRequest.reviewDecision, !review.isEmpty {
                            Label(reviewDisplayName(review), systemImage: "checkmark.seal")
                        }
                    }
                    .appFont(.caption)
                    .foregroundStyle(.secondary)

                    if let additions = pullRequest.additions, let deletions = pullRequest.deletions {
                        HStack(spacing: 12) {
                            Label("\(pullRequest.changedFiles ?? 0) files changed", systemImage: "doc.text")
                            Text("+\(additions)")
                                .foregroundStyle(.green)
                            Text("−\(deletions)")
                                .foregroundStyle(.red)
                        }
                        .appFont(.caption)
                    }

                    if let detailsError {
                        Label(detailsError, systemImage: "exclamationmark.triangle")
                            .appFont(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let body = pullRequest.body, !body.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .appFont(.headline)
                            Markdown(renderableMarkdown(body))
                                .markdownTheme(.docC)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let commits = pullRequest.commits, !commits.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Commits (\(commits.count))")
                                .appFont(.headline)
                            ForEach(commits) { commit in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(String(commit.oid.prefix(7)))
                                        .appFont(.caption, design: .monospaced)
                                        .foregroundStyle(.secondary)
                                    Text(commit.messageHeadline)
                                        .appFont(.subheadline)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
        } else {
            ContentUnavailableView {
                Label {
                    Text("Select a Pull Request")
                } icon: {
                    Image(.pullRequest)
                }
            } description: {
                Text("Choose a pull request to view its description and details.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadPullRequests(selecting number: Int? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.listPullRequests(state: stateFilter, in: repo.path)
            guard result.isSuccess else {
                throw GitHubPullRequestError.cli(result.output)
            }
            let decoded = try JSONDecoder().decode([GitHubPullRequest].self, from: Data(result.output.utf8))
            pullRequests = decoded
            if let number, decoded.contains(where: { $0.number == number }) {
                selectedNumber = number
            } else if let selectedNumber, decoded.contains(where: { $0.number == selectedNumber }) {
                self.selectedNumber = selectedNumber
            } else {
                selectedNumber = decoded.first?.number
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renderableMarkdown(_ body: String) -> String {
        body
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</?p>"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"</?sup>"#, with: "", options: .regularExpression)
    }

    private func loadDetails(for number: Int) async {
        isLoadingDetails = true
        detailsError = nil
        defer { isLoadingDetails = false }
        do {
            let result = try await service.pullRequestDetails(number: number, in: repo.path)
            guard result.isSuccess else {
                throw GitHubPullRequestError.cli(result.output)
            }
            selectedPullRequest = try JSONDecoder().decode(GitHubPullRequest.self, from: Data(result.output.utf8))
        } catch {
            detailsError = error.localizedDescription
        }
    }

    private func stateIcon(for pullRequest: GitHubPullRequest) -> String {
        if pullRequest.mergedAt != nil { return "arrow.triangle.merge" }
        return pullRequest.state.lowercased() == "open" ? "arrow.triangle.branch" : "xmark.circle"
    }

    private func stateColor(for pullRequest: GitHubPullRequest) -> Color {
        if pullRequest.mergedAt != nil { return .purple }
        return pullRequest.state.lowercased() == "open" ? .green : .secondary
    }

    private func reviewDisplayName(_ decision: String) -> String {
        decision.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct GitHubPullRequestEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let repo: Repo
    let onCreated: (Int?) async -> Void
    @State private var title = ""
    @State private var bodyText = ""
    @State private var baseBranch = ""
    @State private var isDraft = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = GitHubCLIService()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create Pull Request")
                    .appFont(.title2)
                    .fontWeight(.semibold)
                Text("Open a pull request from the current branch.")
                    .foregroundStyle(.secondary)
            }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Base")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Base branch", text: $baseBranch)
                        .textFieldStyle(.roundedBorder)
                }
                Image(systemName: "arrow.left")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Compare")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    Text(repo.currentBranch)
                        .fontDesign(.monospaced)
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            TextEditor(text: $bodyText)
                .frame(minHeight: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                }

            Toggle("Create as draft", isOn: $isDraft)
                .toggleStyle(.checkbox)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                BaseButton(title: "Cancel", keyboardShortcut: .cancelAction) { dismiss() }
                ProminentBaseButton(title: isSaving ? "Creating…" : "Create Pull Request", image: Image(systemName: "arrow.up.right")) {
                    Task { await createPullRequest() }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || baseBranch.isEmpty || isSaving)
            }
        }
        .padding(24)
        .frame(width: 720, height: 620)
        .task { await loadDefaultBranch() }
    }

    private func loadDefaultBranch() async {
        do {
            let result = try await service.defaultBranch(in: repo.path)
            if result.isSuccess {
                baseBranch = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createPullRequest() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let result = try await service.createPullRequest(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                body: bodyText,
                baseBranch: baseBranch.trimmingCharacters(in: .whitespacesAndNewlines),
                headBranch: repo.currentBranch,
                isDraft: isDraft,
                in: repo.path
            )
            guard result.isSuccess else { throw GitHubPullRequestError.cli(result.output) }
            let number = URL(string: result.output.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { Int($0.lastPathComponent) }
            await onCreated(number)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum GitHubPullRequestError: LocalizedError {
    case cli(String)

    var errorDescription: String? {
        switch self {
        case .cli(let message):
            return message.isEmpty ? "GitHub CLI could not complete the pull request request." : message
        }
    }
}
