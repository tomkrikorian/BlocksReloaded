//
//  BlockCreatorSystem.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import RealityKit
import BlocksContent
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
                    // Create a cube entity from the HollowCube scene
                    guard let cube = try? Entity.load(named: "HollowCube", in: blocksContentBundle) else {
                        return
                    }
                    
                    entity.addChild(cube)
                    blockComponent.cube = cube
                }
                
                if let cube = blockComponent.cube {
                    // Calculate cube properties
                    let distance = simd_distance(AppModel.shared.leftPinchPosition, AppModel.shared.rightPinchPosition) * 2
                    let midpoint = (AppModel.shared.leftPinchPosition + AppModel.shared.rightPinchPosition) * 0.5
                    let direction = normalize(AppModel.shared.rightPinchPosition - AppModel.shared.leftPinchPosition)
                    let orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
                    let scale = SIMD3<Float>(distance, distance, distance)
                    
                    // Update cube
                    cube.position = midpoint
                    cube.orientation = orientation
                    cube.scale = scale
                }
            } else {
                // If not both hands are pinching, clean up
                if blockComponent.state == .creating {
                    if let cube = blockComponent.cube {
                        // Calculate final cube properties
                        let distance = simd_distance(AppModel.shared.leftPinchPosition, AppModel.shared.rightPinchPosition) * 2
                        let midpoint = (AppModel.shared.leftPinchPosition + AppModel.shared.rightPinchPosition) * 0.5
                        let direction = normalize(AppModel.shared.rightPinchPosition - AppModel.shared.leftPinchPosition)
                        let orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
                        let scale = SIMD3<Float>(distance, distance, distance)
                        
                        // Remove the temporary cube
                        cube.removeFromParent()
                        blockComponent.cube = nil
                        
                        Task {
                            await AppModel.shared.createBlock(
                                position: midpoint,
                                orientation: orientation,
                                scale: scale
                            )
                        }
                    }
                    blockComponent.state = .notCreating
                }
            }
            
            // Apply the updated component back to the entity
            entity.components.set(blockComponent)
        }
    }
}

