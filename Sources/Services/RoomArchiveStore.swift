import Foundation
import RoomPlan

struct RoomProject: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let jsonFileName: String
    let usdzFileName: String
}

enum RoomArchiveStore {
    private static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Rooms", isDirectory: true)
    }

    static func save(_ room: CapturedRoom, name: String) throws -> RoomProject {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID()
        let baseName = id.uuidString
        let jsonName = baseName + ".json"
        let usdzName = baseName + ".usdz"
        let jsonURL = directory.appendingPathComponent(jsonName)
        let usdzURL = directory.appendingPathComponent(usdzName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(room).write(to: jsonURL, options: .atomic)
        do {
            try room.export(to: usdzURL, exportOptions: .model)
        } catch {
            try? FileManager.default.removeItem(at: jsonURL)
            throw error
        }
        return RoomProject(id: id, name: name, createdAt: .now,
                           jsonFileName: jsonName, usdzFileName: usdzName)
    }

    static func all() throws -> [RoomProject] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files.filter { $0.pathExtension == "json" }.map { url in
            let room = try JSONDecoder().decode(CapturedRoom.self, from: Data(contentsOf: url))
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()
            let usdz = id.uuidString + ".usdz"
            return RoomProject(id: id, name: "Помещение", createdAt: .now,
                               jsonFileName: url.lastPathComponent, usdzFileName: usdz)
        }
    }

    static func usdzURL(for project: RoomProject) -> URL {
        directory.appendingPathComponent(project.usdzFileName)
    }

    static func delete(_ project: RoomProject) throws {
        for name in [project.jsonFileName, project.usdzFileName] {
            let url = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }
}
