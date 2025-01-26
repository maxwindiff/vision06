/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A RealityKit component and system to facilitate the generation of solid brush strokes.
*/

import RealityKit

struct SolidBrushComponent: Component {
    var extruder: CurveExtruder
    var material: RealityKit.Material
    var startDate: Date
}

class SolidBrushSystem: System {
    private static let query = EntityQuery(where: .has(SolidBrushComponent.self))
    
    required init(scene: RealityKit.Scene) { }
    
    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            let brushComponent: SolidBrushComponent = entity.components[SolidBrushComponent.self]!

            // Call `update` on the generator.
            // This returns a non-nil `LowLevelMesh` if a new mesh had to be allocated.
            // This can happen when the number of samples exceeds the capacity of the mesh.
            //
            // If the generator returns a new `LowLevelMesh`,
            // apply it to the entity's `ModelComponent`.
            let elapsed = Float(Date.now.timeIntervalSince(brushComponent.startDate))
            if let newMesh = try? brushComponent.extruder.update(elapsed: elapsed),
               let resource = try? MeshResource(from: newMesh) {
                if entity.components.has(ModelComponent.self) {
                    entity.components[ModelComponent.self]!.mesh = resource
                } else {
                    let modelComponent = ModelComponent(mesh: resource, materials: [brushComponent.material])
                    entity.components.set(modelComponent)
                }
            }
        }
    }
}
