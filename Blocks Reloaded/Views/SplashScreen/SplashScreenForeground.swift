/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Functions and SwiftUI views to build the foreground of the splash screen.
  The foreground contains a logotype and a logomark.
  The logotype is 3D text of "RealityKit Drawing App".
  The logomark is a customized 3D shape.
*/

import SwiftUI
import RealityKit
import RealityKitContent

/// Material used for the front face of the logomark.
@MainActor private let logomarkMaterial: PhysicallyBasedMaterial = {
    var frontMaterial = PhysicallyBasedMaterial()
    frontMaterial.metallic = .init(floatLiteral: 0.9)
    frontMaterial.roughness = .init(floatLiteral: 0.1)
    frontMaterial.baseColor = .init(tint: #colorLiteral(red: 0.9874247096, green: 0.245482568, blue: 1, alpha: 1))
    frontMaterial.emissiveColor = .init(color: #colorLiteral(red: 0.9952252516, green: 0.7135150935, blue: 1, alpha: 1))
    frontMaterial.emissiveIntensity = 0.7
    frontMaterial.clearcoat = .init(floatLiteral: 0.9)
    return frontMaterial
}()

/// Material used for the sides of the meshes on the splash screen.
@MainActor private let borderMaterial: PhysicallyBasedMaterial = {
    var borderMaterial = PhysicallyBasedMaterial()
    borderMaterial.metallic = .init(floatLiteral: 0.15)
    borderMaterial.roughness = .init(floatLiteral: 0.85)
    borderMaterial.baseColor = .init(tint: #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
    return borderMaterial
}()

/// Errors related to generation of the foreground.
private enum ForegroundViewError: Error {
    case cannotFindFont
}

/// Creates the `ModelEntity` for the 3D text "RealityKit Drawing App" in a customized layout and font.
@MainActor private func makeTextEntity() async throws -> ModelEntity {
    // Create an `AttributedString`, `"RealityKit"`.
    var textString = AttributedString("Blocks")
    
    // Set the font to 8 pt.
    textString.font = .systemFont(ofSize: 8.0)
    
    // Load a font for the text "Drawing App".
    guard let drawingAppFont = UIFont(name: "ArialRoundedMTBold", size: 14.0) else {
        throw ForegroundViewError.cannotFindFont
    }
    
    // Create an `AttributedString`, `"Drawing App"`, with the loaded font.
    let attributes = AttributeContainer([.font: drawingAppFont])
    textString.append(AttributedString("\nReloaded", attributes: attributes))
    
    // Center the text.
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    textString.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
    
    // Define the container frame of the text.
    var textOptions = MeshResource.GenerateTextOptions()
    textOptions.containerFrame = CGRect(x: 0, y: 0, width: 100, height: 50)
    
    var extrusionOptions = MeshResource.ShapeExtrusionOptions()
    
    // Set the extrusion depth to 2 pt.
    extrusionOptions.extrusionMethod = .linear(depth: 2)
    
    // Set a different material for the sides of the mesh.
    extrusionOptions.materialAssignment = .init(front: 0, back: 0, extrusion: 1, frontChamfer: 1, backChamfer: 1)
    
    // Set the chamfer radius to 0.1 pt.
    extrusionOptions.chamferRadius = 0.1
    
    // Generate the mesh.
    let textMesh = try await MeshResource(extruding: textString,
                                          textOptions: textOptions,
                                          extrusionOptions: extrusionOptions)
    return ModelEntity(mesh: textMesh, materials: [SimpleMaterial(), borderMaterial])
}

/// Creates the `ModelEntity` for the 3D logomark.
@MainActor private func makeGraphicEntity() async throws -> Entity {
    // Create a cube entity from the GlowCube scene
    guard let cube = try? await Entity.init(named: "GlowCube", in: realityKitContentBundle) else {
        return Entity()
    }
    cube.scale = SIMD3(x: 0.5, y: 0.5, z: 0.5)
    cube.position = SIMD3(x: 0, y: 0, z: 0.1)
    cube.components.set(HoverEffectComponent())
    return cube
}

private extension Entity {
    /// Move and scale the entity such that the bounds of `ModelComponent` fills the provided `proxy`.
    func scaleToFit(proxy: GeometryProxy3D, content: RealityViewContent) {
        guard let model = components[ModelComponent.self] else { return }
        
        let frame = proxy.frame(in: .local)
        let frameSize = abs(content.convert(frame.size, from: .local, to: .scene))
        
        let bounds = model.mesh.bounds
        let extents = bounds.extents
        let center = bounds.center
        
        let graphicScale = min(frameSize.x / extents.x, frameSize.y / extents.y)
        scale = SIMD3<Float>(repeating: graphicScale)
        position = SIMD3<Float>(0, 0, -frameSize.z)
        position -= center * graphicScale
    }
}

/// A view that displays a provided `ModelEntity`, scaled to fit the view's bounds.
struct ModelEntityFillView: View {
    /// Build the `ModelEntity` to display.
    let make: @MainActor @Sendable () async throws -> Entity
    
    var body: some View {
        GeometryReader3D { proxy in
            RealityView { content in
                if let modelEntity = try? await make() {
                    modelEntity.scaleToFit(proxy: proxy, content: content)
                    content.add(modelEntity)
                }
            } update: { content in
                for entity in content.entities {
                    entity.scaleToFit(proxy: proxy, content: content)
                }
            }
        }
    }
}

/// A view that's used for the foreground of the app's splash screen.
///
/// It displays 3D text of "RealityKit Drawing App" in a customized font, and a logomark.
struct SplashScreenForegroundView: View {
    var body: some View {
        VStack {
            ModelEntityFillView {
                try await makeTextEntity()
            }
            .frame(idealHeight: 300)
            
            Spacer(minLength: 30)
            
            ModelEntityFillView {
                try await makeGraphicEntity()
            }
            .frame(idealHeight: 50)
        }
        .frame(depth: 0)
    }
}
