import Collections
import Foundation
import RealityKit

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

    let curveExtruder = CurveExtruder(shape: makeCircle(radius: 1, segmentCount: Int(10)))
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, extruder: curveExtruder)

    let solidMeshEntity = Entity()
    solidMeshEntity.position = .zero
    solidMeshEntity.components
      .set(SolidBrushComponent(extruder: curveExtruder, material: SimpleMaterial(), startDate: startDate))
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
