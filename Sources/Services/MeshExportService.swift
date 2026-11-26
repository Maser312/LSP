import Foundation
import ModelIO
import SceneKit
import UIKit

enum MeshExportFormat: String, CaseIterable, Identifiable {
    case ply = "PLY"
    case obj = "OBJ"
    case stl = "STL"
    case usdz = "USDZ"
    case glb = "GLB"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

enum MeshExportService {
    static func export(_ mesh: ScanMesh, name: String, format: MeshExportFormat) throws -> URL {
        guard !mesh.vertices.isEmpty, mesh.triangleCount > 0 else { throw ExportError.emptyMesh }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName(name))
            .appendingPathExtension(format.fileExtension)

        switch format {
        case .ply:
            try exportPLY(mesh, to: url)
        case .obj:
            try exportOBJ(mesh, to: url)
        case .stl:
            try exportSTL(mesh, to: url)
        case .glb:
            try exportGLB(mesh, to: url)
        case .usdz:
            try exportUSDZ(mesh, to: url)
        }
        return url
    }

    private static func exportPLY(_ mesh: ScanMesh, to url: URL) throws {
        var text = "ply\nformat ascii 1.0\ncomment LiDAR Scanner Pro\nelement vertex \(mesh.vertices.count)\nproperty float x\nproperty float y\nproperty float z\n"
        if mesh.hasColors {
            text += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
        }
        text += "element face \(mesh.triangleCount)\nproperty list uchar uint vertex_indices\nend_header\n"
        for index in mesh.vertices.indices {
            let p = mesh.vertices[index]
            text += "\(p.x) \(p.y) \(p.z)"
            if mesh.hasColors {
                let c = mesh.colors[index]
                text += " \(byte(c.x)) \(byte(c.y)) \(byte(c.z))"
            }
            text += "\n"
        }
        for i in stride(from: 0, to: mesh.faces.count - 2, by: 3) {
            text += "3 \(mesh.faces[i]) \(mesh.faces[i + 1]) \(mesh.faces[i + 2])\n"
        }
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private static func exportOBJ(_ mesh: ScanMesh, to url: URL) throws {
        var text = "# LiDAR Scanner Pro\no \(safeName(url.deletingPathExtension().lastPathComponent))\n"
        for (i, p) in mesh.vertices.enumerated() {
            if mesh.hasColors {
                let c = mesh.colors[i]
                text += "v \(p.x) \(p.y) \(p.z) \(c.x) \(c.y) \(c.z)\n"
            } else {
                text += "v \(p.x) \(p.y) \(p.z)\n"
            }
        }
        for i in stride(from: 0, to: mesh.faces.count - 2, by: 3) {
            text += "f \(mesh.faces[i] + 1) \(mesh.faces[i + 1] + 1) \(mesh.faces[i + 2] + 1)\n"
        }
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    private static func exportSTL(_ mesh: ScanMesh, to url: URL) throws {
        var data = Data(repeating: 0, count: 80)
        data.appendLE(UInt32(mesh.triangleCount))
        for i in stride(from: 0, to: mesh.faces.count - 2, by: 3) {
            let a = mesh.vertices[Int(mesh.faces[i])]
            let b = mesh.vertices[Int(mesh.faces[i + 1])]
            let c = mesh.vertices[Int(mesh.faces[i + 2])]
            let normal = simd_normalize(simd_cross(b - a, c - a))
            for value in [normal.x, normal.y, normal.z, a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z] {
                data.appendLE(value)
            }
            data.appendLE(UInt16(0))
        }
        try data.write(to: url, options: .atomic)
    }

    private static func exportGLB(_ mesh: ScanMesh, to url: URL) throws {
        var binary = Data()
        let positionOffset = binary.count
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for p in mesh.vertices {
            minimum = simd_min(minimum, p)
            maximum = simd_max(maximum, p)
            binary.appendLE(p.x); binary.appendLE(p.y); binary.appendLE(p.z)
        }
        let positionLength = binary.count - positionOffset
        while binary.count % 4 != 0 { binary.append(0) }
        let colorOffset = binary.count
        if mesh.hasColors {
            for c in mesh.colors {
                binary.appendLE(c.x); binary.appendLE(c.y); binary.appendLE(c.z); binary.appendLE(c.w)
            }
        }
        let colorLength = binary.count - colorOffset
        while binary.count % 4 != 0 { binary.append(0) }
        let indexOffset = binary.count
        for index in mesh.faces { binary.appendLE(index) }
        let indexLength = binary.count - indexOffset
        while binary.count % 4 != 0 { binary.append(0) }

        var views: [[String: Any]] = [
            ["buffer": 0, "byteOffset": positionOffset, "byteLength": positionLength, "target": 34962],
            ["buffer": 0, "byteOffset": indexOffset, "byteLength": indexLength, "target": 34963]
        ]
        var accessors: [[String: Any]] = [
            ["bufferView": 0, "componentType": 5126, "count": mesh.vertices.count, "type": "VEC3",
             "min": [minimum.x, minimum.y, minimum.z], "max": [maximum.x, maximum.y, maximum.z]],
            ["bufferView": 1, "componentType": 5125, "count": mesh.faces.count, "type": "SCALAR"]
        ]
        var attributes: [String: Any] = ["POSITION": 0]
        if mesh.hasColors {
            views.append(["buffer": 0, "byteOffset": colorOffset, "byteLength": colorLength, "target": 34962])
            accessors.append(["bufferView": 2, "componentType": 5126, "count": mesh.vertices.count, "type": "VEC4"])
            attributes["COLOR_0"] = 2
        }
        let json: [String: Any] = [
            "asset": ["version": "2.0", "generator": "LiDAR Scanner Pro"],
            "scene": 0,
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0]],
            "meshes": [["primitives": [["attributes": attributes, "indices": 1, "mode": 4]]]],
            "buffers": [["byteLength": binary.count]],
            "bufferViews": views,
            "accessors": accessors
        ]
        var jsonData = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        while jsonData.count % 4 != 0 { jsonData.append(0x20) }
        while binary.count % 4 != 0 { binary.append(0) }

        let totalLength = 12 + 8 + jsonData.count + 8 + binary.count
        var glb = Data()
        glb.appendLE(UInt32(0x46546C67))
        glb.appendLE(UInt32(2))
        glb.appendLE(UInt32(totalLength))
        glb.appendLE(UInt32(jsonData.count))
        glb.appendLE(UInt32(0x4E4F534A))
        glb.append(jsonData)
        glb.appendLE(UInt32(binary.count))
        glb.appendLE(UInt32(0x004E4942))
        glb.append(binary)
        try glb.write(to: url, options: .atomic)
    }

