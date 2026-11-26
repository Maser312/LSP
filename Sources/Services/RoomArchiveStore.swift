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
        let metadataName = baseName + ".room"
        let jsonURL = directory.appendingPathComponent(jsonName)
        let usdzURL = directory.appendingPathComponent(usdzName)
        let metadataURL = directory.appendingPathComponent(metadataName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(room).write(to: jsonURL, options: .atomic)
        do {
            try room.export(to: usdzURL, exportOptions: .model)
        } catch {
            try? FileManager.default.removeItem(at: jsonURL)
            throw error
        }
        let project = RoomProject(id: id, name: name, createdAt: .now,
                                  jsonFileName: jsonName, usdzFileName: usdzName)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(project).write(to: metadataURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: jsonURL)
            try? FileManager.default.removeItem(at: usdzURL)
            throw error
        }
        return project
    }

    static func all() throws -> [RoomProject] {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files.filter { $0.pathExtension == "room" }.map { url in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(RoomProject.self, from: Data(contentsOf: url))
        }.sorted { $0.createdAt > $1.createdAt }
    }

    static func usdzURL(for project: RoomProject) -> URL {
        directory.appendingPathComponent(project.usdzFileName)
    }

    static func delete(_ project: RoomProject) throws {
        for name in [project.jsonFileName, project.usdzFileName, "\(project.id.uuidString).room"] {
            let url = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }
}
