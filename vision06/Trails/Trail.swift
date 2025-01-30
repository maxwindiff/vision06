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

  var extruder: CurveExtruder
  var smoothCurveSampler: SmoothCurveSampler
  var trailMaterial: RealityKit.Material
  var bloomMaterial: RealityKit.Material

  public struct Point {
    var position: SIMD3<Float>
    var timeAdded: Float
  }

  @MainActor
  init(rootEntity: Entity) async {
    // Input
    startDate = Date.now
    rootEntity.addChild(rightFingerTip)

    // Output
    extruder = CurveExtruder(shape: makeCircle(radius: 1, segmentCount: Int(8)), radius: 0.001)
    smoothCurveSampler = SmoothCurveSampler(flatness: 0.001, extruder: extruder)
    trailMaterial = try! await ShaderGraphMaterial(named: "/Root/Material",
                                                   from: "FluxMaterial",
                                                   in: realityKitContentBundle)
    bloomMaterial = try! await ShaderGraphMaterial(named: "/Root/Material",
                                                   from: "BloomMaterial",
                                                   in: realityKitContentBundle)

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
