//
//  TopBar.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct TopBar: View {

    let repo: Repo?

    var body: some View {
        if let repo = repo {
            HStack (alignment: .center){
                Text(repo.name)
                    .font(Font.system(size: 18, weight: .semibold))
                Text("/")
                    .font(Font.system(size: 14, weight: .light))
                    .opacity(0.5)
                HStack {
                    Image(systemName: "arrow.trianglehead.branch")
                    Text(repo.currentBranch)
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
                BaseButton(title: "Fetch", image: Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")) {
                    
                }
                BaseButton(title: "Pull", image: Image(.pull)) {
                    
                }
                ProminentBaseButton(title: "Push", image: Image(.push)) {
                    
                }
            }
        } else {
            HStack (alignment: .center){
                Text("Clone or Choose a repository")
                    .font(Font.system(size: 18, weight: .semibold))
                Spacer()
                BaseButton(title: "Clone a Repo") {
                    
                }
                BaseButton(title: "Add Local Repo") {
                    
                }
            }
        }
    }
}

#Preview {
    let repo = Repo.init(name: "tvOS-Beacon", path: "test", currentBranch: "main")
    TopBar(repo: repo)
        .frame(height: 30)
        .padding()
}
