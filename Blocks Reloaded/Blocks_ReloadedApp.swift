//
//  Blocks_ReloadedApp.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import ScenesManager

@main
struct Blocks_ReloadedApp: App {

    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var scenesManager = ScenesManager()
    @State private var appModel = AppModel.shared

    var body: some Scene {
        
        WindowGroup(id: SceneId.mainWindow.rawValue) {
            SplashScreenView()
                .frame(width: 1000, height: 700)
                .fixedSize()
                .environment(\.scenesManager, scenesManager)
                .onAppear {
                    scenesManager.setActions(
                        openWindow: openWindow,
                        dismissWindow: dismissWindow,
                        openImmersiveSpace: openImmersiveSpace,
                        dismissImmersiveSpace: dismissImmersiveSpace
                    )
                }
        }
        .windowResizability(.contentSize)
        .windowStyle(.plain)
        
        ImmersiveSpace(id: SceneId.immersiveSpace.rawValue) {
            ImmersiveView()
                .environment(appModel)
                .environment(\.scenesManager, scenesManager)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
