//
//  LoadingView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 18/06/26.
//

import SwiftUI

struct LoadingView: View {
    let loadingMessage: String
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            AQILoaderView()
                .foregroundStyle(.blue)
                .frame(width: 80, height: 80)
            
            Text(loadingMessage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(24)
        .frame(width: 280, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .interactiveDismissDisabled(true)
    }
}

struct LoadingOverlay: View {
    let loadingMessage: String
    let isLoading: Bool
    
    var body: some View {
        ZStack {
            // Subtle dimming effect
            Color.black.opacity(0.15)
                .edgesIgnoringSafeArea(.all)
            
            LoadingView(loadingMessage: loadingMessage, isLoading: isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
