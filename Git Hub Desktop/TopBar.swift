//
//  TopBar.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct TopBar: View {

    let repo: Repo?
    let viewModel: ViewModel
    
    @State private var error: String?

    var body: some View {
        if let repo = repo {
            VStack(spacing: 8) {
                HStack (alignment: .center){
                    Text(repo.name)
                        .font(Font.system(size: 18, weight: .semibold))
                    Text("/")
                        .font(Font.system(size: 14, weight: .light))
                        .opacity(0.5)
                    HStack {
                        Image(systemName: "arrow.trianglehead.branch")
                        Text(viewModel.currentBranch.isEmpty ? repo.currentBranch : viewModel.currentBranch)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .frame(height: 28)
                            .padding(-8)
                            .tint(.gray)
                            .opacity(0.2)
                    }
                    .padding(8)
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 10)
                    }
                    
                    BaseButton(title: "Fetch", image: Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90"),imageSize: CGSize(width: 19, height: 16)) {
                        self.error = nil
                        Task {
                            let result = await viewModel.fetch(at: repo)
                            if let result, !result.isSuccess {
                                self.error = result.error.isEmpty ? result.output : result.error
                            }
                        }
                    }
                    BaseButton(title: "Pull", image: Image(.pull)) {
                        self.error = nil
                        Task {
                            let result = await viewModel.pull(at: repo)
                            if let result, !result.isSuccess {
                                self.error = result.error.isEmpty ? result.output : result.error
                            }
                        }
                    }
                    ProminentBaseButton(title: "Push", image: Image(.push)) {
                        self.error = nil
                        Task {
                            let result = await viewModel.push(at: repo)
                            if let result, !result.isSuccess {
                                self.error = result.error.isEmpty ? result.output : result.error
                            }
                        }
                    }
                }
                
                if let error {
                    ErrorBannerView(message: error) {
                        self.error = nil
                    }
                }
            }
        } else {
            HStack (alignment: .center){
                Text("Clone or Choose a repository")
                    .font(Font.system(size: 18, weight: .semibold))
                Spacer()
                BaseButton(title: "Clone a Repo") {
                    viewModel.showCloneModal = true
                }
                BaseButton(title: "Add Local Repo") {
                    viewModel.showAddRepoModal = true
                }
            }
        }
    }
}
