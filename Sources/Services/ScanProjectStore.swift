import Foundation

enum ScanProjectStore {
    private static let folderName = "Scans"
    private static let metadataExtension = "lsp"
    private static let meshExtension = "lspmesh"
    private static let magic = Array("LSPMESH1".utf8)

    private static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func allProjects() throws -> [ScanProject] {
        try ensureDirectory()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return try files
            .filter { $0.pathExtension == metadataExtension }
            .compactMap { url -> ScanProject? in
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(ScanProject.self, from: data)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func save(mesh: ScanMesh, name: String) throws -> ScanProject {
        guard !mesh.vertices.isEmpty else { throw StoreError.emptyMesh }
        try ensureDirectory()

        let id = UUID()
        let meshName = "\(id.uuidString).\(meshExtension)"
        let project = ScanProject(id: id, name: cleanName(name), mesh: mesh, meshFileName: meshName)
        let meshURL = directory.appendingPathComponent(meshName)
        let metadataURL = directory.appendingPathComponent("\(id.uuidString).\(metadataExtension)")

        try encode(mesh).write(to: meshURL, options: .atomic)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(project).write(to: metadataURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: meshURL)
            throw error
        }
        return project
    }

    static func load(_ project: ScanProject) throws -> ScanMesh {
        let url = directory.appendingPathComponent(project.meshFileName)
        return try decode(Data(contentsOf: url))
    }

    static func delete(_ project: ScanProject) throws {
        let metadataURL = directory.appendingPathComponent("\(project.id.uuidString).\(metadataExtension)")
        let meshURL = directory.appendingPathComponent(project.meshFileName)
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            try FileManager.default.removeItem(at: metadataURL)
        }
        if FileManager.default.fileExists(atPath: meshURL.path) {
            try FileManager.default.removeItem(at: meshURL)
        }
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func cleanName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Без названия" : String(trimmed.prefix(80))
    }

    private static func encode(_ mesh: ScanMesh) -> Data {
        var data = Data(magic)
        append(UInt32(mesh.vertices.count), to: &data)
        append(UInt32(mesh.faces.count), to: &data)
        for vertex in mesh.vertices {
            append(vertex.x.bitPattern, to: &data)
            append(vertex.y.bitPattern, to: &data)
            append(vertex.z.bitPattern, to: &data)
        }
        for index in mesh.faces {
            append(index, to: &data)
        }
        return data
    }

    private static func decode(_ data: Data) throws -> ScanMesh {
        guard data.count >= 16, Array(data.prefix(8)) == magic else {
            throw StoreError.invalidMeshFile
        }

        var offset = 8
        let vertexCount = Int(readUInt32(data, at: &offset))
        let indexCount = Int(readUInt32(data, at: &offset))
        guard vertexCount <= 20_000_000, indexCount <= 60_000_000,
              data.count == 16 + vertexCount * 12 + indexCount * 4 else {
            throw StoreError.invalidMeshFile
        }

        var vertices: [SIMD3<Float>] = []
        vertices.reserveCapacity(vertexCount)
        for _ in 0..<vertexCount {
            let x = Float(bitPattern: readUInt32(data, at: &offset))
            let y = Float(bitPattern: readUInt32(data, at: &offset))
            let z = Float(bitPattern: readUInt32(data, at: &offset))
            vertices.append(SIMD3<Float>(x, y, z))
        }

        var faces: [UInt32] = []
        faces.reserveCapacity(indexCount)
        for _ in 0..<indexCount {
            faces.append(readUInt32(data, at: &offset))
        }
        guard faces.allSatisfy({ Int($0) < vertexCount }) else {
            throw StoreError.invalidMeshFile
        }
        return ScanMesh(vertices: vertices, faces: faces)
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }

    private static func readUInt32(_ data: Data, at offset: inout Int) -> UInt32 {
        let value = UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
        offset += 4
        return value
    }

    enum StoreError: LocalizedError {
        case emptyMesh
        case invalidMeshFile

        var errorDescription: String? {
            switch self {
            case .emptyMesh:
                return "Нельзя сохранить пустой скан."
            case .invalidMeshFile:
                return "Файл 3D-модели повреждён или имеет неизвестный формат."
            }
        }
    }
}
