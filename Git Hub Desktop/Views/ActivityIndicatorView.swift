//
//  NVActivityIndicatorView.swift
//  Git Hub Desktop
//
//  Created by Bharath on 16/06/26.
//

import Foundation
import SwiftUI

struct AQILoaderView: View {

    @State private var variableValue: Double = 0
    var size: CGFloat = 48

    private let values: [Double] = [
        0,
        0.33,
        0.66,
        0.99
    ]

    var body: some View {
        Image(
            systemName: "aqi.medium",
            variableValue: variableValue
        )
        .font(.system(size: size))
        .task {
            await startLoadingAnimation()
        }
    }

    private func startLoadingAnimation() async {
        while !Task.isCancelled {
            for value in values {
                withAnimation(.smooth(duration: 0.35)) {
                    variableValue = value
                }

                try? await Task.sleep(
                    for: .milliseconds(250)
                )
            }
        }
    }
}
