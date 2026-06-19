//
//  StashesView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 15/06/26.
//

import SwiftUI

struct StashesView: View {
    
    let repo: Repo
    let viewModel: MainViewModel
    let coordinator: AppCoordinator
    
    @State var error: String? = nil
    @State var selectedStash: GitStash? = nil
    @State var height: CGFloat = 0
    @State var stashViewPresented: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                TitleView(title: "Stash", desc: "All Stashes in the repository is shown here. Apply, discard or restore the stash to the current branch.")
            }
            .onChange(of: stashViewPresented) { oldValue, newValue in
                if !newValue {
                    selectedStash = nil
                }
            }
            
            if let error {
                ErrorBannerView(message: error ) {
                    self.error = nil
                }
                .padding(.horizontal)
            }
            
            ZStack {
                GeometryReader { proxy in
                    if !viewModel.stashes.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.stashes) { stash in
                                    SingleStashView(stash: stash, applyStash: {
                                        Task {
                                            do {
                                                let result = try await viewModel.applyStash(at: repo)
                                                if !result.isSuccess {
                                                    self.error = result.error
                                                }
                                            } catch {
                                                self.error = error.localizedDescription
                                            }
                                        }
                                    }, popStash: {
                                        Task {
                                            do {
                                                let result = try await viewModel.popStash(at: repo)
                                                if !result.isSuccess {
                                                    self.error = result.error
                                                }
                                            } catch {
                                                self.error = error.localizedDescription
                                            }
                                        }
                                    }, deleteStash: {
                                        Task {
                                            do {
                                                let result = try await viewModel.dropStash(at: repo)
                                                if !result.isSuccess {
                                                    self.error = result.error
                                                }
                                            } catch {
                                                self.error = error.localizedDescription
                                            }
                                        }
                                    })
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedStash = stash
                                        stashViewPresented = true
                                    }
                                    .padding(-10)
                                }
                                .padding()
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .padding(.bottom, 14)
                        .onAppear {
                            self.height = proxy.size.height
                        }
                    } else {
                        NoStashView()
                    }
                }
                
                if let stash = selectedStash {
                    CommitDiffDetailView(
                        hash: stash.id,
                        title: stash.message,
                        repo: repo,
                        viewModel: viewModel,
                        onBack: {
                            stashViewPresented = false
                        }
                    )
                    .frame(height: height)
                }
            }
        }
    }
}

struct SingleStashView: View {

    enum StashAction: Identifiable {
        case apply
        case pop
        case delete
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .apply: return "Apply Stash"
            case .pop: return "Pop Stash"
            case .delete: return "Delete Stash"
            }
        }
        
        var message: String {
            switch self {
            case .apply: return "Are you sure you want to apply the changes from this stash to your working directory?"
            case .pop: return "Are you sure you want to pop this stash? This will apply the changes to your working directory and remove the stash permanently from your list."
            case .delete: return "Are you sure you want to delete this stash? This action cannot be undone."
            }
        }
        
        var buttonText: String {
            switch self {
            case .apply: return "Apply"
            case .pop: return "Pop"
            case .delete: return "Delete"
            }
        }
        
        var role: ButtonRole? {
            switch self {
            case .delete: return .destructive
            default: return nil
            }
        }
    }

    let stash: GitStash

    @State private var stashError: String?
    @State var applyStash: () -> Void
    @State var popStash: () -> Void
    @State var deleteStash: () -> Void
    @State private var pendingAction: StashAction? = nil
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {

                Text(stashIndex)
                    .frame(width: 44, height: 44)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .background(Circle().opacity(0.15))

                VStack(alignment: .leading, spacing: 4) {

                    Text(stash.message)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {

                        Text(stash.branch)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(stash.type)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(stash.type == "WIP on" ? .orange : .blue)
                    }
                }

                Spacer()

                HStack(spacing: 8) {

                    Button {
                        stashError = nil
                        pendingAction = .apply
                        showAlert = true
                    } label: {
                        Text("Apply")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glassProminent)

                    Button {
                        stashError = nil
                        pendingAction = .pop
                        showAlert = true
                    } label: {
                        Text("Pop")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glass)
                    
                    Button {
                        stashError = nil
                        pendingAction = .delete
                        showAlert = true
                    } label: {
                        Text("Delete")
                            .padding(3)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .buttonStyle(.glass)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if let stashError {
                ErrorBannerView(message: stashError) {
                    self.stashError = nil
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray, lineWidth: 1)
                .opacity(0.2)
        }
        .alert(
            pendingAction?.title ?? "",
            isPresented: $showAlert,
            presenting: pendingAction
        ) { action in
            Button(action.buttonText, role: action.role) {
                switch action {
                case .apply: applyStash()
                case .pop: popStash()
                case .delete: deleteStash()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    private var stashIndex: String {
        stash.id
            .replacingOccurrences(of: "stash@{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }
}

struct NoStashView : View {
    var body: some View {
    
        VStack {
            Image(systemName: "xmark.bin")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Text("No stashes found in this Repository")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
    }
}

#Preview {
    StashesView(repo: Repo(name: "tvOS-App", path: "/Users/bharath/Documents/Projects/tvOS-App", currentBranch: "develop"), viewModel: MainViewModel(), coordinator: AppCoordinator())
}
