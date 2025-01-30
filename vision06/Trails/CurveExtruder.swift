/*
 See the LICENSE.txt file for this sample’s licensing information.
 */
import RealityKit
import Foundation
import simd

class CurveExtruder {
  private var trailMesh: LowLevelMesh?
  private var bloomMesh: LowLevelMesh?

  let radius: Float
  let shape: [SIMD2<Float>]
  let topology: [UInt32]
  let bloomVertexCount = 2 // 2 vertices per sample
  let bloomIndexCount = 4 * 3 // 4 triangles per sample

  private(set) var samples: [CurveSample] = []
  private var materializedSampleCount: Int = 0

  @MainActor
  private var sampleCapacity: Int {
    let vertexCapacity = trailMesh?.vertexCapacity ?? 0
    let indexCapacity = trailMesh?.indexCapacity ?? 0
    let sampleVertexCapacity = vertexCapacity / shape.count
    let sampleIndexCapacity = indexCapacity / topology.count + 1
    return min(sampleVertexCapacity, sampleIndexCapacity)
  }

  @MainActor
  private static func copyVertexBuffer(_ src: LowLevelMesh, _ dst: LowLevelMesh) {
    dst.withUnsafeMutableBytes(bufferIndex: 0) { newBuffer in
      src.withUnsafeBytes(bufferIndex: 0) { oldBuffer in
        newBuffer.copyMemory(from: oldBuffer)
      }
    }
    dst.parts = src.parts
  }

