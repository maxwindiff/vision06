import Foundation
import SwiftUI
import RealityKit
import Spatial

public class EntityGestureState {
  var targetedEntity: Entity?
  var dragStartPosition: SIMD3<Float> = .zero
  var isDragging = false
  var pivotEntity: Entity?
  var initialOrientation: simd_quatf?
  var startOrientation = Rotation3D.identity
  var isRotating = false
  static let shared = EntityGestureState()
}

public struct GestureComponent: Component, Codable {
  mutating func onChanged(value: EntityTargetValue<DragGesture.Value>) {
    let state = EntityGestureState.shared

    if state.targetedEntity == nil {
      state.targetedEntity = value.entity
      state.initialOrientation = value.entity.orientation(relativeTo: nil)
    }

    guard let entity = state.targetedEntity else { fatalError("Gesture contained no entity") }

    // The transform that the pivot will be moved to.
    var targetPivotTransform = Transform()

    // Set the target pivot transform depending on the input source.
    if let inputDevicePose = value.inputDevicePose3D {
      // If there is an input device pose, use it for positioning and rotating the pivot.
      targetPivotTransform.scale = .one
      targetPivotTransform.translation = value.convert(inputDevicePose.position, from: .local, to: .scene)
      targetPivotTransform.rotation = value.convert(AffineTransform3D(rotation: inputDevicePose.rotation), from: .local, to: .scene).rotation
    } else {
      // If there is not an input device pose, use the location of the drag for positioning the pivot.
      targetPivotTransform.translation = value.convert(value.location3D, from: .local, to: .scene)
    }

    if !state.isDragging {
      // If this drag just started, create the pivot entity.
      let pivotEntity = Entity()

      guard let parent = entity.parent else { fatalError("Non-root entity is missing a parent.") }

      // Add the pivot entity into the scene.
      parent.addChild(pivotEntity)

      // Move the pivot entity to the target transform.
      pivotEntity.move(to: targetPivotTransform, relativeTo: nil)

      // Add the targeted entity as a child of the pivot without changing the targeted entity's world transform.
      pivotEntity.addChild(entity, preservingWorldTransform: true)

      // Store the pivot entity.
      state.pivotEntity = pivotEntity

      // Indicate that a drag has started.
      state.isDragging = true
      print("Drag started, entity: \(entity.name) pivot: \(pivotEntity.name)")

    } else {
      // If this drag is ongoing, move the pivot entity to the target transform.
      // The animation duration smooths the noise in the target transform across frames.
      state.pivotEntity?.move(to: targetPivotTransform, relativeTo: nil, duration: 0.2)
    }
  }

  mutating func onEnded(value: EntityTargetValue<DragGesture.Value>) {
    let state = EntityGestureState.shared
    state.isDragging = false

    if let pivotEntity = state.pivotEntity {
      pivotEntity.parent!.addChild(state.targetedEntity!, preservingWorldTransform: true)
      pivotEntity.removeFromParent()
    }

    state.pivotEntity = nil
    state.targetedEntity = nil
  }
}

public extension Entity {
  var gestureComponent: GestureComponent? {
    get { components[GestureComponent.self] }
    set { components[GestureComponent.self] = newValue }
  }
}

public extension Gesture where Value == EntityTargetValue<DragGesture.Value> {
  func useGestureComponent() -> some Gesture {
    onChanged { value in
      guard var gestureComponent = value.entity.gestureComponent else { return }
      gestureComponent.onChanged(value: value)
      value.entity.components.set(gestureComponent)
    }
    .onEnded { value in
      guard var gestureComponent = value.entity.gestureComponent else { return }
      gestureComponent.onEnded(value: value)
      value.entity.components.set(gestureComponent)
    }
  }
}
