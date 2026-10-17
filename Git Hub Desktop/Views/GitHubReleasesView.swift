import SwiftUI
import AppKit
import MarkdownUI

struct GitHubReleasesView: View {
    let repo: Repo

    @State private var releases: [GitHubRelease] = []
    @State private var selectedTag: String?
    @State private var selectedRelease: GitHubRelease?
    @State private var isLoading = false
    @State private var isLoadingDetails = false
    @State private var errorMessage: String?
    @State private var detailsError: String?
    @State private var showingCreateRelease = false
    @State private var releaseToEdit: GitHubRelease?
    @State private var releaseToDelete: GitHubRelease?

    private let service = GitHubCLIService()

    init(repo: Repo) {
        self.repo = repo
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                Text("Releases")
                    .appFont(.title2)
                    .fontWeight(.semibold)
                Text(repo.name)
                    .appFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                ProminentBaseButton(title: "New Release", image: Image(systemName: "plus")) {
                    showingCreateRelease = true
                }
                BaseButton(title: "Refresh", image: Image(systemName: "arrow.clockwise")) {
                    Task { await loadReleases() }
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            if isLoading && releases.isEmpty {
                ProgressView("Loading releases…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, releases.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load Releases", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                        .textSelection(.enabled)
                } actions: {
                    BaseButton(title: "Try Again") {
                        Task { await loadReleases() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if releases.isEmpty {
                ContentUnavailableView(
                    "No Releases Yet",
                    systemImage: "tag",
                    description: Text("Published and draft releases for this repository will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    releaseList
                        .frame(minWidth: 240, idealWidth: 290, maxWidth: 360)
                    releaseDetails
                        .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            await loadReleases()
        }
        .task(id: selectedTag) {
            guard let selectedTag else { return }
            await loadDetails(for: selectedTag)
        }
        .sheet(isPresented: $showingCreateRelease) {
            GitHubReleaseEditorSheet(repoPath: repo.path, currentBranch: repo.currentBranch) { tag in
                await loadReleases(selecting: tag)
            }
        }
        .sheet(item: $releaseToEdit) { release in
            GitHubReleaseEditorSheet(
                repoPath: repo.path,
                currentBranch: repo.currentBranch,
                release: release
            ) { tag in
                await loadReleases(selecting: tag)
                await loadDetails(for: tag)
            }
        }
        .confirmationDialog(
            "Delete Release?",
            isPresented: Binding(
                get: { releaseToDelete != nil },
                set: { if !$0 { releaseToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: releaseToDelete
        ) { release in
            BaseButton(title: "Delete Release", textTint: .red) {
                Task { await deleteRelease(release) }
            }
            BaseButton(title: "Cancel", keyboardShortcut: .cancelAction) {
                releaseToDelete = nil
            }
        } message: { release in
            Text("Delete release \(release.tagName)? The Git tag will be kept.")
        }
    }

    private var releaseList: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 8)
            }

            List(selection: $selectedTag) {
                ForEach(releases) { release in
                    VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(release.displayTitle)
                                    .appFont(.headline)
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                if isLatest(release) {
                                    releaseBadge("Latest", color: .green)
                                }
                            }
                            Text(release.tagName)
                                .appFont(.caption, design: .monospaced)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                if release.isDraft == true {
                                    releaseBadge("Draft", color: .orange)
                                }
                                if release.isPrerelease == true {
                                    releaseBadge("Pre-release", color: .purple)
                                }
                                if let date = release.displayDate {
                                    Text(date)
                                        .appFont(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTag = release.tagName
                    }
                    .tag(release.tagName)
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var releaseDetails: some View {
        if isLoadingDetails {
            ProgressView("Loading release details…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let release = selectedRelease {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(release.displayTitle)
                                    .appFont(.title)
                                    .fontWeight(.bold)
                                Text(release.tagName)
                                    .appFont(.subheadline, design: .monospaced)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            BaseButton(title: "Edit", image: Image(systemName: "pencil")) {
                                releaseToEdit = release
                            }
                            BaseButton(title: "Delete", image: Image(systemName: "trash"), textTint: .red) {
                                releaseToDelete = release
                            }
                            if let url = release.url {
                                BaseButton(title: "View on GitHub", image: Image(systemName: "arrow.up.right.square")) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            if isLatest(release) {
                                releaseBadge("Latest", color: .green)
                            }
                            if release.isDraft == true {
                                releaseBadge("Draft", color: .orange)
                            }
                            if release.isPrerelease == true {
                                releaseBadge("Pre-release", color: .purple)
                            } else if release.isDraft != true {
                                releaseBadge("Stable", color: .blue)
                            }
                            if release.isImmutable == true {
                                releaseBadge("Immutable", color: .secondary)
                            }
                        }

                        HStack(spacing: 14) {
                            if let date = release.displayDate {
                                Label("Published \(date)", systemImage: "calendar")
                            }
                            if let author = release.author?.displayName {
                                Label(author, systemImage: "person")
                            }
                        }
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let detailsError {
                        Label(detailsError, systemImage: "exclamationmark.triangle")
                            .appFont(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let body = release.body, !body.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Release Notes")
                                .appFont(.headline)
                            Markdown(body)
                                .markdownTheme(.docC)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if let assets = release.assets, !assets.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Assets")
                                    .appFont(.headline)
                                Text("\(assets.count)")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12), in: Capsule())
                            }

                            ForEach(assets) { asset in
                                HStack(spacing: 10) {
                                    Image(systemName: "shippingbox")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(asset.name)
                                            .appFont(.subheadline)
                                            .lineLimit(1)
                                            .textSelection(.enabled)
                                        HStack(spacing: 8) {
                                            if let size = asset.formattedSize {
                                                Text(size)
                                            }
                                            if let count = asset.downloadCount {
                                                Text("\(count.formatted()) downloads")
                                            }
                                            if let contentType = asset.contentType {
                                                Text(contentType)
                                                    .lineLimit(1)
                                            }
                                        }
                                        .appFont(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if let url = asset.browserDownloadUrl {
                                        BaseButton(title: "Download", image: Image(systemName: "arrow.down.circle")) {
                                            NSWorkspace.shared.open(url)
                                        }
                                        .help("Download \(asset.name)")
                                    }
                                }
                                .padding(10)
                                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    if release.tarballUrl != nil || release.zipballUrl != nil {
                        Divider()
                        HStack(spacing: 12) {
                            if let url = release.zipballUrl {
                                Link(destination: url) {
                                    Label("Source ZIP", systemImage: "doc.zipper")
                                }
                            }
                            if let url = release.tarballUrl {
                                Link(destination: url) {
                                    Label("Source tarball", systemImage: "doc.zipper")
                                }
                            }
                        }
                        .appFont(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
        } else {
            ContentUnavailableView(
                "Select a Release",
                systemImage: "tag",
                description: Text("Choose a release to view its notes, assets, and publishing details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func releaseBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .appFont(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func isLatest(_ release: GitHubRelease) -> Bool {
        release.isLatest ?? releases.first(where: { $0.tagName == release.tagName })?.isLatest ?? false
    }

    private func loadReleases(selecting tagToSelect: String? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await service.listReleases(in: repo.path)
            guard result.isSuccess else {
                errorMessage = result.output.isEmpty ? "GitHub CLI could not list releases." : result.output
                return
            }
            releases = try JSONDecoder().decode([GitHubRelease].self, from: Data(result.output.utf8))
            if let tagToSelect, releases.contains(where: { $0.tagName == tagToSelect }) {
                selectedTag = tagToSelect
            }
            if let selectedTag, !releases.contains(where: { $0.tagName == selectedTag }) {
                self.selectedTag = nil
                selectedRelease = nil
            }
            if selectedTag == nil {
                selectedTag = releases.first?.tagName
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadDetails(for tag: String) async {
        isLoadingDetails = true
        detailsError = nil
        selectedRelease = releases.first { $0.tagName == tag }
        defer { isLoadingDetails = false }

        do {
            let result = try await service.releaseDetails(tag: tag, in: repo.path)
            guard result.isSuccess else {
                detailsError = result.output.isEmpty ? "Could not load the full release details." : result.output
                return
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: Data(result.output.utf8))
            guard selectedTag == tag else { return }
            selectedRelease = release
        } catch {
            detailsError = error.localizedDescription
        }
    }

    private func deleteRelease(_ release: GitHubRelease) async {
        releaseToDelete = nil
        detailsError = nil

        do {
            let result = try await service.deleteRelease(tag: release.tagName, in: repo.path)
            guard result.isSuccess else {
                detailsError = result.output.isEmpty ? "GitHub CLI could not delete the release." : result.output
                return
            }
            selectedRelease = nil
            selectedTag = nil
            await loadReleases()
        } catch {
            detailsError = error.localizedDescription
        }
    }
}

private struct GitHubReleaseEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var tag: String
    @State private var title: String
    @State private var notes: String
    @State private var targetBranch = ""
    @State private var branches: [String] = []
    @State private var isLoadingBranches = false
    @State private var generateNotes = false
    @State private var isDraft = false
    @State private var isPrerelease = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    let repoPath: String
    let currentBranch: String
    let release: GitHubRelease?
    let onSaved: (String) async -> Void

    private let service = GitHubCLIService()
    private let gitService = GitService()

    init(
        repoPath: String,
        currentBranch: String,
        release: GitHubRelease? = nil,
        onSaved: @escaping (String) async -> Void
    ) {
        self.repoPath = repoPath
        self.currentBranch = currentBranch
        self.release = release
        self.onSaved = onSaved
        _tag = State(initialValue: release?.tagName ?? "")
        _title = State(initialValue: release?.displayTitle ?? "")
        _notes = State(initialValue: release?.body ?? "")
        _targetBranch = State(initialValue: release?.targetCommitish ?? currentBranch)
        _isDraft = State(initialValue: release?.isDraft ?? false)
        _isPrerelease = State(initialValue: release?.isPrerelease ?? false)
    }

    private var modalSize: CGSize {
        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        return CGSize(width: screenSize.width * 0.8, height: screenSize.height * 0.8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(release == nil ? "Create a Release" : "Edit Release")
                    .font(.title2.weight(.semibold))
                Text(release == nil
                     ? "Create a GitHub release from a tag in this repository."
                     : "Update the title, notes, target branch, or release status.")
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tag")
                        .font(.headline)
                    TextField("e.g. v1.2.0", text: $tag)
                        .textFieldStyle(.roundedBorder)
                        .disabled(release != nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Release title")
                        .font(.headline)
                    TextField("Optional", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(alignment: .center, spacing: 18) {
                Picker("Target branch", selection: $targetBranch) {
                    ForEach(branches, id: \.self) { branch in
                        Text(branch).tag(branch)
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)
                .disabled(isLoadingBranches || branches.isEmpty)
                if isLoadingBranches {
                    ProgressView("Loading branches…")
                        .controlSize(.small)
                }
                Spacer()
                Toggle("Draft", isOn: $isDraft)
                    .toggleStyle(.checkbox)
                Toggle("Pre-release", isOn: $isPrerelease)
                    .toggleStyle(.checkbox)
            }

            if release == nil {
                Text("If this tag doesn’t exist, GitHub will create it from the selected branch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(generateNotes ? "Additional release notes (optional)" : "Release notes")
                        .font(.headline)
                    Spacer()
                    if release == nil {
                        Toggle("Generate automatically", isOn: $generateNotes)
                            .toggleStyle(.checkbox)
                    }
                }
                TextEditor(text: $notes)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    }
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                BaseButton(title: "Cancel", keyboardShortcut: .cancelAction) {
                    dismiss()
                }
                ProminentBaseButton(
                    title: isSaving ? "Saving…" : (release == nil ? "Create Release" : "Save Changes"),
                    image: isSaving ? nil : Image(systemName: release == nil ? "plus" : "checkmark")
                ) {
                    Task { await saveRelease() }
                }
                .disabled(
                    (release == nil && tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        || targetBranch.isEmpty
                        || isLoadingBranches
                        || isSaving
                )
            }
        }
        .padding(24)
        .frame(width: modalSize.width, height: modalSize.height)
        .task {
            await loadBranches()
        }
    }

    private func loadBranches() async {
        isLoadingBranches = true
        defer { isLoadingBranches = false }

        do {
            let result = try await gitService.run(
                ["for-each-ref", "--format=%(refname:short)", "refs/heads"],
                at: repoPath
            )
            guard result.isSuccess else {
                branches = [targetBranch].filter { !$0.isEmpty }
                return
            }
            branches = result.output
                .split(whereSeparator: \.isNewline)
                .map(String.init)
            if !targetBranch.isEmpty, !branches.contains(targetBranch) {
                branches.insert(targetBranch, at: 0)
            } else if targetBranch.isEmpty {
                targetBranch = branches.first ?? ""
            }
        } catch {
            branches = [targetBranch].filter { !$0.isEmpty }
        }
    }

    private func saveRelease() async {
        let releaseTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        let releaseTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let result: GitHubCLIResult
            if release != nil {
                result = try await service.editRelease(
                    tag: releaseTag,
                    title: releaseTitle,
                    notes: notes,
                    targetBranch: targetBranch,
                    isDraft: isDraft,
                    isPrerelease: isPrerelease,
                    in: repoPath
                )
            } else {
                result = try await service.createRelease(
                    tag: releaseTag,
                    title: releaseTitle,
                    notes: notes,
                    targetBranch: targetBranch,
                    generateNotes: generateNotes,
                    isDraft: isDraft,
                    isPrerelease: isPrerelease,
                    in: repoPath
                )
            }
            guard result.isSuccess else {
                errorMessage = result.output.isEmpty ? "GitHub CLI could not create the release." : result.output
                return
            }
            await onSaved(releaseTag)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

