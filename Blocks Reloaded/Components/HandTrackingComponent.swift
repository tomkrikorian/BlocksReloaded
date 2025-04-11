/*
Abstract:
A component that tracks an entity to a hand.
*/
import RealityKit
import ARKit

/// A component that tracks the hand skeleton.
struct HandTrackingComponent: Component {
    /// The chirality for the hand this component tracks.
    let chirality: AnchoringComponent.Target.Chirality

    /// A lookup that maps each joint name to the entity that represents it.
    var fingers: [HandSkeleton.JointName: Entity] = [:]
    
    /// The sphere entity that appears when pinching
    var pinchSphere: ModelEntity?
    
    /// The cube entity that appears when both hands are pinching
    static var connectingCube: ModelEntity?
    
    /// Creates a new hand-tracking component.
    /// - Parameter chirality: The chirality of the hand target.
    init(chirality: AnchoringComponent.Target.Chirality) {
        self.chirality = chirality
        HandTrackingSystem.registerSystem()
    }
} 