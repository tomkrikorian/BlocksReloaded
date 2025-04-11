//
//  SplashScreenView.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 12/04/2025.
//

import RealityKit
import SwiftUI

struct SplashScreenView: View {
    @Environment(\.scenesManager) var scenesManager
    private static let startButtonWidth: CGFloat = 150

    var body: some View {
        ZStack {
            VStack {
                
            }
            
            
            VStack {
                Spacer(minLength: 100)
                
                SplashScreenForegroundView()
                
                Spacer(minLength: 50)
                
                Button {
                    Task {
                        await scenesManager.toggleImmersiveSpace()
                    }
                } label: {
                    Text("Start").frame(minWidth: Self.startButtonWidth)
                }
                .glassBackgroundEffect()
                .controlSize(.extraLarge)
                .frame(width: Self.startButtonWidth)
                
                Spacer(minLength: 100)
            }
            .frame(depth: 0, alignment: DepthAlignment.back)
        }
        .glassBackgroundEffect()
        .frame(depth: 100, alignment: DepthAlignment.back)
        .sceneTracker(for: .mainWindow)
    }
}
