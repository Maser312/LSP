import ARKit
import Foundation
import simd

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published private(set) var status = "Подготовка LiDAR…"
    @Published private(set) var meshAnchorCount = 0
    @Published private(set) var vertexCount = 0
    @Published private(set) var triangleCount = 0
    @Published var projectName = "Новый скан"

    private var chunks: [UUID: MeshChunk] = [:]

    var hasMesh: Bool { vertexCount > 0 }

    func setUnavailable(_ message: String) { status = message }

    func consume(anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            chunks[meshAnchor.identifier] = Self.makeChunk(from: meshAnchor)
        }

        var vertices = 0
        var triangles = 0
        for chunk in chunks.values {
            vertices += chunk.vertices.count
            triangles += chunk.faces.count / 3
        }
        meshAnchorCount = chunks.count
        vertexCount = vertices
        triangleCount = triangles
        status = hasMesh ? "Сканирование активно" : "Наведите камеру на поверхность"
    }

    func makeMesh() -> ScanMesh {
        var result = ScanMesh()
        for chunk in chunks.values { result.append(chunk) }
        return result
    }

    func exportPLY() throws -> URL {
        try PLYExporter.export(makeMesh(), projectName: projectName)
    }

    func reset() {
        chunks.removeAll()
        meshAnchorCount = 0
        vertexCount = 0
        triangleCount = 0
        status = "Сканирование активно"
    }

    private static func makeChunk(from anchor: ARMeshAnchor) -> MeshChunk {
        let geometry = anchor.geometry
        let source = geometry.vertices
        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(source.count)
        let vertexBase = source.buffer.contents()

        for index in 0..<source.count {
            let address = vertexBase.advanced(by: source.offset + index * source.stride)
            let local = address.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let world = anchor.transform * SIMD4<Float>(local.x, local.y, local.z, 1)
            vertices.append(SIMD3<Float>(world.x, world.y, world.z))
        }

        let faces = geometry.faces
        let faceBase = faces.buffer.contents()
        var indices: [UInt32] = []
        indices.reserveCapacity(faces.count * faces.indexCountPerPrimitive)

        for face in 0..<faces.count {
            for corner in 0..<faces.indexCountPerPrimitive {
                let offset = (face * faces.indexCountPerPrimitive + corner) * faces.bytesPerIndex
                let address = faceBase.advanced(by: offset)
                if faces.bytesPerIndex == 2 {
                    indices.append(UInt32(address.assumingMemoryBound(to: UInt16.self).pointee))
                } else {
                    indices.append(address.assumingMemoryBound(to: UInt32.self).pointee)
                }
            }
        }
        return MeshChunk(vertices: vertices, faces: indices)
    }
}
