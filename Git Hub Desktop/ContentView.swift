//
//  ContentView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 25/04/26.
//

import SwiftUI

struct ContentView: View {

    @State private var viewModel = ViewModel()

    @State private var selectedRepo: Repo?
    @State private var selectedSection: RepoSection = .changes

    var body: some View {

        NavigationSplitView {

            Sidebar(
                selectedRepo: $selectedRepo,
                selectedSection: $selectedSection,
                repos: viewModel.store.sortedRepos
            )

        } detail: {

            VStack(spacing: 0) {

//                TopBar(
//                    repo: selectedRepo,
//                    selectedSection: selectedSection
//                )

                Divider()

//                BodyView(
//                    repo: selectedRepo,
//                    selectedSection: selectedSection
//                )
            }
            .padding()
        }
        .onAppear {

            if selectedRepo == nil {
                selectedRepo = viewModel.store.sortedRepos.first
            }
        }
        .onChange(of: selectedRepo) {

            selectedSection = .changes
        }
    }
}

#Preview {
    ContentView()
}
