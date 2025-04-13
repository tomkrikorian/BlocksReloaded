//
//  AppModel.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import RealityKit
import BlocksContent

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    
    public static let shared = AppModel()
    
    public var sceneRootEntity: Entity?
    
    public var isPinchingLeftHand: Bool = false
    public var leftPinchPosition: SIMD3<Float> = .zero
    
    public var isPinchingRightHand: Bool = false
    public var rightPinchPosition: SIMD3<Float> = .zero
    
    // Hand root entities
    public var leftHandRoot: Entity?
    public var rightHandRoot: Entity?
    
    public var gravity: SIMD3<Float> = [0, -9.8, 0]
    
    public init() { }
    
    public func toggleGravity() {
        if gravity.y == 0 {
            gravity = [0, -9.8, 0]
        } else {
            gravity = [0, 0, 0]
        }
    }
    
    /// Creates a block with the given properties and adds it to the scene
    /// - Parameters:
    ///   - position: The position of the block in world space
    ///   - orientation: The orientation of the block
    ///   - scale: The scale of the block
    /// - Returns: The created block entity
    @MainActor
    func createBlock(position: SIMD3<Float>, orientation: simd_quatf, scale: SIMD3<Float>) async -> Entity? {
        guard let root = sceneRootEntity else { return nil }
        
        // Create a cube entity from the GlowCube scene
        guard let cube = try? await Entity.init(named: "GlowCube", in: blocksContentBundle) else {
            return nil
        }
        
        // Get the first child entity
        guard let childEntity = cube.children.first else {
            return nil
        }
        
        // Apply transformations to the child entity
        childEntity.position = position
        childEntity.orientation = orientation
        childEntity.scale = scale
        
        // Add physics body component with improved physics settings
        var physics = PhysicsBodyComponent(
            massProperties: .default,
            material: .generate(staticFriction: 10, dynamicFriction: 10, restitution: 0),
            mode: .dynamic
        )
        physics.isAffectedByGravity = true
        physics.isContinuousCollisionDetectionEnabled = true
        childEntity.components[PhysicsBodyComponent.self] = physics

        let physicsMotion = PhysicsMotionComponent()
        childEntity.components[PhysicsMotionComponent.self] = physicsMotion

        let highlightStyle = HoverEffectComponent.HighlightHoverEffectStyle(
            color: .orange,
            strength: 0.2
        )
        let hoverEffect = HoverEffectComponent(.highlight(highlightStyle))
        childEntity.components.set(hoverEffect)

        // Play creation sound effect
        do {
            let audioResource = try AudioFileResource.load(
                named: "SFX_BoxCreated",
                configuration: .init(shouldLoop: false)
            )
            
            var spatialAudio = SpatialAudioComponent()
            spatialAudio.gain = -5.0
            childEntity.spatialAudio = spatialAudio
            childEntity.playAudio(audioResource)
        } catch {
            print("Error loading box creation audio: \(error.localizedDescription)")
        }
        
        root.addChild(cube)
        return cube
    }
}
