import Collections
import Foundation
import RealityKit

public struct Trail {
  let rootEntity: Entity
  var solidMeshGenerator: SolidDrawingMeshGenerator
  var smoothCurveSampler: SmoothCurveSampler
  var inputsOverTime: Deque<(SIMD3<Float>, TimeInterval)> = []

  @MainActor
  init(rootEntity: Entity) async {
    self.rootEntity = rootEntity

    let solidMeshEntity = Entity()
    rootEntity.addChild(solidMeshEntity)
    solidMeshGenerator = SolidDrawingMeshGenerator(rootEntity: solidMeshEntity,
                                                   material: SimpleMaterial())
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, generator: solidMeshGenerator)
  }

  @MainActor
  mutating func receive(input: SIMD3<Float>, time: TimeInterval) {
    // Remove old entries from deque, insert current position if changed.
    while let (_, headTime) = inputsOverTime.first, time - headTime > 0.1 {
      inputsOverTime.removeFirst()
    }
    let lastInputPosition = inputsOverTime.last?.0
    inputsOverTime.append((input, time))
    if let lastInputPosition, lastInputPosition == input {
      return
    }
    // TODO: maybe remove minor movements?

    smoothCurveSampler.trace(point: input)
  }
}
