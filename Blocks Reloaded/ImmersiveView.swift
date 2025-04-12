//
//  ImmersiveView.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @State private var initialPosition: SIMD3<Float>? = nil
    
    var translationGesture: some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged({ value in
                /// The entity that the drag gesture targets.
                let rootEntity = value.entity

                // Set `initialPosition` to the initial position of the entity if it is `nil`.
                if initialPosition == nil {
                    initialPosition = rootEntity.position
                    rootEntity.components.remove(PhysicsBodyComponent.self)
                }

                /// The movement that converts a global world space to the scene world space of the entity.
                let movement = value.convert(value.translation3D, from: .global, to: .scene)

                // Apply the entity position to match the drag gesture
                rootEntity.position = (initialPosition ?? .zero) + movement
            })
            .onEnded({ value in
                var physics = PhysicsBodyComponent()
                physics.isAffectedByGravity = true
                value.entity.components.set(physics)
                // Reset the `initialPosition` to `nil` when the gesture ends.
                initialPosition = nil
            })
    }
    
    var body: some View {
        RealityView { content in
            // Create a root entity for the scene
            let rootEntity = Entity()
            AppModel.shared.sceneRootEntity = rootEntity
            content.add(rootEntity)
            
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
            
            // Add hand tracking
            makeHandEntities(in: content)
            makeBlockCreatorEntity(in: content)
        }
        .upperLimbVisibility(.hidden)
        .gesture(translationGesture)
    }
    
    /// Creates the entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities(in content: any RealityViewContentProtocol) {
        // Add the left hand.
        let leftHand = Entity()
        leftHand.components.set(HandTrackingComponent(chirality: .left))
        content.add(leftHand)

        // Add the right hand.
        let rightHand = Entity()
        rightHand.components.set(HandTrackingComponent(chirality: .right))
        content.add(rightHand)
    }
    
    @MainActor
    func makeBlockCreatorEntity(in content: any RealityViewContentProtocol) {
        let blockCreatorEntity = Entity()
        blockCreatorEntity.components.set(BlockInProgressComponent())
        content.add(blockCreatorEntity)
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel.shared)
}
