import Accelerate
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
  @Environment(AppModel.self) private var appModel

  let session = SpatialTrackingSession()

  @State var sphere: ModelEntity?  // for debugging
  @State var buttonEntity: ViewAttachmentEntity?
  @State var buttonProjection: SIMD3<Float> = [0, 0, 1]

  let palm = AnchorEntity(.hand(.right, location: .palm))
  let rightThumbTip = AnchorEntity(.hand(.right, location: .joint(for: .thumbTip)))
  let rightIndexFingerTip = AnchorEntity(.hand(.right, location: .joint(for: .indexFingerTip)))
  let rightMiddleFingerTip = AnchorEntity(.hand(.right, location: .joint(for: .middleFingerTip)))
  let rightRingFingerTip = AnchorEntity(.hand(.right, location: .joint(for: .ringFingerTip)))
  let rightLittleFingerTip = AnchorEntity(.hand(.right, location: .joint(for: .littleFingerTip)))
  let trailContent = Entity()
  @State var trails: [Trail] = []

  var dragGesture: some Gesture {
    DragGesture()
      .targetedToAnyEntity()
      .useGestureComponent()
  }

  var body: some View {
    RealityView { content, attachments in
      // Sphere for debugging
      let sphere = ModelEntity(mesh: .generateSphere(radius: 0.005),
                               materials: [SimpleMaterial(color: .yellow.withAlphaComponent(0), isMetallic: false)])
      content.add(sphere)
      self.sphere = sphere

      // Draggable button
      if let entity = attachments.entity(for: "ButtonView") {
        content.add(entity)
        entity.look(at: [0, 1.1, -1], from: [0, 1, -0.5], relativeTo: nil)

        entity.components.set(GestureComponent())
        entity.components.set(InputTargetComponent())
        let size = entity.attachment.bounds.extents
        let mesh = MeshResource.generatePlane(width: size.x, height: size.y)
        try! await entity.components.set(CollisionComponent(shapes: [ShapeResource.generateConvex(from: mesh)]))
        buttonEntity = entity
      }

      // Finger trails
      TrailSystem.registerSystem()
      TrailComponent.registerComponent()
      trailContent.addChild(palm)
      trailContent.addChild(rightThumbTip)
      trailContent.addChild(rightIndexFingerTip)
      trailContent.addChild(rightMiddleFingerTip)
      trailContent.addChild(rightRingFingerTip)
      trailContent.addChild(rightLittleFingerTip)
      content.add(trailContent)

      trails.append(try! await Trail(rootEntity: trailContent, palm: palm, anchor: rightThumbTip, color: SIMD3<Float>(0.5, 0.7, 0.5)))
      trails.append(try! await Trail(rootEntity: trailContent, palm: palm, anchor: rightIndexFingerTip, color: SIMD3<Float>(1, 0.6, 1)))
      trails.append(try! await Trail(rootEntity: trailContent, palm: palm, anchor: rightMiddleFingerTip, color: SIMD3<Float>(0.6, 0.8, 1.5)))
      trails.append(try! await Trail(rootEntity: trailContent, palm: palm, anchor: rightRingFingerTip, color: SIMD3<Float>(1.5, 0.7, 0.7)))
      trails.append(try! await Trail(rootEntity: trailContent, palm: palm, anchor: rightLittleFingerTip, color: SIMD3<Float>(1.2, 0.8, 0.5)))
    } update: { content, attachments in
    } attachments: {
      Attachment(id: "ButtonView") {
        ButtonView(size: 100, finger: buttonProjection)
      }
    }
    .task {
      _ = await session.run(SpatialTrackingSession.Configuration(tracking: [.hand, .world]))
//      if let buttonEntity {
//        // Project fingertip coordinates onto the button surface
//        buttonProjection = (buttonEntity.transform.matrix.inverse * SIMD4<Float>(finger.x, finger.y, finger.z, 1)).xyz
//        buttonProjection.x = buttonProjection.x / buttonEntity.attachment.bounds.extents.x + 0.5
//        buttonProjection.y = -buttonProjection.y  / buttonEntity.attachment.bounds.extents.y + 0.5
//      }
    }
    .simultaneousGesture(dragGesture)
    .onDisappear {
      trailContent.children.removeAll()
    }
  }
}

extension SIMD4<Float> {
  var xyz: SIMD3<Float> {
    SIMD3(x, y, z)
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
