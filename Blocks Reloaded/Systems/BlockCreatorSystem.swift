//
//  BlockCreatorSystem.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import RealityKit
import SwiftUI

/// A system that handles the creation of blocks between hands
struct BlockCreatorSystem: System {
    /// The query this system uses to find all entities with the block in progress component.
    static let query = EntityQuery(where: .has(BlockInProgressComponent.self))
    
    init(scene: RealityKit.Scene) { }
    
    /// Performs any necessary updates to the entities with the block in progress component.
    /// - Parameter context: The context for the system to update.
    func update(context: SceneUpdateContext) {
        let blockEntities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        for entity in blockEntities {
            guard var blockComponent = entity.components[BlockInProgressComponent.self] else { continue }
            
            // Check if both hands are pinching
            if AppModel.shared.isPinchingLeftHand && AppModel.shared.isPinchingRightHand {
                blockComponent.state = .creating
                
                // Create or update the cube
                if blockComponent.cube == nil {
                    let cube = ModelEntity(
                        mesh: .generateBox(size: SIMD3<Float>(1.0, 1.0, 1.0)),
                        materials: [SimpleMaterial(color: .blue, isMetallic: false)]
                    )
                    entity.addChild(cube)
                    blockComponent.cube = cube
                }
                
                if let cube = blockComponent.cube {
                    // Calculate cube properties
                    let distance = simd_distance(AppModel.shared.leftPinchPosition, AppModel.shared.rightPinchPosition)
                    let midpoint = (AppModel.shared.leftPinchPosition + AppModel.shared.rightPinchPosition) * 0.5
                    
                    // Update cube
                    let uniformScale = distance
                    cube.scale = SIMD3<Float>(uniformScale, uniformScale, uniformScale)
                    cube.position = midpoint
                    
                    // Orient the cube to point from left to right hand
                    let direction = normalize(AppModel.shared.rightPinchPosition - AppModel.shared.leftPinchPosition)
                    cube.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
                }
            } else {
                // If not both hands are pinching, clean up
                if blockComponent.state == .creating {
                    if let cube = blockComponent.cube {
                        // Store the cube's current transform
                        let currentTransform = cube.transform
                        
                        // Remove from block entity
                        cube.removeFromParent()
                        
                        // Add to main scene if available
                        if let root = AppModel.shared.sceneRootEntity {
                            root.addChild(cube)
                            // Restore the transform
                            cube.transform = currentTransform
                        }
                        
                        blockComponent.cube = nil
                    }
                    blockComponent.state = .notCreating
                }
            }
            
            // Apply the updated component back to the entity
            entity.components.set(blockComponent)
        }
    }
}

