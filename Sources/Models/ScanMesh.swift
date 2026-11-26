import Foundation
import simd

struct MeshChunk {
    let vertices: [SIMD3<Float>]
    let faces: [UInt32]
    var colors: [SIMD4<Float>] = []
}

struct ScanMesh {
    var vertices: [SIMD3<Float>] = []
    var faces: [UInt32] = []
    var colors: [SIMD4<Float>] = []

    mutating func append(_ chunk: MeshChunk) {
        let baseIndex = UInt32(vertices.count)
        vertices.append(contentsOf: chunk.vertices)
        faces.append(contentsOf: chunk.faces.map { $0 + baseIndex })
        if chunk.colors.count == chunk.vertices.count {
            colors.append(contentsOf: chunk.colors)
        } else {
            colors.append(contentsOf: repeatElement(SIMD4<Float>(0.1, 0.72, 0.82, 1), count: chunk.vertices.count))
        }
    }

    var triangleCount: Int { faces.count / 3 }
    var hasColors: Bool { colors.count == vertices.count }
}
