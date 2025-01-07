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

  @State var leftHand: HandSkeletonView?
  @State var rightHand: HandSkeletonView?

  var dragGesture: some Gesture {
    DragGesture()
      .targetedToAnyEntity()
      .useGestureComponent()
  }

  var body: some View {
    RealityView { content, attachments in
      leftHand = HandSkeletonView(jointColor: .red, connectionColor: .red.withAlphaComponent(0.5))
      rightHand = HandSkeletonView(jointColor: .blue, connectionColor: .blue.withAlphaComponent(0.5))
      content.add(leftHand!)
      content.add(rightHand!)

      if let entity = attachments.entity(for: "ButtonView") {
        content.add(entity)
        entity.look(at: [0.4, 0.8, -1], from: [0.2, 0.9, -0.5], relativeTo: nil)
        print(entity.transform)

        entity.components.set(GestureComponent())
        entity.components.set(InputTargetComponent())
        let size = entity.attachment.bounds.extents
        let mesh = MeshResource.generatePlane(width: size.x, height: size.y)
        entity.components.set(CollisionComponent(shapes: [ShapeResource.generateConvex(from: mesh)]))
      }
    } update: { content, attachments in
    } attachments: {
      Attachment(id: "ButtonView") {
        ButtonView(size: 100)
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
          guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else { continue }
          updateHand(device: deviceAnchor, hand: update.anchor)
        }
      }
    }
    .simultaneousGesture(dragGesture)
  }

  func updateHand(device: DeviceAnchor, hand: HandAnchor) {
    if hand.chirality == .left {
      leftHand?.updateHandSkeleton(with: hand)
    } else {
      rightHand?.updateHandSkeleton(with: hand)
    }
  }
}

#Preview(immersionStyle: .mixed) {
  ImmersiveView()
    .environment(AppModel())
}
