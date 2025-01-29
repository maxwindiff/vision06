/*
 See the LICENSE.txt file for this sample’s licensing information.
 */
import RealityKit
import Foundation
import simd

class CurveExtruder {
  private var lowLevelMesh: LowLevelMesh?

  let shape: [SIMD2<Float>]
  let radius: Float
  let topology: [UInt32]

  private(set) var samples: [CurveSample] = []
  private var materializedSampleCount: Int = 0

  @MainActor
  private var sampleCapacity: Int {
    let vertexCapacity = lowLevelMesh?.vertexCapacity ?? 0
    let indexCapacity = lowLevelMesh?.indexCapacity ?? 0
    let sampleVertexCapacity = vertexCapacity / shape.count
    let sampleIndexCapacity = indexCapacity / topology.count + 1
    return min(sampleVertexCapacity, sampleIndexCapacity)
  }

  @MainActor
  private func reallocateMeshIfNeeded(lastSampleIndex: Int) throws -> Bool {
    // If more than 75% of the samples have faded out, just copy the most recent samples to the start of the array.
    if let lowLevelMesh, Float(lastSampleIndex) / Float(sampleCapacity) > 0.75 {
      samples = Array(samples[lastSampleIndex..<samples.count])
      materializedSampleCount -= lastSampleIndex
      lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
        let startVertexByte = lastSampleIndex * shape.count * MemoryLayout<TrailVertex>.stride
        let vertexBytes = samples.count * shape.count * MemoryLayout<TrailVertex>.stride
        // move `vertexBytes` bytes from `startVertexBytes` to the beginning of the buffer
        buffer.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: startVertexByte), count: vertexBytes))
      }
      return false
    }

    guard samples.count > sampleCapacity else {
      // No need to reallocate if `sampleCapacity` is small enough.
      return false
    }

    // Double the sample capacity each time a reallocation is needed.
    var newSampleCapacity = max(sampleCapacity, 1024)
    while newSampleCapacity < samples.count {
      newSampleCapacity *= 2
    }

    // `shape` is instantiated at each sample.
    let newVertexCapacity = newSampleCapacity * shape.count

    // Each segment between two samples adds a triangle fan, which has `topology.count` indices.
    let triangleFanCapacity = newSampleCapacity - 1
    let newIndexCapacity = triangleFanCapacity * topology.count

    let newMesh = try Self.makeLowLevelMesh(vertexCapacity: newVertexCapacity, indexCapacity: newIndexCapacity)

    // The topology is fixed, so you only need to write to the index buffer once.
    newMesh.withUnsafeMutableIndices { buffer in
      // Fill the index buffer with `triangleFanCapacity` copies of the array `topology` offset for each sample.
      let typedBuffer = buffer.bindMemory(to: UInt32.self)
      for fanIndex in 0..<triangleFanCapacity {
        for vertexIndex in 0..<topology.count {
          let bufferIndex = vertexIndex + topology.count * fanIndex
          if topology[vertexIndex] == UInt32.max {
            typedBuffer[bufferIndex] = UInt32.max
          } else {
            typedBuffer[bufferIndex] = topology[vertexIndex] + UInt32(shape.count * fanIndex)
          }
        }
      }
    }

    if let lowLevelMesh {
      // Copy the vertex buffer from the old mesh to the new one.
      lowLevelMesh.withUnsafeBytes(bufferIndex: 0) { oldBuffer in
        newMesh.withUnsafeMutableBytes(bufferIndex: 0) { newBuffer in
          newBuffer.copyMemory(from: oldBuffer)
        }
      }
      newMesh.parts = lowLevelMesh.parts
    }

    lowLevelMesh = newMesh

    return true
  }

  @MainActor
  private static func makeLowLevelMesh(vertexCapacity: Int, indexCapacity: Int) throws -> LowLevelMesh {
    var descriptor = TrailVertex.descriptor
    descriptor.vertexCapacity = vertexCapacity
    descriptor.indexCapacity = indexCapacity
    return try LowLevelMesh(descriptor: descriptor)
  }

  init(shape: [SIMD2<Float>], radius: Float) {
    self.shape = shape
    self.radius = radius

    // Triangle fan lists each vertex in `shape` once for each ring, except for vertex `0` of `shape` which
    // is listed twice. Plus one extra index for the end-index (0xFFFFFFFF).
    let indexCountPerFan = 2 * (shape.count + 1) + 1

    var topology: [UInt32] = []
    topology.reserveCapacity(indexCountPerFan)

    // Build triangle fan.
    for vertexIndex in shape.indices.reversed() {
      topology.append(UInt32(vertexIndex))
      topology.append(UInt32(shape.count + vertexIndex))
    }

    // Wrap around to the first vertex.
    topology.append(UInt32(shape.count - 1))
    topology.append(UInt32(2 * shape.count - 1))

    // Add end-index.
    topology.append(UInt32.max)
    assert(topology.count == indexCountPerFan)

    self.topology = topology
  }

  func append<S: Sequence>(samples: S) where S.Element == CurveSample {
    self.samples.append(contentsOf: samples)
  }

  func removeLast(sampleCount: Int) {
    samples.removeLast(sampleCount)
    materializedSampleCount = min(materializedSampleCount, max(samples.count - 1, 0))
  }

  @MainActor
  func update(elapsed: Float) throws -> LowLevelMesh? {
    var startSample = samples.firstIndex { elapsed - $0.point.timeAdded < 1.0 } ?? 0
    let didReallocate = try reallocateMeshIfNeeded(lastSampleIndex: startSample)
    startSample = samples.firstIndex { elapsed - $0.point.timeAdded < 1.0 } ?? 0

    if materializedSampleCount != samples.count, let lowLevelMesh {
      if materializedSampleCount < samples.count {
        lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBuffer in
          let vertexBuffer = rawBuffer.bindMemory(to: TrailVertex.self)
          updateVertexBuffer(vertexBuffer)
        }
      }

      lowLevelMesh.parts.removeAll()
      if samples.count > 1 {
        let triangleFanCount = samples.count - 1 - startSample
        let bounds = BoundingBox(min: [-100, -100, -100], max: [100, 100, 100])
        let part = LowLevelMesh.Part(indexOffset: startSample * topology.count * MemoryLayout<UInt32>.stride,
                                     indexCount: triangleFanCount * topology.count,
                                     topology: .triangleStrip,
                                     materialIndex: 0,
                                     bounds: bounds)
        lowLevelMesh.parts.append(part)
      }
    }

    // Update timeline of all vertices
    if let lowLevelMesh {
      lowLevelMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
        let vertexBuffer = buffer.bindMemory(to: TrailVertex.self)
        for i in startSample..<samples.count {
          for j in 0..<shape.count {
            vertexBuffer[i * shape.count + j].timeline.y = elapsed
          }
        }
      }
    }

    return didReallocate ? lowLevelMesh : nil
  }

  private func updateVertexBuffer(_ vertexBuffer: UnsafeMutableBufferPointer<TrailVertex>) {
    guard materializedSampleCount < samples.count else { return }

    for sampleIndex in materializedSampleCount..<samples.count {
      let sample = samples[sampleIndex]

      for shapeVertexIndex in 0..<shape.count {
        var vertex = TrailVertex()

        // Use the rotation frame of `sample` to compute the 3D position of this vertex.
        let position2d = shape[shapeVertexIndex] * radius
        vertex.position = sample.rotationFrame * SIMD3<Float>(position2d, 0) + sample.point.position

        // To compute the 3D bitangent, take the tangent of the shape in 2D
        // and orient with respect to the rotation frame of `sample`.
        let nextShapeIndex = (shapeVertexIndex + 1) % shape.count
        let prevShapeIndex = (shapeVertexIndex + shape.count - 1) % shape.count
        let bitangent2d = simd_normalize(shape[nextShapeIndex] - shape[prevShapeIndex])
        vertex.bitangent = sample.rotationFrame * SIMD3<Float>(bitangent2d, 0)

        vertex.normal = sample.rotationFrame * SIMD3<Float>(bitangent2d.y, -bitangent2d.x, 0)
        vertex.timeline = SIMD2<Float>(sample.point.timeAdded, 0)
        vertex.curveDistance = sample.curveDistance

        // Verify: This mesh generator should never output NaN.
        assert(any(isnan(vertex.position) .== 0))
        assert(any(isnan(vertex.bitangent) .== 0))
        assert(any(isnan(vertex.normal) .== 0))

        vertexBuffer[sampleIndex * shape.count + shapeVertexIndex] = vertex
      }
    }
    materializedSampleCount = samples.count
  }
}
