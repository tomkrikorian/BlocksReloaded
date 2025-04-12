//
//  AppModel.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import SwiftUI
import RealityKit
import RealityKitContent

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
    
    public init() { }
    
    /// Creates a block with the given properties and adds it to the scene
    /// - Parameters:
    ///   - position: The position of the block in world space
    ///   - orientation: The orientation of the block
    ///   - scale: The scale of the block
    /// - Returns: The created block entity
    @MainActor
    func createBlock(position: SIMD3<Float>, orientation: simd_quatf, scale: SIMD3<Float>) -> Entity? {
        guard let root = sceneRootEntity else { return nil }
        
        // Create a cube entity from the GlowCube scene
        guard let cube = try? Entity.load(named: "GlowCube", in: realityKitContentBundle) else {
            return nil
        }
        
        cube.position = position
        cube.orientation = orientation
        cube.scale = scale
        
        // Add collision component with proper collision group and mask
        cube.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateBox(size: scale)],
            mode: .default
        )
        
        // Add physics body component with improved physics settings
        var physics = PhysicsBodyComponent(
            massProperties: .init(mass: 1.0), // Increased mass for better interaction
            material: .generate(staticFriction: 0.5, dynamicFriction: 0.4, restitution: 0.3), // Adjusted for better bouncing
            mode: .dynamic
        )
        physics.isAffectedByGravity = true
        physics.isContinuousCollisionDetectionEnabled = true // Enable continuous collision detection
        cube.components[PhysicsBodyComponent.self] = physics
        
        // Add physics simulation component
        var physicsSimulation = PhysicsSimulationComponent()
        physicsSimulation.collisionOptions = .all
        cube.components[PhysicsSimulationComponent.self] = physicsSimulation

        var physicsMotion =  PhysicsMotionComponent()
        cube.components[PhysicsMotionComponent.self] = physicsMotion

        
        cube.components.set(InputTargetComponent(allowedInputTypes: .direct))
        
        root.addChild(cube)
        return cube
    }
}
