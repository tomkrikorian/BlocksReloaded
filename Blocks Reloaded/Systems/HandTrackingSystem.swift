/*
Abstract:
A system that updates entities that have hand-tracking components.
*/
import RealityKit
import ARKit

/// A system that provides hand-tracking capabilities.
struct HandTrackingSystem: System {
    /// The active ARKit session.
    static var arSession = ARKitSession()

    /// The provider instance for hand-tracking.
    static let handTracking = HandTrackingProvider()

    /// The most recent anchor that the provider detects on the left hand.
    static var latestLeftHand: HandAnchor?

    /// The most recent anchor that the provider detects on the right hand.
    static var latestRightHand: HandAnchor?

    init(scene: RealityKit.Scene) {
        Task { await Self.runSession() }
    }

    @MainActor
    static func runSession() async {
        do {
            // Attempt to run the ARKit session with the hand-tracking provider.
            try await arSession.run([handTracking])
        } catch let error as ARKitSession.Error {
            print("The app has encountered an error while running providers: \(error.localizedDescription)")
        } catch let error {
            print("The app has encountered an unexpected error: \(error.localizedDescription)")
        }

        // Start to collect each hand-tracking anchor.
        for await anchorUpdate in handTracking.anchorUpdates {
            // Check whether the anchor is on the left or right hand.
            switch anchorUpdate.anchor.chirality {
            case .left:
                self.latestLeftHand = anchorUpdate.anchor
            case .right:
                self.latestRightHand = anchorUpdate.anchor
            }
        }
    }
    
    /// The query this system uses to find all entities with the hand-tracking component.
    static let query = EntityQuery(where: .has(HandTrackingComponent.self))
    
    /// Performs any necessary updates to the entities with the hand-tracking component.
    /// - Parameter context: The context for the system to update.
    func update(context: SceneUpdateContext) {
        let handEntities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)

        for entity in handEntities {
            guard var handComponent = entity.components[HandTrackingComponent.self] else { continue }

            // Set up the finger joint entities if you haven't already.
            if handComponent.fingers.isEmpty {
                self.addJoints(to: entity, handComponent: &handComponent)
            }

            // Get the hand anchor for the component, depending on its chirality.
            guard let handAnchor: HandAnchor = switch handComponent.chirality {
                case .left: Self.latestLeftHand
                case .right: Self.latestRightHand
                default: nil
            } else { continue }

            // Iterate through all of the anchors on the hand skeleton.
            if let handSkeleton = handAnchor.handSkeleton {
                for (jointName, jointEntity) in handComponent.fingers {
                    /// The current transform of the person's hand joint.
                    let anchorFromJointTransform = handSkeleton.joint(jointName).anchorFromJointTransform

                    // Update the joint entity to match the transform of the person's hand joint.
                    jointEntity.setTransformMatrix(
                        handAnchor.originFromAnchorTransform * anchorFromJointTransform,
                        relativeTo: nil
                    )
                }
                
                // Check for pinch between thumb and index finger
                let thumbTip = handSkeleton.joint(.thumbTip)
                let indexTip = handSkeleton.joint(.indexFingerTip)
                
                let thumbPosition = thumbTip.anchorFromJointTransform.columns.3
                let indexPosition = indexTip.anchorFromJointTransform.columns.3
                
                // Extract xyz components from the position vectors
                let thumbPos = SIMD3<Float>(thumbPosition.x, thumbPosition.y, thumbPosition.z)
                let indexPos = SIMD3<Float>(indexPosition.x, indexPosition.y, indexPosition.z)
                
                let distance = simd_distance(thumbPos, indexPos)
                let isPinching = distance < 0.03 // Adjust this threshold as needed
                
                // Debug logging
                print("Thumb position: \(thumbPos)")
                print("Index position: \(indexPos)")
                print("Distance: \(distance)")
                print("Is pinching: \(isPinching)")
                
                // Create or update the pinch sphere
                if isPinching {
                    if handComponent.pinchSphere == nil {
                        // Create the sphere if it doesn't exist
                        let sphere = ModelEntity(
                            mesh: .generateSphere(radius: 0.02),
                            materials: [SimpleMaterial(color: .red, isMetallic: false)]
                        )
                        entity.addChild(sphere)
                        handComponent.pinchSphere = sphere
                        print("Created new sphere")
                    }
                    
                    // Position the sphere between thumb and index finger
                    if let sphere = handComponent.pinchSphere {
                        // Convert positions to world space
                        let thumbWorldPos = handAnchor.originFromAnchorTransform * thumbPosition
                        let indexWorldPos = handAnchor.originFromAnchorTransform * indexPosition
                        
                        let thumbWorldPos3 = SIMD3<Float>(thumbWorldPos.x, thumbWorldPos.y, thumbWorldPos.z)
                        let indexWorldPos3 = SIMD3<Float>(indexWorldPos.x, indexWorldPos.y, indexWorldPos.z)
                        
                        let midpoint = (thumbWorldPos3 + indexWorldPos3) * 0.5
                        sphere.position = midpoint
                        print("Sphere position: \(sphere.position)")
                    }
                } else {
                    // Remove the sphere if not pinching
                    if let sphere = handComponent.pinchSphere {
                        sphere.removeFromParent()
                        handComponent.pinchSphere = nil
                        print("Removed sphere")
                    }
                }
            }
            
            // Apply the updated hand component back to the hand entity
            entity.components.set(handComponent)
        }
    }
    
    /// Performs any necessary setup to the entities with the hand-tracking component.
    /// - Parameters:
    ///   - entity: The entity to perform setup on.
    ///   - handComponent: The hand-tracking component to update.
    func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
        /// The size of the sphere mesh.
        let radius: Float = 0.01

        /// The material to apply to the sphere entity.
        let material = SimpleMaterial(color: .white, isMetallic: false)

        /// The sphere entity that represents a joint in a hand.
        let sphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )

        // For each joint, create a sphere and attach it to the fingers.
        for bone in Hand.joints {
            // Add a duplication of the sphere entity to the hand entity.
            let newJoint = sphereEntity.clone(recursive: false)
            handEntity.addChild(newJoint)

            // Attach the sphere to the finger.
            handComponent.fingers[bone.0] = newJoint
        }

        // Apply the updated hand component back to the hand entity.
        handEntity.components.set(handComponent)
    }
} 
