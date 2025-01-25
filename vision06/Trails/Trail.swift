import Collections
import Foundation
import RealityKit

public struct Trail {
  var smoothCurveSampler: SmoothCurveSampler

  public struct Point {
    var position: SIMD3<Float>
    var timeAdded: Float
  }

  @MainActor
  init(rootEntity: Entity) async {
    let curveExtruder = CurveExtruder(shape: makeCircle(radius: 1, segmentCount: Int(32)))
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, extruder: curveExtruder)

    let solidMeshEntity = Entity()
    rootEntity.addChild(solidMeshEntity)
    solidMeshEntity.position = .zero
    solidMeshEntity.components.set(SolidBrushComponent(extruder: curveExtruder, material: SimpleMaterial()))
  }

  @MainActor
  mutating func receive(input: SIMD3<Float>, time: TimeInterval) {
    smoothCurveSampler.trace(point: Point(position: input, timeAdded: Float(time)))
  }
}
