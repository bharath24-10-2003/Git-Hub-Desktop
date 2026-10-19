import SwiftUI
import AppKit
import MarkdownUI

struct GitHubPullRequestsView: View {
    let repo: Repo
    @State private var pullRequests: [GitHubPullRequest] = []
    @State private var selectedNumber: Int?
    @State private var selectedPullRequest: GitHubPullRequest?
    @State private var detailTab: PullRequestDetailTab = .conversation
    @State private var selectedFilePath: String?
    @State private var fileDiffs: [String: FileDiff] = [:]
    @State private var reviewComments: [GitHubPullRequestReviewComment] = []
    @State private var reviewCommentsError: String?
    @State private var loadedDiffPullRequestNumber: Int?
    @State private var isLoadingFileDiff = false
    @State private var fileDiffError: String?
    @State private var stateFilter = "open"
    @State private var isLoading = false
    @State private var isLoadingDetails = false
    @State private var errorMessage: String?
    @State private var detailsError: String?
    @State private var showingCreateSheet = false
    @State private var pendingCreatedNumber: Int?
    @State private var commentText = ""
    @State private var replyingTo: PullRequestConversationEntry?
    @State private var isSubmittingComment = false
    @State private var isUpdatingPullRequest = false
    @State private var pullRequestActionError: String?
    @State private var showingReviewerSheet = false
    @State private var reviewerSearchText = ""
    @State private var reviewerSearchResults: [GitHubReviewer] = []
    @State private var isSearchingReviewers = false
    @State private var reviewerSearchError: String?
    @State private var isAddingReviewer = false

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
            if detailTab == .fileChanges {
                await loadFileDiff(for: selectedNumber)
            }
        }
        .onChange(of: detailTab) { _, newValue in
            guard newValue == .fileChanges, let selectedNumber else { return }
            Task { await loadFileDiff(for: selectedNumber) }
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
        .sheet(isPresented: $showingReviewerSheet) {
            reviewerSearchSheet
        }
        .alert(
            "Pull Request Action Failed",
            isPresented: Binding(
                get: { pullRequestActionError != nil },
                set: { if !$0 { pullRequestActionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { pullRequestActionError = nil }
        } message: {
            Text(pullRequestActionError ?? "")
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
        } else if let detailsError, selectedPullRequest == nil {
            ContentUnavailableView {
                Label("Couldn't Load Pull Request", systemImage: "exclamationmark.triangle")
            } description: {
                Text(detailsError)
                    .textSelection(.enabled)
            } actions: {
                if let selectedNumber {
                    BaseButton(title: "Try Again") {
                        Task { await loadDetails(for: selectedNumber) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let pullRequest = selectedPullRequest {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("#\(pullRequest.number)")
                                    .appFont(.title)
                                    .fontWeight(.bold)
                                    .underline()
                                    .foregroundStyle(.blue)
                                Text(pullRequest.title)
                                    .appFont(.title)
                                    .fontWeight(.bold)
                            }
                            Text(pullRequest.displayState)
                                .appFont(.subheadline)
                                .foregroundStyle(stateColor(for: pullRequest))
                        }
                        .textSelection(.enabled)
                        Spacer(minLength: 12)
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
                        if let additions = pullRequest.additions, let deletions = pullRequest.deletions {
                            Label("\(pullRequest.changedFiles ?? 0) files changed", systemImage: "doc.text")
                            Text("+\(additions)")
                                .foregroundStyle(.green)
                            Text("−\(deletions)")
                                .foregroundStyle(.red)
                        }
                    }
                    .appFont(.caption)
                    .foregroundStyle(.secondary)

                    if let detailsError {
                        Label(detailsError, systemImage: "exclamationmark.triangle")
                            .appFont(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)

                TabView(selection: $detailTab) {
                    conversationTab(for: pullRequest)
                        .tabItem {
                            Label("Conversation", systemImage: "text.bubble")
                        }
                        .tag(PullRequestDetailTab.conversation)

                    commitsTab(for: pullRequest)
                        .tabItem {
                            Label("Commits (\(pullRequest.commits?.count ?? 0))", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .tag(PullRequestDetailTab.commits)

                    fileChangesTab(for: pullRequest)
                        .tabItem {
                            Label("Files changed (\(pullRequest.changedFiles ?? pullRequest.files?.count ?? 0))", systemImage: "doc.text")
                        }
                        .tag(PullRequestDetailTab.fileChanges)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func conversationTab(for pullRequest: GitHubPullRequest) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    conversationCard(
                        author: pullRequest.author?.login ?? "Unknown author",
                        date: pullRequest.displayDate,
                        title: "Description",
                        body: pullRequest.body
                    )

                    ForEach(conversationEntries(for: pullRequest)) { entry in
                        conversationCard(
                            author: entry.author,
                            date: entry.date,
                            title: entry.title,
                            body: entry.body,
                            url: entry.url,
                            replyEntry: entry
                        )
                        .padding(.leading, entry.inReplyToID == nil ? 0 : 24)
                    }

                    if (pullRequest.comments ?? []).isEmpty && (pullRequest.reviews ?? []).isEmpty && reviewComments.isEmpty {
                        Label("No comments or reviews yet", systemImage: "text.bubble")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                    }
                    if let reviewCommentsError {
                        Label("Review comments unavailable: \(reviewCommentsError)", systemImage: "exclamationmark.triangle")
                            .appFont(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                if let replyingTo {
                    HStack {
                        Label("Replying to @\(replyingTo.author)", systemImage: "arrowshape.turn.up.left")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BaseButton(title: "Cancel Reply") {
                            self.replyingTo = nil
                            commentText = ""
                        }
                    }
                }

                TextEditor(text: $commentText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 80)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
                    .overlay(alignment: .topLeading) {
                        if commentText.isEmpty {
                            Text("Leave a comment…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 8) {
                    BaseButton(title: "Add reviewers", image: Image(systemName: "person.badge.plus")) {
                        reviewerSearchText = ""
                        reviewerSearchResults = []
                        reviewerSearchError = nil
                        showingReviewerSheet = true
                    }
                    .disabled(isUpdatingPullRequest)

                    Spacer()

                    BaseButton(title: "Close pull request", image: Image(systemName: "xmark.circle")) {
                        Task { await closePullRequest(pullRequest) }
                    }
                    .disabled(isUpdatingPullRequest || pullRequest.state.lowercased() != "open")

                    Menu {
                        Button("Create a merge commit") {
                            Task { await mergePullRequest(pullRequest, method: "merge") }
                        }
                        Button("Rebase and merge") {
                            Task { await mergePullRequest(pullRequest, method: "rebase") }
                        }
                        Button("Squash and merge") {
                            Task { await mergePullRequest(pullRequest, method: "squash") }
                        }
                    } label: {
                        Label(isUpdatingPullRequest ? "Merging…" : "Merge pull request", systemImage: "arrow.triangle.merge")
                            .appFont(.subheadline, weight: .medium)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                    }
                    .menuStyle(.borderedButton)
                    .clipShape(Capsule())
                    .disabled(isUpdatingPullRequest || pullRequest.state.lowercased() != "open")

                    ProminentBaseButton(title: isSubmittingComment ? "Commenting…" : "Comment", image: Image(systemName: "paperplane")) {
                        Task { await submitComment(for: pullRequest) }
                    }
                    .disabled(isSubmittingComment || commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .background(.bar)
        }
    }

    private func conversationCard(
        author: String,
        date: String?,
        title: String,
        body: String?,
        url: URL? = nil,
        replyEntry: PullRequestConversationEntry? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(.secondary)
                Text(author)
                    .fontWeight(.semibold)
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                if let date {
                    Text(date)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
                if let url {
                    BaseButton(title: "View", image: Image(systemName: "arrow.up.right.square")) {
                        NSWorkspace.shared.open(url)
                    }
                }
                if let replyEntry, replyEntry.inReplyToID == nil {
                    BaseButton(title: "Reply", image: Image(systemName: "arrowshape.turn.up.left")) {
                        replyingTo = replyEntry
                        commentText = replyEntry.reviewCommentID == nil ? "@\(replyEntry.author) " : ""
                    }
                }
            }

            if let body, !body.isEmpty {
                Divider()
                Markdown(renderableMarkdown(body))
                    .markdownTheme(.docC)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func conversationEntries(for pullRequest: GitHubPullRequest) -> [PullRequestConversationEntry] {
        let comments = (pullRequest.comments ?? []).map { comment in
            PullRequestConversationEntry(
                id: "comment-\(comment.id)",
                author: comment.author?.login ?? "Unknown author",
                date: comment.createdAt,
                title: "commented",
                body: comment.body,
                url: comment.url
            )
        }
        let reviews = (pullRequest.reviews ?? []).map { review in
            PullRequestConversationEntry(
                id: "review-\(review.id)",
                author: review.author?.login ?? "Unknown reviewer",
                date: review.submittedAt,
                title: "reviewed · \(reviewDisplayName(review.state))",
                body: review.body,
                url: review.url
            )
        }
        let reviewComments = reviewComments.map { comment in
            PullRequestConversationEntry(
                id: "review-comment-\(comment.id)",
                author: comment.user?.login ?? "Unknown reviewer",
                date: comment.createdAt,
                title: comment.path.map { "commented on \($0)" } ?? "commented on a file",
                body: comment.body,
                url: comment.htmlURL,
                reviewCommentID: comment.id,
                inReplyToID: comment.inReplyToID
            )
        }
        return (comments + reviews + reviewComments).sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    private var reviewerSearchSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Reviewers")
                .appFont(.title2)
                .fontWeight(.semibold)

            TextField("Search GitHub users", text: $reviewerSearchText)
                .textFieldStyle(.roundedBorder)

            if isSearchingReviewers {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let reviewerSearchError {
                ContentUnavailableView("Search Failed", systemImage: "exclamationmark.triangle", description: Text(reviewerSearchError))
            } else if reviewerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Search for a reviewer", systemImage: "person.crop.circle.badge.plus", description: Text("Enter a GitHub username to find and request a review."))
            } else if reviewerSearchResults.isEmpty {
                ContentUnavailableView("No Users Found", systemImage: "person.crop.circle", description: Text("Try another username."))
            } else {
                List(reviewerSearchResults) { reviewer in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(reviewer.login)
                                .fontWeight(.medium)
                            Text("@\(reviewer.login)")
                                .appFont(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        BaseButton(title: isAddingReviewer ? "Adding…" : "Request review", image: Image(systemName: "person.badge.plus")) {
                            guard let selectedPullRequest else { return }
                            Task { await addReviewer(reviewer, to: selectedPullRequest) }
                        }
                        .disabled(isAddingReviewer)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }

            HStack {
                Spacer()
                BaseButton(title: "Done", keyboardShortcut: .cancelAction) {
                    showingReviewerSheet = false
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 520)
        .task(id: reviewerSearchText) {
            let query = reviewerSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard query.count >= 2 else {
                reviewerSearchResults = []
                reviewerSearchError = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await searchReviewers(query)
        }
    }

    private func searchReviewers(_ query: String) async {
        isSearchingReviewers = true
        reviewerSearchError = nil
        defer { isSearchingReviewers = false }
        do {
            let result = try await service.searchReviewers(query: query, in: repo.path)
            guard result.isSuccess else { throw GitHubPullRequestError.cli(result.output) }
            reviewerSearchResults = try JSONDecoder().decode([GitHubReviewer].self, from: Data(result.output.utf8))
        } catch {
            reviewerSearchError = error.localizedDescription
            reviewerSearchResults = []
        }
    }

    private func addReviewer(_ reviewer: GitHubReviewer, to pullRequest: GitHubPullRequest) async {
        isAddingReviewer = true
        defer { isAddingReviewer = false }
        do {
            let result = try await service.addReviewer(reviewer.login, toPullRequest: pullRequest.number, in: repo.path)
            guard result.isSuccess else { throw GitHubPullRequestError.cli(result.output) }
            showingReviewerSheet = false
            await loadDetails(for: pullRequest.number)
        } catch {
            reviewerSearchError = error.localizedDescription
        }
    }

    private func submitComment(for pullRequest: GitHubPullRequest) async {
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            let result: GitHubCLIResult
            if let commentID = replyingTo?.reviewCommentID {
                result = try await service.replyToPullRequestReviewComment(
                    number: pullRequest.number,
                    commentID: commentID,
                    body: body,
                    in: repo.path
                )
            } else {
                result = try await service.commentOnPullRequest(number: pullRequest.number, body: body, in: repo.path)
            }
            guard result.isSuccess else { throw GitHubPullRequestError.cli(result.output) }
            commentText = ""
            replyingTo = nil
            await loadDetails(for: pullRequest.number)
        } catch {
            pullRequestActionError = error.localizedDescription
        }
    }

    private func closePullRequest(_ pullRequest: GitHubPullRequest) async {
        await updatePullRequest {
            try await service.closePullRequest(number: pullRequest.number, in: repo.path)
        }
    }

    private func mergePullRequest(_ pullRequest: GitHubPullRequest, method: String) async {
        await updatePullRequest {
            try await service.mergePullRequest(number: pullRequest.number, method: method, in: repo.path)
        }
    }

    private func updatePullRequest(
        operation: () async throws -> GitHubCLIResult
    ) async {
        isUpdatingPullRequest = true
        defer { isUpdatingPullRequest = false }
        do {
            let result = try await operation()
            guard result.isSuccess else { throw GitHubPullRequestError.cli(result.output) }
            selectedPullRequest = nil
            await loadPullRequests()
        } catch {
            pullRequestActionError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func commitsTab(for pullRequest: GitHubPullRequest) -> some View {
        let commits = pullRequest.commits ?? []
        if commits.isEmpty {
            ContentUnavailableView("No Commits", systemImage: "point.3.connected.trianglepath.dotted", description: Text("No commits are available for this pull request."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                if index < commits.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 1, height: 32)
                                }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(commit.messageHeadline)
                                    .fontWeight(.medium)
                                    .textSelection(.enabled)
                                HStack {
                                    if let url = commitURL(for: commit, pullRequest: pullRequest) {
                                        Link(String(commit.oid.prefix(7)), destination: url)
                                            .font(.system(.caption, design: .monospaced))
                                    } else {
                                        Text(String(commit.oid.prefix(7)))
                                            .appFont(.caption, design: .monospaced)
                                    }
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, index < commits.count - 1 ? 18 : 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
    }

    private func commitURL(for commit: GitHubPullRequestCommit, pullRequest: GitHubPullRequest) -> URL? {
        guard let url = pullRequest.url else { return nil }
        return URL(string: "\(url.absoluteString)/commits/\(commit.oid)")
    }

    @ViewBuilder
    private func fileChangesTab(for pullRequest: GitHubPullRequest) -> some View {
        let files = pullRequest.files ?? []
        if files.isEmpty {
            ContentUnavailableView(
                "No File Changes",
                systemImage: "doc.text",
                description: Text("GitHub did not return a changed-file list for this pull request.")
            )
        } else {
            HSplitView {
                List(files, selection: $selectedFilePath) { file in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(file.path)
                            .lineLimit(2)
                            .textSelection(.enabled)
                        HStack(spacing: 8) {
                            Text(file.changeType.capitalized)
                            Text("+\(file.additions)")
                                .foregroundStyle(.green)
                            Text("−\(file.deletions)")
                                .foregroundStyle(.red)
                        }
                        .appFont(.caption)
                    }
                    .padding(.vertical, 5)
                    .tag(file.path)
                }
                .listStyle(.inset)
                .frame(minWidth: 200, idealWidth: 260, maxWidth: 340)

                fileDiffDetail(for: pullRequest, files: files)
                    .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear {
                if selectedFilePath == nil || !files.contains(where: { $0.path == selectedFilePath }) {
                    selectedFilePath = files.first?.path
                }
            }
        }
    }

    @ViewBuilder
    private func fileDiffDetail(for pullRequest: GitHubPullRequest, files: [GitHubPullRequestFile]) -> some View {
        if isLoadingFileDiff {
            ProgressView("Loading file changes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let fileDiffError {
            ContentUnavailableView {
                Label("Couldn't Load File Changes", systemImage: "exclamationmark.triangle")
            } description: {
                Text(fileDiffError)
                    .textSelection(.enabled)
            } actions: {
                BaseButton(title: "Try Again") {
                    Task { await loadFileDiff(for: pullRequest.number, force: true) }
                }
            }
        } else if let selectedFilePath,
                  let file = files.first(where: { $0.path == selectedFilePath }),
                  let diff = fileDiffs[file.path] {
            DiffRendererView(
                diff: diff,
                file: ChangedFile(path: file.path, status: file.changeType.capitalized, isStaged: false)
            )
            .padding(10)
        } else if let selectedFilePath,
                  let file = files.first(where: { $0.path == selectedFilePath }) {
            ContentUnavailableView(
                "Diff Unavailable",
                systemImage: "doc.questionmark",
                description: Text("A text patch isn't available for \(file.path). It may be a binary file or GitHub did not return a patch for it.")
            )
        } else {
            ContentUnavailableView("Select a File", systemImage: "doc.text", description: Text("Choose a changed file to view its diff."))
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
        let withoutComments = body.replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)

        let withImages = replacingHTMLMatches(in: withoutComments, pattern: #"<img\b[^>]*>"#) { match, source in
            guard let range = Range(match.range, in: source) else { return "" }
            let tag = String(source[range])
            let alt = htmlAttribute("alt", in: tag) ?? "image"
            guard let imageSource = htmlAttribute("src", in: tag) else { return alt }
            return "![\(alt)](\(imageSource))"
        }
        let withoutSources = withImages.replacingOccurrences(of: #"<source\b[^>]*>"#, with: "", options: .regularExpression)
        var markdown = replacingHTMLMatches(in: withoutSources, pattern: #"<a\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\s\S]*?)</a>"#) { match, source in
            guard let urlRange = Range(match.range(at: 1), in: source),
                  let contentRange = Range(match.range(at: 2), in: source) else { return "" }
            let url = String(source[urlRange])
            let content = String(source[contentRange])
            return "[\(content)](\(url))"
        }
        markdown = markdown
            .replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</p\s*>"#, with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: #"<p\b[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"</?sup\b[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"</?picture\b[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<\s*(strong|b)\b[^>]*>"#, with: "**", options: .regularExpression)
            .replacingOccurrences(of: #"</\s*(strong|b)\s*>"#, with: "**", options: .regularExpression)
            .replacingOccurrences(of: #"<\s*(em|i)\b[^>]*>"#, with: "*", options: .regularExpression)
            .replacingOccurrences(of: #"</\s*(em|i)\s*>"#, with: "*", options: .regularExpression)
            .replacingOccurrences(of: #"<\s*li\b[^>]*>"#, with: "\n- ", options: .regularExpression)
            .replacingOccurrences(of: #"</\s*li\s*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"</?\s*(ul|ol)\b[^>]*>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"</?[A-Za-z][^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        return markdown
    }

    private func htmlAttribute(_ name: String, in tag: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*[\"']([^\"']*)[\"']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else { return nil }
        return String(tag[range])
    }

    private func replacingHTMLMatches(
        in source: String,
        pattern: String,
        transform: (NSTextCheckingResult, String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return source }
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        var result = source
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(match, source))
        }
        return result
    }

    private func loadDetails(for number: Int) async {
        isLoadingDetails = true
        detailsError = nil
        selectedPullRequest = nil
        selectedFilePath = nil
        fileDiffs = [:]
        reviewComments = []
        reviewCommentsError = nil
        loadedDiffPullRequestNumber = nil
        fileDiffError = nil
        defer { isLoadingDetails = false }
        do {
            let result = try await service.pullRequestDetails(number: number, in: repo.path)
            guard result.isSuccess else {
                throw GitHubPullRequestError.cli(result.output)
            }
            selectedPullRequest = try JSONDecoder().decode(GitHubPullRequest.self, from: Data(result.output.utf8))

            do {
                let commentsResult = try await service.pullRequestReviewComments(number: number, in: repo.path)
                guard commentsResult.isSuccess else { throw GitHubPullRequestError.cli(commentsResult.output) }
                let pages = try JSONDecoder().decode([[GitHubPullRequestReviewComment]].self, from: Data(commentsResult.output.utf8))
                reviewComments = pages.flatMap { $0 }
            } catch {
                reviewCommentsError = error.localizedDescription
            }
        } catch {
            detailsError = error.localizedDescription
        }
    }

    private func loadFileDiff(for number: Int, force: Bool = false) async {
        guard selectedPullRequest?.number == number else { return }
        guard force || loadedDiffPullRequestNumber != number else { return }
        guard !isLoadingFileDiff else { return }

        isLoadingFileDiff = true
        fileDiffError = nil
        defer { isLoadingFileDiff = false }
        do {
            let result = try await service.pullRequestDiff(number: number, in: repo.path)
            guard result.isSuccess else {
                throw GitHubPullRequestError.cli(result.output)
            }
            fileDiffs = parsePullRequestDiff(result.output)
            loadedDiffPullRequestNumber = number
            if let files = selectedPullRequest?.files,
               selectedFilePath == nil || !files.contains(where: { $0.path == selectedFilePath }) {
                selectedFilePath = files.first?.path
            }
        } catch {
            fileDiffError = error.localizedDescription
        }
    }

    private func parsePullRequestDiff(_ output: String) -> [String: FileDiff] {
        var parsedDiffs: [String: FileDiff] = [:]
        var path: String?
        var lines: [DiffLine] = []
        var oldLine: Int?
        var newLine: Int?
        var isNewFile = false
        var isDeletedFile = false
        var isBinary = false

        func saveCurrentFile() {
            guard let path else { return }
            parsedDiffs[path] = FileDiff(
                lines: lines,
                isNewFile: isNewFile,
                isDeletedFile: isDeletedFile,
                isBinary: isBinary
            )
            lines = []
            oldLine = nil
            newLine = nil
            isNewFile = false
            isDeletedFile = false
            isBinary = false
        }

        for line in output.components(separatedBy: .newlines) {
            if line.hasPrefix("diff --git ") {
                saveCurrentFile()
                path = pullRequestDiffPath(from: line)
                continue
            }
            guard path != nil else { continue }

            if line.hasPrefix("new file mode") {
                isNewFile = true
                continue
            }
            if line.hasPrefix("deleted file mode") {
                isDeletedFile = true
                continue
            }
            if line.hasPrefix("Binary files ") || line == "GIT binary patch" {
                isBinary = true
                continue
            }
            if line.hasPrefix("--- ") || line.hasPrefix("+++ ") || line.hasPrefix("index ") ||
                line.hasPrefix("similarity index ") || line.hasPrefix("rename from ") || line.hasPrefix("rename to ") {
                continue
            }
            if line.hasPrefix("@@") {
                lines.append(DiffLine(text: line, type: .hunkHeader, oldLineNumber: nil, newLineNumber: nil))
                let pattern = #"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let oldRange = Range(match.range(at: 1), in: line),
                   let newRange = Range(match.range(at: 2), in: line) {
                    oldLine = Int(line[oldRange])
                    newLine = Int(line[newRange])
                }
                continue
            }
            if line.hasPrefix("+") {
                lines.append(DiffLine(text: line, type: .added, oldLineNumber: nil, newLineNumber: newLine))
                if let current = newLine { newLine = current + 1 }
            } else if line.hasPrefix("-") {
                lines.append(DiffLine(text: line, type: .removed, oldLineNumber: oldLine, newLineNumber: nil))
                if let current = oldLine { oldLine = current + 1 }
            } else if line.hasPrefix(" ") {
                lines.append(DiffLine(text: line, type: .context, oldLineNumber: oldLine, newLineNumber: newLine))
                if let current = oldLine { oldLine = current + 1 }
                if let current = newLine { newLine = current + 1 }
            } else if line.hasPrefix("\\ No newline at end of file") {
                lines.append(DiffLine(text: line, type: .context, oldLineNumber: nil, newLineNumber: nil))
            }
        }
        saveCurrentFile()
        return parsedDiffs
    }

    private func pullRequestDiffPath(from header: String) -> String? {
        let patterns = [
            #"^diff --git a/.* b/(.*)$"#,
            #"^diff --git "a/.*" "b/(.*)"$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
                  let range = Range(match.range(at: 1), in: header) else { continue }
            return String(header[range])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .replacingOccurrences(of: #"\\([\\ ])"#, with: "$1", options: .regularExpression)
        }
        return nil
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

private enum PullRequestDetailTab: Hashable {
    case conversation
    case commits
    case fileChanges
}

private struct PullRequestConversationEntry: Identifiable {
    let id: String
    let author: String
    let date: String?
    let title: String
    let body: String?
    let url: URL?
    var reviewCommentID: Int? = nil
    var inReplyToID: Int? = nil
}