  @MainActor
  private func reallocateMeshIfNeeded(lastSampleIndex: Int) throws -> (didReallocate: Bool, didCompact: Bool) {
    // If more than 75% of the samples have faded out, compact most recent samples to the start of the array.
    if Float(lastSampleIndex) / Float(sampleCapacity) > 0.75 {
      samples = Array(samples[lastSampleIndex..<samples.count])
      materializedSampleCount -= lastSampleIndex
      if let trailMesh {
        trailMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
          // Move `vertexBytes` bytes from `startVertexBytes` to the beginning of the buffer
          let startVertexByte = lastSampleIndex * shape.count * MemoryLayout<TrailVertex>.stride
          let vertexBytes = samples.count * shape.count * MemoryLayout<TrailVertex>.stride
          buffer.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: startVertexByte), count: vertexBytes))
        }
      }
      if let bloomMesh {
        bloomMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
          let startVertexByte = lastSampleIndex * bloomVertexCount * MemoryLayout<BloomVertex>.stride
          let vertexBytes = samples.count * bloomVertexCount * MemoryLayout<BloomVertex>.stride
          buffer.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: startVertexByte), count: vertexBytes))
        }
      }
      return (false, true)
    }

    // Some resizing logic
    guard samples.count > sampleCapacity else {
      return (false, false)
    }
    var newSampleCapacity = max(sampleCapacity, 1024)
    while newSampleCapacity < samples.count {
      newSampleCapacity *= 2
    }

    // Resize the trail
    var trailMeshDesc = TrailVertex.descriptor
    trailMeshDesc.vertexCapacity = newSampleCapacity * shape.count // one shape per sample
    trailMeshDesc.indexCapacity = (newSampleCapacity - 1) * topology.count // between every two samples
    let newTrailMesh = try LowLevelMesh(descriptor: trailMeshDesc)
    if let trailMesh {
      Self.copyVertexBuffer(trailMesh, newTrailMesh)
    }
    newTrailMesh.withUnsafeMutableIndices { buffer in
      // The topology is fixed, so you only need to write to the index buffer once.
      let indexBuffer = buffer.bindMemory(to: UInt32.self)
      for fanIndex in 0..<newSampleCapacity - 1 {
        for vertexIndex in 0..<topology.count {
          let bufferIndex = vertexIndex + topology.count * fanIndex
          if topology[vertexIndex] == UInt32.max {
            indexBuffer[bufferIndex] = UInt32.max
          } else {
            indexBuffer[bufferIndex] = topology[vertexIndex] + UInt32(shape.count * fanIndex)
          }
        }
      }
    }
    trailMesh = newTrailMesh

    // Resize the bloom
    var bloomMeshDesc = BloomVertex.descriptor
    bloomMeshDesc.vertexCapacity = newSampleCapacity * bloomVertexCount
    bloomMeshDesc.indexCapacity = (newSampleCapacity - 1) * bloomIndexCount // between every two samples
    let newBloomMesh = try LowLevelMesh(descriptor: bloomMeshDesc)
    if let bloomMesh {
      Self.copyVertexBuffer(bloomMesh, newBloomMesh)
    }
    newBloomMesh.withUnsafeMutableIndices { buffer in
      // The topology is fixed, so you only need to write to the index buffer once.
      let indexBuffer = buffer.bindMemory(to: UInt32.self)
      for fanIndex in 0..<newSampleCapacity - 1 {
        let baseIndex = fanIndex * bloomIndexCount
        let baseVertex = UInt32(fanIndex * bloomVertexCount)
        // 0 * ----- * 2 ...
        //   |    /  |
        //   |   /   |  newer =>
        //   |  /    |
        // 1 * ----- * 3 ...
        indexBuffer[baseIndex + 0] = baseVertex
        indexBuffer[baseIndex + 1] = baseVertex + 1
        indexBuffer[baseIndex + 2] = baseVertex + 2
        indexBuffer[baseIndex + 3] = baseVertex + 3
        indexBuffer[baseIndex + 4] = baseVertex + 2
        indexBuffer[baseIndex + 5] = baseVertex + 1
        for offset in 0..<6 {
          // Back-facing triangles
          indexBuffer[baseIndex + 6 + offset] = indexBuffer[baseIndex + 5 - offset]
        }
      }
    }
    bloomMesh = newBloomMesh

    return (true, false)
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
  func update(elapsed: Float) throws -> (LowLevelMesh, LowLevelMesh)? {
    var startSample = samples.firstIndex { elapsed - $0.point.timeAdded < 1.0 } ?? 0
    let (didReallocate, didCompact) = try reallocateMeshIfNeeded(lastSampleIndex: startSample)
    if didCompact {
      startSample = 0
    }

    guard let trailMesh, let bloomMesh else {
      return nil
    }

    if materializedSampleCount != samples.count {
      if materializedSampleCount < samples.count {
        trailMesh.withUnsafeMutableBytes(bufferIndex: 0) { trailBuffer in
          updateTrailVertexBuffer(trailBuffer.bindMemory(to: TrailVertex.self))
        }
        bloomMesh.withUnsafeMutableBytes(bufferIndex: 0) { bloomBuffer in
          updateBloomVertexBuffer(bloomBuffer.bindMemory(to: BloomVertex.self))
        }
        materializedSampleCount = samples.count
      }

      let activeSamples = samples.count - startSample
      let bounds = BoundingBox(min: [-10, -10, -10], max: [10, 10, 10])
      if activeSamples > 1 {
        let trailPart = LowLevelMesh.Part(indexOffset: startSample * topology.count * MemoryLayout<UInt32>.stride,
                                          indexCount: (activeSamples - 1) * topology.count,
                                          topology: .triangleStrip,
                                          materialIndex: 0,
                                          bounds: bounds)
        trailMesh.parts.removeAll()
        trailMesh.parts.append(trailPart)

        let bloomPart = LowLevelMesh.Part(indexOffset: startSample * bloomIndexCount * MemoryLayout<UInt32>.stride,
                                          indexCount: (activeSamples - 1) * bloomIndexCount,
                                          topology: .triangle,
                                          materialIndex: 0,
                                          bounds: bounds)
        bloomMesh.parts.removeAll()
        bloomMesh.parts.append(bloomPart)
      }
    }

    // Update timeline of all vertices
    trailMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
      let vertexBuffer = buffer.bindMemory(to: TrailVertex.self)
      for i in startSample..<samples.count {
        for j in 0..<shape.count {
          vertexBuffer[i * shape.count + j].timeline.y = elapsed
        }
      }
    }
    bloomMesh.withUnsafeMutableBytes(bufferIndex: 0) { buffer in
      let vertexBuffer = buffer.bindMemory(to: BloomVertex.self)
      for i in startSample..<samples.count {
        for j in 0..<bloomVertexCount {
          vertexBuffer[i * bloomVertexCount + j].timeline.y = elapsed
        }
      }
    }

    return didReallocate ? (trailMesh, bloomMesh) : nil
  }

  private func updateTrailVertexBuffer(_ trailVertices: UnsafeMutableBufferPointer<TrailVertex>) {
    for sampleIndex in materializedSampleCount..<samples.count {
      let sample = samples[sampleIndex]
      for shapeVertexIndex in 0..<shape.count {
        var trailVertex = TrailVertex()

        // Use the rotation frame of `sample` to compute the 3D position of this vertex.
        let position2d = shape[shapeVertexIndex] * radius
        trailVertex.position = sample.rotationFrame * SIMD3<Float>(position2d, 0) + sample.position

        // To compute the 3D bitangent, take the tangent of the shape in 2D
        // and orient with respect to the rotation frame of `sample`.
        let nextShapeIndex = (shapeVertexIndex + 1) % shape.count
        let prevShapeIndex = (shapeVertexIndex + shape.count - 1) % shape.count
        let bitangent2d = simd_normalize(shape[nextShapeIndex] - shape[prevShapeIndex])
        trailVertex.bitangent = sample.rotationFrame * SIMD3<Float>(bitangent2d, 0)

        trailVertex.normal = sample.rotationFrame * SIMD3<Float>(bitangent2d.y, -bitangent2d.x, 0)
        trailVertex.curveDistance = sample.curveDistance
        trailVertex.timeline = SIMD2<Float>(sample.point.timeAdded, 0)

        // Verify: This mesh generator should never output NaN.
        assert(any(isnan(trailVertex.position) .== 0))
        assert(any(isnan(trailVertex.bitangent) .== 0))
        assert(any(isnan(trailVertex.normal) .== 0))

        trailVertices[sampleIndex * shape.count + shapeVertexIndex] = trailVertex
      }
    }
  }

  private func updateBloomVertexBuffer(_ bloomVertices: UnsafeMutableBufferPointer<BloomVertex>) {
    for sampleIndex in materializedSampleCount..<samples.count {
      let sample = samples[sampleIndex]
      for bloomVertexIndex in 0..<bloomVertexCount {
        var bloomVertex = BloomVertex()
        bloomVertex.position = sample.position
        bloomVertex.curveDistance = sample.curveDistance
        bloomVertex.timeline = SIMD2<Float>(sample.point.timeAdded, 0)
        bloomVertex.direction = sampleIndex == 0 ? .zero : sample.position - samples[sampleIndex-1].position
        bloomVertices[sampleIndex * bloomVertexCount + bloomVertexIndex] = bloomVertex
      }
    }
  }
}
