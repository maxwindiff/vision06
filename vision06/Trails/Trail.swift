import Foundation
import RealityKit
import RealityKitContent

class TrailComponent: Component {
  var trail: Trail

  init(trail: Trail) {
    self.trail = trail
  }
}

class TrailSystem: System {
  private static let query = EntityQuery(where: .has(TrailComponent.self))

  required init(scene: RealityKit.Scene) { }

  func update(context: SceneUpdateContext) {
    for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
      let trail = entity.components[TrailComponent.self]!.trail

      trail.updateInput()
      if let (newTrail, newBloom) = try? trail.updateMesh() {
        if let resource = try? MeshResource(from: newTrail) {
          if entity.components.has(ModelComponent.self) {
            entity.components[ModelComponent.self]!.mesh = resource
          } else {
            let modelComponent = ModelComponent(mesh: resource, materials: [trail.trailMaterial])
            entity.components.set(modelComponent)
          }
        }

        if let resource = try? MeshResource(from: newBloom) {
          let child = entity.children[0]
          if child.components.has(ModelComponent.self) {
            child.components[ModelComponent.self]!.mesh = resource
          } else {
            let modelComponent = ModelComponent(mesh: resource, materials: [trail.bloomMaterial])
            child.components.set(modelComponent)
          }
        }
      }
    }
  }
}

public class Trail {
  let rightFingerTip = AnchorEntity(.hand(.right, location: .indexFingerTip))
  let startDate: Date
  var lastPoint: SIMD3<Float> = .zero
  var count: Int = 0

  var extruder: CurveExtruder
  var smoothCurveSampler: SmoothCurveSampler
  var trailMaterial: ShaderGraphMaterial
  var bloomMaterial: ShaderGraphMaterial

  public struct Point {
    var position: SIMD3<Float>
    var timeAdded: Float
  }

  @MainActor
  init(rootEntity: Entity) async throws {
    // Input
    startDate = Date.now
    rootEntity.addChild(rightFingerTip)

    // Output
    extruder = CurveExtruder(shape: makeCircle(radius: 1, segmentCount: Int(4)), radius: 0.0001, fadeTime: 0.5)
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, extruder: extruder)
    trailMaterial = try await ShaderGraphMaterial(named: "/Root/CoreMaterial",
                                                   from: "Materials",
                                                   in: realityKitContentBundle)
    try trailMaterial.setParameter(name: "FadeOutBegin", value: .float(0.25))
    try trailMaterial.setParameter(name: "FadeOutComplete", value: .float(0.5))
    bloomMaterial = try await ShaderGraphMaterial(named: "/Root/BloomMaterial",
                                                   from: "Materials",
                                                   in: realityKitContentBundle)
    try bloomMaterial.setParameter(name: "FadeOutBegin", value: .float(0.25))
    try bloomMaterial.setParameter(name: "FadeOutComplete", value: .float(0.5))
    try bloomMaterial.setParameter(name: "Width", value: .float(0.005))

    let trailEntity = Entity()
    trailEntity.position = .zero
    trailEntity.components.set(TrailComponent(trail: self))
    let bloomEntity = Entity()
    bloomEntity.position = .zero
    trailEntity.addChild(bloomEntity)
    rootEntity.addChild(trailEntity)
  }

  @MainActor
  func updateInput() {
    count += 1
    // if count > 1000 { return } // for debugging

    let input = rightFingerTip.position(relativeTo: nil)
    if input.x == 0 && input.y == 0 {
      // Sometimes the position reports (0, 0, something) at startup, ignore it.
      return
    }
    if distance(lastPoint, input) < 0.0001 {
      return
    }
    lastPoint = input

    let timeAdded = Float(Date.now.timeIntervalSince(startDate))
    smoothCurveSampler.trace(point: Point(position: input, timeAdded: timeAdded))
  }

  @MainActor
  func updateMesh() throws -> (LowLevelMesh, LowLevelMesh)? {
    return try extruder.update(elapsed: Float(Date.now.timeIntervalSince(startDate)))
  }
}
