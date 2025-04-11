/*
Abstract:
A component that tracks an entity to a hand.
*/
import RealityKit
import ARKit

/// A component that tracks the hand skeleton.
struct HandTrackingComponent: Component {
    /// The chirality for the hand this component tracks.
    var chirality: HandAnchor.Chirality

    /// A lookup that maps each joint name to the entity that represents it.
    var fingers: [HandSkeleton.JointName: ModelEntity] = [:]
    
    /// A lookup that maps each joint name to the bone entity that represents it.
    var bones: [HandSkeleton.JointName: ModelEntity] = [:]

    /// The sphere entity that appears when pinching
    var pinchSphere: ModelEntity?
    
    /// Last known positions of joints for change detection
    var lastJointPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]
    
    /// Time when the pinch started
    var pinchStartTime: TimeInterval = 0
    
    /// Whether the pinch is valid (after delay)
    var isPinchValid: Bool = false
    
    /// Creates a new hand-tracking component.
    /// - Parameter chirality: The chirality of the hand target.
    init(chirality: HandAnchor.Chirality) {
        self.chirality = chirality
        HandTrackingSystem.registerSystem()
    }
} 
