import ARKit
import Combine
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
    private var processedMesh: ScanMesh?
    private var lastPhotoColorTimestamp: TimeInterval = -1

    var hasMesh: Bool { vertexCount > 0 }

    func setUnavailable(_ message: String) { status = message }

    func consume(anchors: [ARAnchor], frame: ARFrame?) {
        processedMesh = nil
        let shouldSamplePhoto = frame.map {
            lastPhotoColorTimestamp < 0 || $0.timestamp - lastPhotoColorTimestamp >= 0.65
        } ?? false

        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            var chunk = Self.makeChunk(from: meshAnchor)
            if shouldSamplePhoto, let frame {
                chunk = MeshChunk(
                    vertices: chunk.vertices,
                    faces: chunk.faces,
                    colors: CameraColorSampler.sample(points: chunk.vertices, fallback: chunk.colors, frame: frame)
                )
            } else if let previous = chunks[meshAnchor.identifier],
                      previous.colors.count == chunk.vertices.count {
                chunk = MeshChunk(vertices: chunk.vertices, faces: chunk.faces, colors: previous.colors)
            }
            chunks[meshAnchor.identifier] = chunk
        }

        if shouldSamplePhoto, let frame { lastPhotoColorTimestamp = frame.timestamp }
        updateCounts()
        status = hasMesh ? "Сканирование активно · цвет с камеры" : "Наведите камеру на поверхность"
    }

    func makeMesh() -> ScanMesh {
        if let processedMesh { return processedMesh }
        var result = ScanMesh()
        for chunk in chunks.values { result.append(chunk) }
        return result
    }

    func simplify(voxelSize: Float) {
        let original = makeMesh()
        let simplified = MeshSimplifier.simplify(original, voxelSize: voxelSize)
        processedMesh = simplified
        vertexCount = simplified.vertices.count
        triangleCount = simplified.triangleCount
        status = "Сетка упрощена: \(original.vertices.count.formatted()) → \(simplified.vertices.count.formatted()) вершин"
    }

    func reset() {
        chunks.removeAll()
        processedMesh = nil
        lastPhotoColorTimestamp = -1
        meshAnchorCount = 0
        vertexCount = 0
        triangleCount = 0
        status = "Сканирование активно"
    }

    private func updateCounts() {
        vertexCount = chunks.values.reduce(0) { $0 + $1.vertices.count }
        triangleCount = chunks.values.reduce(0) { $0 + $1.faces.count / 3 }
        meshAnchorCount = chunks.count
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
        var colors = Array(repeating: SIMD4<Float>(0.15, 0.68, 0.82, 1), count: source.count)

        for face in 0..<faces.count {
            var faceIndices: [Int] = []
            for corner in 0..<faces.indexCountPerPrimitive {
                let offset = (face * faces.indexCountPerPrimitive + corner) * faces.bytesPerIndex
                let address = faceBase.advanced(by: offset)
                let index: UInt32 = faces.bytesPerIndex == 2
                    ? UInt32(address.assumingMemoryBound(to: UInt16.self).pointee)
                    : address.assumingMemoryBound(to: UInt32.self).pointee
                indices.append(index)
                faceIndices.append(Int(index))
            }
            let color = classificationColor(classificationOf(face: face, in: geometry))
            for index in faceIndices where index < colors.count { colors[index] = color }
        }
        return MeshChunk(vertices: vertices, faces: indices, colors: colors)
    }

    private static func classificationOf(face: Int, in geometry: ARMeshGeometry) -> ARMeshClassification {
        guard let source = geometry.classification else { return .none }
        let address = source.buffer.contents().advanced(by: face)
        let rawValue = Int(address.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: rawValue) ?? .none
    }

    private static func classificationColor(_ classification: ARMeshClassification) -> SIMD4<Float> {
        switch classification {
        case .wall: return SIMD4<Float>(0.18, 0.62, 0.92, 1)
        case .floor: return SIMD4<Float>(0.20, 0.82, 0.56, 1)
        case .ceiling: return SIMD4<Float>(0.72, 0.55, 0.94, 1)
        case .table: return SIMD4<Float>(0.95, 0.68, 0.22, 1)
        case .seat: return SIMD4<Float>(0.94, 0.42, 0.38, 1)
        case .window: return SIMD4<Float>(0.28, 0.82, 0.92, 1)
        case .door: return SIMD4<Float>(0.76, 0.55, 0.32, 1)
        case .none: return SIMD4<Float>(0.48, 0.58, 0.66, 1)
        @unknown default: return SIMD4<Float>(0.48, 0.58, 0.66, 1)
        }
    }
}
