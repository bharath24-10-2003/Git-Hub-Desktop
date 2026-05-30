//
//  CustomModal.swift
//  Git Hub Desktop
//
//  Created by Bharath on 26/04/26.
//

import SwiftUI

struct CloneModal: View {
    
    @State private var url: String = ""
    @State private var path: String = "Documents/GitHub/"
    
    var body: some View {
        VStack (alignment:.leading) {
            ModalDescription(title: "Clone Repository", description: "Enter the URL of the GitHub remote repository and the local path where you want to clone the repository.")
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)
            
            Text("Git Repository URL")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            
            CustomTextField(url: $url, imageName: "link", placeholder: "git@github.com:user/repo.git")
                .padding(.bottom, 20)

            Text("Choose a path")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            HStack (alignment:.center) {
                
                CustomTextField(url: $path, imageName: "folder")
                BaseButton(title: "Browse") {
                    
                }
                
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            HStack (alignment:.center) {
                Spacer()
                BaseButton(title: "Close") {
                    
                }
                ProminentBaseButton(title: "Clone Repository") {
                    
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
    }
}

struct AddRepoModal: View {
    
    @State private var path: String = "Documents/GitHub/"
    
    var body: some View {
        VStack (alignment:.leading) {
            ModalDescription(title: "Add Local Repository", description: "Enter the local path of your repository to add it in GitHub.")
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.vertical)

            Text("Choose a path")
                .font(Font.system(size: 14,weight: .semibold,design: .default))
            HStack (alignment:.center) {
                
                CustomTextField(url: $path, imageName: "folder")
                BaseButton(title: "Browse") {
                    
                }
                
            }
            
            Divider()
                .padding(.horizontal, -16)
                .padding(.top)
            
            HStack (alignment:.center) {
                Spacer()
                BaseButton(title: "Close") {
                    
                }
                ProminentBaseButton(title: "Add Repository") {
                    
                }
            }
            .padding(.top, 10)
        }
        .frame(width: 500)
        .padding()
    }
}

struct CustomTextField: View {
    
    @Binding var url: String
    @State var imageName: String = ""
    @State var placeholder: String = ""
    
    var body: some View {
        TextField(placeholder, text: $url)
            .padding(12)
            .padding(.leading, 30)
            .background(
                background
            )
            .textFieldStyle(.plain)
            .font(Font.system(size: 14,weight: .regular,design: .default))
    }
    
    var background: some View {
        ZStack(alignment: .leading) {
            
            Image(systemName: imageName)
                .padding(.leading, 15)
                .opacity(0.7)
            
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
    }
}

struct BaseButton: View {
    
    @State var title: String
    @State var image: Image?
    @State var textTint: Color = .white
    @State var action: (() -> Void)
    
    var body: some View {
        Button {
             action()
        } label: {
            if let image = image {
                image
                    .resizable()
                    .frame(width: 16,height: 16)
                    .padding(.trailing, -8)
                    .padding(.leading, 16)
                    .tint(.white)
                    .font(Font.system(size: 14, weight: .bold, design: .default))
            }
            Text(title)
                .font(Font.system(size: 14, weight: .medium, design: .none))
                .padding(.horizontal,16)
                .padding(.vertical,8)
                .tint(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(height: 42)
        }
        .buttonStyle(.glass)
        .tint(.white)
    }
}
struct ProminentBaseButton: View{
    
    @State var title: String
    @State var image: Image?
    @State var textTint: Color = .black
    @State var action: (() -> Void)
    
    var body: some View {
        Button {
            action()
        } label: {
            if let image = image {
                image
                    .resizable()
                    .frame(width: 16,height: 16)
                    .padding(.trailing, -8)
                    .padding(.leading, 16)
                    .tint(.white)
                    .font(Font.system(size: 14, weight: .bold, design: .default))
            }
            Text(title)
                .font(Font.system(size: 14, weight: .medium, design: .none))
                .padding(.horizontal,16)
                .padding(.vertical,8)
                .tint(textTint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(height: 36)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                .frame(height: 42)
        }
        .buttonStyle(.borderedProminent)
    }
}

struct ModalDescription: View {
    
    @State var title: String
    @State var description: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(Font.system(size: 24, weight: .semibold, design: .default))
                .padding(.bottom, 4)
            Text(description)
                .font(Font.system(size: 14,weight: .regular,design: .default))
                .fixedSize(horizontal: false, vertical: true)
                .opacity(0.7)
        }
        .padding(.vertical,4)
    }
}

#Preview {
    
//    CloneModal()
//        .overlay {
//            RoundedRectangle(cornerRadius: 30)
//                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
//        }
//        .padding()
    
    AddRepoModal()
        .overlay {
            RoundedRectangle(cornerRadius: 30)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        }
        .padding()
    
//    ModalDescription(title: "Clone Repository", description: "Enter the URL of the repository and the path where you want to clone")
    
//    CloneModal()
//    
    HStack {
        BaseButton(title: "Push", image: Image(systemName: "arrowshape.up")) {
            
        }
        ProminentBaseButton(title: "Pull", image: Image(systemName: "arrowshape.down")) {
            
        }
    }
}
