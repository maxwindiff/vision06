import Accelerate
import ARKit
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
  @Environment(AppModel.self) private var appModel

  let session = ARKitSession()
  let worldTracking = WorldTrackingProvider()
  let handTracking = HandTrackingProvider()
  let headAnchor = AnchorEntity(.head)

  @State var sphere: ModelEntity?  // for debugging
  @State var buttonEntity: ViewAttachmentEntity?
  @State var buttonProjection: SIMD3<Float> = [0, 0, 1]

  let trailContent = Entity()
  @State var trail: Trail?

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
      SolidBrushSystem.registerSystem()
      SolidBrushComponent.registerComponent()
      content.add(trailContent)
      trail = await Trail(rootEntity: trailContent)
    } update: { content, attachments in
    } attachments: {
      Attachment(id: "ButtonView") {
        ButtonView(size: 100, finger: buttonProjection)
      }
    }
    .task {
      do {
        try await session.run([worldTracking, handTracking])
      } catch {
        print("ARKitSession error:", error)
      }
    }
    .task {
      for await update in handTracking.anchorUpdates {
        if update.event == .updated {
          if update.anchor.chirality == .right {
            let finger = Transform(matrix: update.anchor.originFromAnchorTransform *
                                   update.anchor.handSkeleton!.joint(.indexFingerTip).anchorFromJointTransform).translation
            trail?.receive(input: [finger.x, finger.y, finger.z])
//            if let buttonEntity {
//              // Project fingertip coordinates onto the button surface
//              buttonProjection = (buttonEntity.transform.matrix.inverse * SIMD4<Float>(finger.x, finger.y, finger.z, 1)).xyz
//              buttonProjection.x = buttonProjection.x / buttonEntity.attachment.bounds.extents.x + 0.5
//              buttonProjection.y = -buttonProjection.y  / buttonEntity.attachment.bounds.extents.y + 0.5
//            }
          }
        }
      }
    }
    .simultaneousGesture(dragGesture)
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