    private static func exportUSDZ(_ mesh: ScanMesh, to url: URL) throws {
        let scene = SCNScene()
        let source = SCNGeometrySource(
            data: mesh.vertices.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .vertex,
            vectorCount: mesh.vertices.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD3<Float>>.stride
        )
        var indices = Data()
        for index in mesh.faces { indices.appendLE(index) }
        let element = SCNGeometryElement(data: indices, primitiveType: .triangles,
                                         primitiveCount: mesh.triangleCount, bytesPerIndex: 4)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemTeal
        material.isDoubleSided = true
        geometry.firstMaterial = material
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))

        guard MDLAsset.canExportFileExtension("usdz") else { throw ExportError.usdzUnavailable }
        let asset = MDLAsset(scnScene: scene, bufferAllocator: nil)
        try asset.export(to: url)
    }

    private static func byte(_ value: Float) -> Int {
        Int((max(0, min(1, value)) * 255).rounded())
    }

    private static func safeName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:\n\r")
        let cleaned = name.components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "-")
        return String((cleaned.isEmpty ? "LiDAR-Scan" : cleaned).prefix(70))
    }

    enum ExportError: LocalizedError {
        case emptyMesh
        case usdzUnavailable
        var errorDescription: String? {
            switch self {
            case .emptyMesh: return "В модели нет полигонов для экспорта."
            case .usdzUnavailable: return "Эта версия iOS не предоставляет экспорт USDZ для произвольной сетки."
            }
        }
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
    mutating func appendLE(_ value: Float) {
        appendLE(value.bitPattern)
    }
}
