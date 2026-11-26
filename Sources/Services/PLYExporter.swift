import Foundation

enum PLYExporter {
    static func export(_ mesh: ScanMesh, projectName: String) throws -> URL {
        guard !mesh.vertices.isEmpty else { throw ExportError.emptyMesh }

        var output = """
        ply
        format ascii 1.0
        comment Created by LiDAR Scanner Pro
        element vertex \(mesh.vertices.count)
        property float x
        property float y
        property float z
        element face \(mesh.triangleCount)
        property list uchar uint vertex_indices
        end_header

        """

        for vertex in mesh.vertices {
            output += "\(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        for index in stride(from: 0, to: mesh.faces.count - (mesh.faces.count % 3), by: 3) {
            output += "3 \(mesh.faces[index]) \(mesh.faces[index + 1]) \(mesh.faces[index + 2])\n"
        }

        let safeName = projectName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName.isEmpty ? "LiDAR-Scan" : safeName).ply")
        try Data(output.utf8).write(to: url, options: .atomic)
        return url
    }

    enum ExportError: LocalizedError {
        case emptyMesh
        var errorDescription: String? {
            "В скане пока нет геометрии. Сначала просканируйте объект или помещение."
        }
    }
}
