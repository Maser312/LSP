import Foundation

struct ScanProject: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    let vertexCount: Int
    let triangleCount: Int
    let meshFileName: String

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, mesh: ScanMesh, meshFileName: String) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.vertexCount = mesh.vertices.count
        self.triangleCount = mesh.triangleCount
        self.meshFileName = meshFileName
    }
}
