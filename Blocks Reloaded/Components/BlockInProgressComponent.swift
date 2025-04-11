//
//  BlockInProgressComponent.swift
//  Blocks Reloaded
//
//  Created by Tom Krikorian on 11/04/2025.
//

import RealityKit

/// A component that tracks the state of a block being created between two hands
struct BlockInProgressComponent: Component {
    /// The cube entity that represents the block being created
    var cube: Entity?
    
    /// The current state of the block creation
    enum State {
        case notCreating
        case creating
    }
    
    var state: State = .notCreating
    
    init() {
        BlockCreatorSystem.registerSystem()
    }
}

