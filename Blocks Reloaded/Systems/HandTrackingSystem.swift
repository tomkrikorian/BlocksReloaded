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
    
    /// The main scene content
    static var mainSceneContent: Entity?

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
        
        var leftHandSphere: ModelEntity?
        var rightHandSphere: ModelEntity?
        var leftHandEntity: Entity?
        var rightHandEntity: Entity?

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
                // Update joint positions
                self.updateJointPositions(handSkeleton: handSkeleton, handComponent: handComponent, handAnchor: handAnchor)
                
                // Get thumb and index positions
                let (thumbPos, indexPos) = self.getThumbAndIndexPositions(handSkeleton: handSkeleton)
                let (thumbWorldPos, indexWorldPos) = self.getWorldPositions(thumbPos: thumbPos, indexPos: indexPos, handAnchor: handAnchor)
                
                // Calculate pinch state
                let distance = simd_distance(thumbPos, indexPos)
                let isPinching = distance < 0.03 // Adjust this threshold as needed
                
                // Update AppModel with pinch state and position
                self.updateAppModel(handComponent: handComponent, isPinching: isPinching, thumbWorldPos: thumbWorldPos, indexWorldPos: indexWorldPos)
                
                // Debug logging
                print("Thumb position: \(thumbPos)")
                print("Index position: \(indexPos)")
                print("Distance: \(distance)")
                print("Is pinching: \(isPinching)")
                
                // Handle pinch sphere
                let midpoint = (thumbWorldPos + indexWorldPos) * 0.5
                self.handlePinchSphere(
                    entity: entity,
                    handComponent: &handComponent,
                    isPinching: isPinching,
                    midpoint: midpoint,
                    leftHandSphere: &leftHandSphere,
                    rightHandSphere: &rightHandSphere,
                    leftHandEntity: &leftHandEntity,
                    rightHandEntity: &rightHandEntity
                )
            }
            
            // Apply the updated hand component back to the hand entity
            entity.components.set(handComponent)
        }
        
        // Handle connecting cube
        self.handleConnectingCube(
            leftHandSphere: leftHandSphere,
            rightHandSphere: rightHandSphere,
            leftHandEntity: leftHandEntity,
            rightHandEntity: rightHandEntity
        )
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
    
    // MARK: - Helper Methods
    
    private func updateJointPositions(handSkeleton: HandSkeleton, handComponent: HandTrackingComponent, handAnchor: HandAnchor) {
        for (jointName, jointEntity) in handComponent.fingers {
            let anchorFromJointTransform = handSkeleton.joint(jointName).anchorFromJointTransform
            jointEntity.setTransformMatrix(
                handAnchor.originFromAnchorTransform * anchorFromJointTransform,
                relativeTo: nil
            )
        }
    }
    
    private func getThumbAndIndexPositions(handSkeleton: HandSkeleton) -> (thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>) {
        let thumbTip = handSkeleton.joint(.thumbTip)
        let indexTip = handSkeleton.joint(.indexFingerTip)
        
        let thumbPosition = thumbTip.anchorFromJointTransform.columns.3
        let indexPosition = indexTip.anchorFromJointTransform.columns.3
        
        let thumbPos = SIMD3<Float>(thumbPosition.x, thumbPosition.y, thumbPosition.z)
        let indexPos = SIMD3<Float>(indexPosition.x, indexPosition.y, indexPosition.z)
        
        return (thumbPos, indexPos)
    }
    
    private func getWorldPositions(thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>, handAnchor: HandAnchor) -> (thumbWorldPos: SIMD3<Float>, indexWorldPos: SIMD3<Float>) {
        let thumbPosition = SIMD4<Float>(thumbPos.x, thumbPos.y, thumbPos.z, 1)
        let indexPosition = SIMD4<Float>(indexPos.x, indexPos.y, indexPos.z, 1)
        
        let thumbWorldPos = handAnchor.originFromAnchorTransform * thumbPosition
        let indexWorldPos = handAnchor.originFromAnchorTransform * indexPosition
        
        return (
            SIMD3<Float>(thumbWorldPos.x, thumbWorldPos.y, thumbWorldPos.z),
            SIMD3<Float>(indexWorldPos.x, indexWorldPos.y, indexWorldPos.z)
        )
    }
    
    @MainActor private func updateAppModel(handComponent: HandTrackingComponent, isPinching: Bool, thumbWorldPos: SIMD3<Float>, indexWorldPos: SIMD3<Float>) {
        if handComponent.chirality == .left {
            AppModel.shared.isPinchingLeftHand = isPinching
            if isPinching {
                AppModel.shared.leftPinchPosition = (thumbWorldPos + indexWorldPos) * 0.5
            }
        } else if handComponent.chirality == .right {
            AppModel.shared.isPinchingRightHand = isPinching
            if isPinching {
                AppModel.shared.rightPinchPosition = (thumbWorldPos + indexWorldPos) * 0.5
            }
        }
    }
    
    private func handlePinchSphere(
        entity: Entity,
        handComponent: inout HandTrackingComponent,
        isPinching: Bool,
        midpoint: SIMD3<Float>,
        leftHandSphere: inout ModelEntity?,
        rightHandSphere: inout ModelEntity?,
        leftHandEntity: inout Entity?,
        rightHandEntity: inout Entity?
    ) {
        if isPinching {
            if handComponent.pinchSphere == nil {
                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.02),
                    materials: [SimpleMaterial(color: .red, isMetallic: false)]
                )
                entity.addChild(sphere)
                handComponent.pinchSphere = sphere
                print("Created new sphere")
            }
            
            if let sphere = handComponent.pinchSphere {
                sphere.position = midpoint
                print("Sphere position: \(sphere.position)")
                
                if handComponent.chirality == .left {
                    leftHandSphere = sphere
                    leftHandEntity = entity
                } else {
                    rightHandSphere = sphere
                    rightHandEntity = entity
                }
            }
        } else {
            if let sphere = handComponent.pinchSphere {
                sphere.removeFromParent()
                handComponent.pinchSphere = nil
                print("Removed sphere")
            }
        }
    }
    
    private func handleConnectingCube(
        leftHandSphere: ModelEntity?,
        rightHandSphere: ModelEntity?,
        leftHandEntity: Entity?,
        rightHandEntity: Entity?
    ) {
        if let leftSphere = leftHandSphere,
           let rightSphere = rightHandSphere,
           let leftEntity = leftHandEntity,
           let rightEntity = rightHandEntity {
            
            let distance = simd_distance(leftSphere.position, rightSphere.position)
            let midpoint = (leftSphere.position + rightSphere.position) * 0.5
            
            if HandTrackingComponent.connectingCube == nil {
                let cube = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(1.0, 1.0, 1.0)),
                    materials: [SimpleMaterial(color: .blue, isMetallic: false)]
                )
                leftEntity.addChild(cube)
                HandTrackingComponent.connectingCube = cube
            }
            
            if let cube = HandTrackingComponent.connectingCube {
                let uniformScale = distance
                cube.scale = SIMD3<Float>(uniformScale, uniformScale, uniformScale)
                cube.position = midpoint
                
                let direction = normalize(rightSphere.position - leftSphere.position)
                cube.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: direction)
            }
        } else {
            if let cube = HandTrackingComponent.connectingCube {
                let currentTransform = cube.transform
                cube.removeFromParent()
                
                if let mainContent = Self.mainSceneContent {
                    mainContent.addChild(cube)
                    cube.transform = currentTransform
                }
                
                HandTrackingComponent.connectingCube = nil
            }
        }
    }
} 
