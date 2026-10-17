import SwiftUI
import AppKit

private struct GitHubCLIAuthDetails {
    var host = "github.com"
    var account: String?
    var credentialStore: String?
    var isActive: Bool?
    var gitProtocol: String?
    var scopes: [String] = []

    init(output: String) {
        for line in output.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let loginRange = trimmedLine.range(of: "Logged in to "),
               let accountRange = trimmedLine[loginRange.upperBound...].range(of: " account ") {
                host = String(trimmedLine[loginRange.upperBound..<accountRange.lowerBound])
                let accountDetails = String(trimmedLine[accountRange.upperBound...])
                if let storeStart = accountDetails.range(of: " ("), accountDetails.hasSuffix(")") {
                    account = String(accountDetails[..<storeStart.lowerBound])
                    credentialStore = String(accountDetails[storeStart.upperBound..<accountDetails.index(before: accountDetails.endIndex)])
                } else {
                    account = accountDetails
                }
            } else if trimmedLine.hasPrefix("- Active account:") {
                isActive = trimmedLine.hasSuffix("true")
            } else if trimmedLine.hasPrefix("- Git operations protocol:") {
                gitProtocol = trimmedLine.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces)
            } else if trimmedLine.hasPrefix("- Token scopes:") {
                let rawScopes = trimmedLine.components(separatedBy: ":").dropFirst().joined(separator: ":")
                let quoteCharacters = CharacterSet(charactersIn: "'\"")
                scopes = rawScopes
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: quoteCharacters) }
                    .filter { !$0.isEmpty }
            }
        }
    }
}

struct GitHubCLIAuthSettingsView: View {
    @State private var isAuthenticated: Bool?
    @State private var isCLIAvailable = true
    @State private var isChecking = false
    @State private var isLoggingIn = false
    @State private var isLoggingOut = false
    @State private var showingLogoutConfirmation = false
    @State private var statusMessage = "Checking GitHub CLI authentication…"
    @State private var authDetails: GitHubCLIAuthDetails?

    private let loadsAuthStatusOnAppear: Bool
    private let service = GitHubCLIService()

    init() {
        loadsAuthStatusOnAppear = true
    }

    init(loadsAuthStatusOnAppear: Bool) {
        self.loadsAuthStatusOnAppear = loadsAuthStatusOnAppear
        _isAuthenticated = State(initialValue: false)
        _statusMessage = State(initialValue: "Not signed in to GitHub CLI")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: isAuthenticated == true ? "checkmark.circle.fill" : "person.crop.circle.badge.questionmark")
                    .foregroundStyle(isAuthenticated == true ? .green : .secondary)
                    .appFont(.title2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("GitHub CLI")
                        .appFont(.headline)
                    Text(statusMessage)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isChecking || isLoggingIn || isLoggingOut {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let authDetails {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Account")
                            .appFont(.subheadline)
                            .fontWeight(.semibold)
                        detailRow("GitHub account", value: authDetails.account ?? "—", icon: "person")
                        detailRow("Host", value: authDetails.host, icon: "globe")
                        if let credentialStore = authDetails.credentialStore {
                            detailRow("Credential store", value: credentialStore, icon: "key.horizontal")
                        }
                        if let isActive = authDetails.isActive {
                            detailRow("Status", value: isActive ? "Active account" : "Not active", icon: "checkmark.circle")
                        }
                        if let gitProtocol = authDetails.gitProtocol {
                            detailRow("Git protocol", value: gitProtocol.uppercased(), icon: "arrow.left.arrow.right")
                        }
                    }

                    if !authDetails.scopes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Granted scopes")
                                .appFont(.subheadline)
                                .fontWeight(.semibold)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], alignment: .leading, spacing: 6) {
                                ForEach(authDetails.scopes, id: \.self) { scope in
                                    Text(scope)
                                        .appFont(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Button("Refresh Status", systemImage: "arrow.clockwise") {
                    Task { await refreshStatus() }
                }
                .disabled(isChecking || isLoggingIn || isLoggingOut)

                Spacer()

                if isAuthenticated != true {
                    Button("Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark") {
                        Task { await login() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isChecking || isLoggingIn || isLoggingOut || !isCLIAvailable)
                } else {
                    Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                        showingLogoutConfirmation = true
                    }
                    .disabled(isChecking || isLoggingIn || isLoggingOut)
                }
            }

            Text(isLoggingIn
                 ? "GitHub is waiting for browser approval. Enter the one-time code copied to your clipboard if prompted, then return here."
                 : "Sign-in opens GitHub in your browser. The GitHub CLI stores its authentication securely in macOS Keychain.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 260)
        .task {
            guard loadsAuthStatusOnAppear else { return }
            await refreshStatus()
        }
        .alert("Sign out of GitHub CLI?", isPresented: $showingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { await logout() }
            }
        } message: {
            Text("This removes local CLI authentication for \(authDetails?.account ?? "this account"). It does not revoke the GitHub CLI authorization from your GitHub account.")
        }
    }

    private func detailRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: icon)
                .appFont(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .appFont(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    private func refreshStatus() async {
        isChecking = true
        defer { isChecking = false }

        do {
            let result = try await service.authStatus()
            isAuthenticated = result.isSuccess
            if result.isSuccess {
                isCLIAvailable = true
                statusMessage = "Signed in to GitHub CLI"
                authDetails = GitHubCLIAuthDetails(output: result.output)
            } else if result.exitCode == 127 {
                isCLIAvailable = false
                statusMessage = "GitHub CLI was not found. Install gh, then refresh status."
                authDetails = nil
            } else {
                isCLIAvailable = true
                statusMessage = "Not signed in to GitHub CLI"
                authDetails = nil
            }
        } catch {
            isCLIAvailable = false
            isAuthenticated = false
            statusMessage = "Could not check GitHub CLI status"
            authDetails = nil
        }
    }

    private func login() async {
        isLoggingIn = true
        statusMessage = "Opening GitHub sign-in…"
        authDetails = nil
        defer { isLoggingIn = false }

        do {
            // Open the device authorization page explicitly; gh may fail to launch
            // a browser when started from a GUI app without a terminal session.
            if let deviceURL = URL(string: "https://github.com/login/device") {
                NSWorkspace.shared.open(deviceURL)
            }
            statusMessage = "Complete sign-in in the browser…"
            let result = try await service.loginWithBrowser()
            if !result.isSuccess {
                statusMessage = "GitHub sign-in did not complete. Try again."
                isAuthenticated = false
                return
            }
            await refreshStatus()
        } catch {
            statusMessage = "Could not start GitHub sign-in: \(error.localizedDescription)"
            isAuthenticated = false
        }
    }

    private func logout() async {
        guard let authDetails, let account = authDetails.account else { return }
        isLoggingOut = true
        defer { isLoggingOut = false }

        do {
            let result = try await service.logout(host: authDetails.host, account: account)
            if result.isSuccess {
                await refreshStatus()
            } else {
                statusMessage = "Could not sign out. Refresh status and try again."
            }
        } catch {
            statusMessage = "Could not sign out: \(error.localizedDescription)"
        }
    }
}

#Preview {
    GitHubCLIAuthSettingsView(loadsAuthStatusOnAppear: false)
}
