import SwiftUI

@main
struct vision06App: App {
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @State private var appModel = AppModel()

  init() {
    GestureComponent.registerComponent()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(appModel)
        .task {
          await openImmersiveSpace(id: appModel.immersiveSpaceID)
        }
    }
    .defaultSize(width: 400, height: 400)

    ImmersiveSpace(id: appModel.immersiveSpaceID) {
      ImmersiveView()
        .environment(appModel)
        .onAppear {
          appModel.immersiveSpaceState = .open
        }
        .onDisappear {
          appModel.immersiveSpaceState = .closed
        }
        .persistentSystemOverlays(.hidden)
    }
    .immersionStyle(selection: .constant(.mixed), in: .mixed)
  }
}
