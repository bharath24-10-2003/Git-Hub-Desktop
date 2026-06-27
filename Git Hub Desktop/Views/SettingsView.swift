//
//  SettingsView.swift
//  Git Hub Desktop
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                
            GitConfigSettingsView()
                .tabItem {
                    Label("Git Config", systemImage: "terminal")
                }
            
            AuthSettingsView()
                .tabItem {
                    Label("Authentication", systemImage: "lock")
                }
        }
        .frame(width: 450, height: 250)
    }
}


struct AppearanceSettingsView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    
    var body: some View {
        Form {
            Picker("Appearance", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
        .padding(30)
    }
}

struct GitConfigSettingsView: View {
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var isSaving = false
    @State private var showSavedMessage = false
    let gitService = GitService()
    
    var body: some View {
        Form {
            TextField("Global Username", text: $username)
            TextField("Global Email", text: $email)
            
            HStack {
                if showSavedMessage {
                    Text("Saved")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Spacer()
                Button("Save") {
                    saveConfig()
                }
                .disabled(isSaving)
            }
            .padding(.top)
        }
        .padding(30)
        .task {
            username = await gitService.getGlobalConfig(key: "user.name") ?? ""
            email = await gitService.getGlobalConfig(key: "user.email") ?? ""
        }
    }
    
    func saveConfig() {
        isSaving = true
        showSavedMessage = false
        Task {
            try? await gitService.setGlobalConfig(key: "user.name", value: username)
            try? await gitService.setGlobalConfig(key: "user.email", value: email)
            isSaving = false
            withAnimation {
                showSavedMessage = true
            }
        }
    }
}

struct AuthSettingsView: View {
    @State private var githubUsername: String = ""
    @State private var token: String = ""
    @State private var isSaving = false
    @State private var message: String? = nil
    
    let gitService = GitService()
    
    var body: some View {
        Form {
            TextField("GitHub Username", text: $githubUsername)
            SecureField("Personal Access Token", text: $token)
            
            Text("Your token will be securely saved in the macOS Keychain and automatically used by Git for HTTPS operations.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            HStack {
                if let message {
                    Text(message)
                        .foregroundColor(message.contains("Failed") ? .red : .green)
                        .font(.caption)
                }
                Spacer()
                Button("Register Token") {
                    register()
                }
                .disabled(isSaving || token.isEmpty || githubUsername.isEmpty)
            }
            .padding(.top)
        }
        .padding(30)
    }
    
    func register() {
        isSaving = true
        Task {
            do {
                try await gitService.registerPAT(username: githubUsername, token: token)
                message = "Token saved to macOS Keychain."
                token = ""
            } catch {
                message = "Failed to save: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
