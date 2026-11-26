import Foundation
import simd

struct MeshChunk {
    let vertices: [SIMD3<Float>]
    let faces: [UInt32]
}

struct ScanMesh {
    var vertices: [SIMD3<Float>] = []
    var faces: [UInt32] = []

    mutating func append(_ chunk: MeshChunk) {
        let baseIndex = UInt32(vertices.count)
        vertices.append(contentsOf: chunk.vertices)
        faces.append(contentsOf: chunk.faces.map { $0 + baseIndex })
    }

    var triangleCount: Int { faces.count / 3 }
}
