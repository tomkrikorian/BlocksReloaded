//
//  ImmersiveView.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import RealityKit
import BlocksContent
import ScenesManager

struct ImmersiveView: View {
    @Environment(\.scenesManager) private var scenesManager
    @State private var initialPosition: SIMD3<Float>? = nil
    @Environment(AppModel.self) private var appModel
    
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
        RealityView { content, attachments in
            // Create a root entity for the scene
            let rootEntity = Entity()
            rootEntity.name = "SCENE_ROOT"
            
            var simulation = PhysicsSimulationComponent()
            simulation.gravity = appModel.gravity
            rootEntity.components.set(simulation)
            
            AppModel.shared.sceneRootEntity = rootEntity
            content.add(rootEntity)
            
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: blocksContentBundle) {
                rootEntity.addChild(immersiveContentEntity)
            }
            
            // Add ambient audio
            if let audioEntity = createAmbientAudio() {
                rootEntity.addChild(audioEntity)
            }
            
            // Add hand tracking
            makeHandEntities(in: rootEntity)
            makeBlockCreatorEntity(in: rootEntity)
            
            // Add collision event subscription
            content.subscribe(to: CollisionEvents.Began.self) { collisionEvent in
                Task { @MainActor in
                    do {
                        let audioResource = try AudioFileResource.load(
                            named: "SFX_Impact",
                            configuration: .init(shouldLoop: false)
                        )
                        
                        var spatialAudio = SpatialAudioComponent()
                        spatialAudio.gain = -5.0
                        collisionEvent.entityA.spatialAudio = spatialAudio
                        collisionEvent.entityA.playAudio(audioResource)
                    } catch {
                        print("Error loading impact audio: \(error.localizedDescription)")
                    }
                }
            }
            
            // Add introduction attachment
            if let introductionAttachment = attachments.entity(for: "introduction") {
                // Position the attachment 2 meters in front of the user
                introductionAttachment.position = [0, 1.5, -2]
                rootEntity.addChild(introductionAttachment)
            }
        } attachments: {
            Attachment(id: "introduction") {
                IntroductionView()
            }
        }
        .onChange(of: appModel.gravity, { oldValue, newValue in
            var simulation = PhysicsSimulationComponent()
            simulation.gravity = appModel.gravity
            guard let sceneRoot = appModel.sceneRootEntity else {
                return
            }
            sceneRoot.components.set(simulation)
        })
        .upperLimbVisibility(.hidden)
        .persistentSystemOverlays(.hidden)
        .gesture(translationGesture)
        .immersiveSpaceTracker()
        .sceneTracker(for: SceneId.immersiveSpace, onOpen:{onOpen()}, onDismiss: {onDismiss()})

    }
    
    
    func onOpen() {
        scenesManager.dismissWindow(.mainWindow)
    }
    
    func onDismiss() {
        scenesManager.openWindow(.mainWindow)
    }
    
    /// Creates the entity that contains all hand-tracking entities.
    @MainActor
    func makeHandEntities(in rootEntity: Entity) {
        // Add the left hand.
        let leftHand = Entity()
        leftHand.components.set(HandTrackingComponent(chirality: .left))
        rootEntity.addChild(leftHand)

        // Add the right hand.
        let rightHand = Entity()
        rightHand.components.set(HandTrackingComponent(chirality: .right))
        rootEntity.addChild(rightHand)
    }
    
    @MainActor
    func makeBlockCreatorEntity(in rootEntity: Entity) {
        let blockCreatorEntity = Entity()
        blockCreatorEntity.name = "BLOCK_CREATOR"
        blockCreatorEntity.components.set(BlockInProgressComponent())
        rootEntity.addChild(blockCreatorEntity)
    }
    
    @MainActor
    func createAmbientAudio() -> Entity? {
        let audioEntity = Entity()
        
        do {
            // Load the audio file from RealityKitContent package
            let audioResource = try AudioFileResource.load(
                named: "GalacticHorizons",
                configuration: .init(shouldLoop: true)
            )
            
            var ambientAudio = AmbientAudioComponent()
            ambientAudio.gain = -5.0 // Slightly lower volume
            audioEntity.ambientAudio = ambientAudio
            audioEntity.playAudio(audioResource)
            
            return audioEntity
        } catch {
            print("Error loading ambient audio: \(error.localizedDescription)")
            return nil
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel.shared)
}
