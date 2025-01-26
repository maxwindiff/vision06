import Foundation
import RealityKit
import RealityKitContent

public struct Trail {
  let startDate: Date
  var lastPoint: SIMD3<Float> = .zero
  var smoothCurveSampler: SmoothCurveSampler

  public struct Point {
    var position: SIMD3<Float>
    var timeAdded: Float
  }

  @MainActor
  init(rootEntity: Entity) async {
    startDate = Date.now

    let extruder = CurveExtruder(shape: makeCircle(radius: 1, segmentCount: Int(10)))
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, extruder: extruder)

    var material: RealityKit.Material = SimpleMaterial()
    if let shaderMaterial = try? await ShaderGraphMaterial(named: "/Root/Material",
                                                           from: "FluxMaterial",
                                                           in: realityKitContentBundle) {
      print("Loaded material")
      material = shaderMaterial
    }

    let solidMeshEntity = Entity()
    solidMeshEntity.position = .zero
    solidMeshEntity.components.set(SolidBrushComponent(extruder: extruder, material: material, startDate: startDate))
    rootEntity.addChild(solidMeshEntity)
  }

  @MainActor
  mutating func receive(input: SIMD3<Float>) {
    if distance(lastPoint, input) < 0.001 {
      return
    }
    lastPoint = input

    let timeAdded = Float(Date.now.timeIntervalSince(startDate))
    smoothCurveSampler.trace(point: Point(position: input, timeAdded: timeAdded))
  }
}
