import RealityKit
import SwiftUI
import ARKit

/*
Abstract:
A system that updates entities that have hand-tracking components.
*/

struct HandTrackingSystem: System {
    static var arSession = ARKitSession()
    static let handTracking = HandTrackingProvider()
    
    static var latestLeftHand: HandAnchor?
    static var latestRightHand: HandAnchor?
    
    init(scene: RealityKit.Scene) {
        Task { await Self.runSession() }
    }
    
    @MainActor
    static func runSession() async {
        do {
            try await arSession.run([handTracking])
        } catch let error as ARKitSession.Error {
            print("Error running providers: \(error.localizedDescription)")
        } catch let error {
            print("Unexpected error: \(error.localizedDescription)")
        }
        
        // Listen for each hand anchor update.
        for await anchorUpdate in handTracking.anchorUpdates {
            switch anchorUpdate.anchor.chirality {
            case .left:
                Self.latestLeftHand = anchorUpdate.anchor
            case .right:
                Self.latestRightHand = anchorUpdate.anchor
            }
        }
    }
    
    static let query = EntityQuery(where: .has(HandTrackingComponent.self))
    
    func update(context: SceneUpdateContext) {
        let handEntities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        var leftHandSphere: ModelEntity?
        var rightHandSphere: ModelEntity?
        var leftHandEntity: Entity?
        var rightHandEntity: Entity?
        
        for entity in handEntities {
            guard var handComponent = entity.components[HandTrackingComponent.self] else { continue }
            
            // If we haven't created the finger joint spheres yet, do so once.
            if handComponent.fingers.isEmpty {
                addJoints(to: entity, handComponent: &handComponent)
            }
            
            // Find the relevant HandAnchor (left or right).
            guard let handAnchor: HandAnchor = {
                switch handComponent.chirality {
                case .left:  return Self.latestLeftHand
                case .right: return Self.latestRightHand
                default:     return nil
                }
            }() else {
                continue
            }
            
            // If the skeleton is available, update everything
            if let handSkeleton = handAnchor.handSkeleton {
                updateJointPositions(handSkeleton: handSkeleton, handComponent: &handComponent, handAnchor: handAnchor)
                
                // Identify pinch location between thumb and index
                let (thumbPos, indexPos) = getThumbAndIndexPositions(handSkeleton: handSkeleton)
                let (thumbWorldPos, indexWorldPos) = getWorldPositions(thumbPos: thumbPos, indexPos: indexPos, handAnchor: handAnchor)
                
                let distance = simd_distance(thumbPos, indexPos)
                let isPinching = distance < 0.03
                
                updateAppModel(handComponent: handComponent, isPinching: isPinching, thumbWorldPos: thumbWorldPos, indexWorldPos: indexWorldPos)
                
                let midpoint = (thumbWorldPos + indexWorldPos) * 0.5
                handlePinchSphere(
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
            
            // Store updated component
            entity.components.set(handComponent)
        }
    }
    
    // ----------------------------------------------------------------
    // 1) Create finger joint spheres if we haven't already
    // ----------------------------------------------------------------
    
    func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
        let radius: Float = 0.005
        let material = SimpleMaterial(color: .white, isMetallic: false)
        
        let sphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )
        
        // Add a small sphere for each joint
        for (jointName, finger, _) in Hand.joints {
            let newJoint = sphereEntity.clone(recursive: false)
            handEntity.addChild(newJoint)
            handComponent.fingers[jointName] = newJoint
        }
        
        handEntity.components.set(handComponent)
        print("Finished adding joints")
    }
    
    // ----------------------------------------------------------------
    // 2) Update the joints & cylinders each frame
    // ----------------------------------------------------------------
    
    private func updateJointPositions(
        handSkeleton: HandSkeleton,
        handComponent: inout HandTrackingComponent,
        handAnchor: HandAnchor
    ) {
        // Update each joint's transform in world space
        for (jointName, jointEntity) in handComponent.fingers {
            let anchorFromJointTransform = handSkeleton.joint(jointName).anchorFromJointTransform
            jointEntity.setTransformMatrix(
                handAnchor.originFromAnchorTransform * anchorFromJointTransform,
                relativeTo: nil
            )
        }
        
        // If we haven't created cylinders yet, do it once
        if handComponent.cylinders.isEmpty {
            createCylinders(handComponent: &handComponent, handSkeleton: handSkeleton)
        }
    }
    
    // ----------------------------------------------------------------
    // (A) Create cylinders once for each consecutive joint pair
    // ----------------------------------------------------------------
    
