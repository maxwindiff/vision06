import RealityKit

struct BloomVertex {
  var position: SIMD3<Float> = .zero
  var direction: SIMD3<Float> = .zero
  var uv: SIMD2<Float> = .zero // x = (0: "upper" vertex, 1: "lower" vertex), y = sample index mod 2
  var curveTopology: SIMD2<Float> = .zero // x = distance from beginning, y = curvature (scalar)
  var timeline: SIMD2<Float> = .zero // x = added time, y = current time
}

extension BloomVertex {
  static var vertexAttributes: [LowLevelMesh.Attribute] = [
    .init(semantic: .position, format: .float3, offset: MemoryLayout.offset(of: \Self.position)!),
    .init(semantic: .color, format: .float3, offset: MemoryLayout.offset(of: \Self.direction)!),
    .init(semantic: .uv0, format: .float2, offset: MemoryLayout.offset(of: \Self.uv)!),
    .init(semantic: .uv1, format: .float2, offset: MemoryLayout.offset(of: \Self.curveTopology)!),
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
