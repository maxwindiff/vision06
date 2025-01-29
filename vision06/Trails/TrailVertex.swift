import RealityKit

struct TrailVertex {
  var position: SIMD3<Float> = .zero
  var normal: SIMD3<Float> = .zero
  var bitangent: SIMD3<Float> = .zero
  var curveDistance: Float = .zero
  var timeline: SIMD2<Float> = .zero
}

extension TrailVertex {
  static var vertexAttributes: [LowLevelMesh.Attribute] = [
    .init(semantic: .position, format: .float3, offset: MemoryLayout.offset(of: \Self.position)!),
    .init(semantic: .normal, format: .float3, offset: MemoryLayout.offset(of: \Self.normal)!),
    .init(semantic: .bitangent, format: .float3, offset: MemoryLayout.offset(of: \Self.bitangent)!),
    .init(semantic: .uv1, format: .float, offset: MemoryLayout.offset(of: \Self.curveDistance)!),
    .init(semantic: .uv2, format: .float2, offset: MemoryLayout.offset(of: \Self.timeline)!),
  ]

  static var vertexLayouts: [LowLevelMesh.Layout] = [
    .init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)
  ]

  static var descriptor: LowLevelMesh.Descriptor {
    var desc = LowLevelMesh.Descriptor()
    desc.vertexAttributes = vertexAttributes
    desc.vertexLayouts = vertexLayouts
    desc.indexType = .uint32
    return desc
  }
}

