import RealityKit

struct BloomVertex {
  var position: SIMD3<Float> = .zero
  var curveDistance: Float = .zero
  var timeline: SIMD2<Float> = .zero
  var params: SIMD2<Float> = .zero
}

extension BloomVertex {
  static var vertexAttributes: [LowLevelMesh.Attribute] = [
    .init(semantic: .position, format: .float3, offset: MemoryLayout.offset(of: \Self.position)!),
    .init(semantic: .uv1, format: .float, offset: MemoryLayout.offset(of: \Self.curveDistance)!),
    .init(semantic: .uv2, format: .float2, offset: MemoryLayout.offset(of: \Self.timeline)!),
    .init(semantic: .uv3, format: .float2, offset: MemoryLayout.offset(of: \Self.params)!),
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
