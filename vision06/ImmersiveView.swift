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

  var body: some View {
    RealityView { content in
      leftHand = HandSkeletonView(jointColor: .red, connectionColor: .red.withAlphaComponent(0.5))
      rightHand = HandSkeletonView(jointColor: .blue, connectionColor: .blue.withAlphaComponent(0.5))
      content.add(leftHand!)
      content.add(rightHand!)
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