    private func createCylinders(handComponent: inout HandTrackingComponent, handSkeleton: HandSkeleton) {
        for joint in HandSkeleton.JointName.allCases {
            // Skip wrist and forearm joints as they don't have parent joints
            if joint == .wrist || joint == .forearmWrist || joint == .forearmArm {
                continue
            }
            
            let skeletonJoint = handSkeleton.joint(joint)
            guard let parentJoint = skeletonJoint.parentJoint else { continue }
            
            // Get the transform from the joint to its parent in local space
            let parentFromJointTransform = skeletonJoint.parentFromJointTransform
            
            // Extract position from the transform
            let position = SIMD3<Float>(
                parentFromJointTransform.columns.3.x,
                parentFromJointTransform.columns.3.y,
                parentFromJointTransform.columns.3.z
            )
            
            // Calculate the distance between joints
            let distance = simd_length(position)
            
            // Create cylinder with correct transform
            let cylinderMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let cylinderModel = ModelEntity(
                mesh: .generateCylinder(height: 1.0, radius: 0.002),
                materials: [cylinderMaterial]
            )
            
            // Create a holder entity to manage the cylinder's transform
            let holder = Entity()
            
            // Position the holder at the parent joint
            holder.position = .zero
            
            // Orient the holder to point from parent to child joint
            holder.look(at: position, from: .zero, relativeTo: nil)
            
            // Add the cylinder to the holder
            let rotationAngle: Float = handComponent.chirality == .left ? -.pi / 2 : .pi / 2
            cylinderModel.transform = Transform(
                scale: [1, distance, 1],
                rotation: simd_quatf(angle: rotationAngle, axis: [1, 0, 0]), // Rotate to align with Y axis
                translation: [0, 0, -distance * 0.5] // Offset by half the length in local space
            )
            holder.addChild(cylinderModel)
            
            // Add the holder to the parent joint
            if let parentJointEntity = handComponent.fingers[parentJoint.name] {
                parentJointEntity.addChild(holder)
                handComponent.cylinders[joint] = cylinderModel
            }
        }
    }
    
    // ----------------------------------------------------------------
    // Thumb & Index pinch logic
    // ----------------------------------------------------------------
    
    private func getThumbAndIndexPositions(
        handSkeleton: HandSkeleton
    ) -> (thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>) {
        let thumbTip = handSkeleton.joint(.thumbTip)
        let indexTip = handSkeleton.joint(.indexFingerTip)
        
        let thumbPosition = thumbTip.anchorFromJointTransform.columns.3
        let indexPosition = indexTip.anchorFromJointTransform.columns.3
        
        return (
            SIMD3<Float>(thumbPosition.x, thumbPosition.y, thumbPosition.z),
            SIMD3<Float>(indexPosition.x, indexPosition.y, indexPosition.z)
        )
    }
    
    private func getWorldPositions(
        thumbPos: SIMD3<Float>,
        indexPos: SIMD3<Float>,
        handAnchor: HandAnchor
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        let thumb4 = SIMD4<Float>(thumbPos.x, thumbPos.y, thumbPos.z, 1)
        let index4 = SIMD4<Float>(indexPos.x, indexPos.y, indexPos.z, 1)
        
        let thumbWorld = handAnchor.originFromAnchorTransform * thumb4
        let indexWorld = handAnchor.originFromAnchorTransform * index4
        
        return (
            SIMD3<Float>(thumbWorld.x, thumbWorld.y, thumbWorld.z),
            SIMD3<Float>(indexWorld.x, indexWorld.y, indexWorld.z)
        )
    }
    
    @MainActor
    private func updateAppModel(
        handComponent: HandTrackingComponent,
        isPinching: Bool,
        thumbWorldPos: SIMD3<Float>,
        indexWorldPos: SIMD3<Float>
    ) {
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
                // Create a ring (circle with a hole)
                let circlePath = Path { path in
                    path.addArc(center: .zero, radius: 0.04,
                                startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
                    path.addArc(center: .zero, radius: 0.03,
                                startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                }
                
                var extrusionOptions = MeshResource.ShapeExtrusionOptions()
                extrusionOptions.extrusionMethod = .linear(depth: 0.005)
                extrusionOptions.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: 32)
                
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: .blue)
                material.emissiveColor = .init(color: .blue)
                material.emissiveIntensity = 1.0
                
                let circle = ModelEntity(
                    mesh: try! MeshResource(extruding: circlePath, extrusionOptions: extrusionOptions),
                    materials: [material]
                )
                
                entity.addChild(circle)
                handComponent.pinchSphere = circle
            }
            
            if let circle = handComponent.pinchSphere {
                circle.position = midpoint
                if handComponent.chirality == .left {
                    leftHandSphere = circle
                    leftHandEntity = entity
                } else {
                    rightHandSphere = circle
                    rightHandEntity = entity
                }
            }
        } else {
            // Remove the ring when not pinching
            if let circle = handComponent.pinchSphere {
                circle.removeFromParent()
                handComponent.pinchSphere = nil
            }
        }
    }
}
