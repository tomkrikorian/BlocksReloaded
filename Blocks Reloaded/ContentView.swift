//
//  ContentView.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @State private var enlarge = false

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                content.add(scene)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                ToggleImmersiveSpaceButton()
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
