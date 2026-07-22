import Foundation

public enum DatabaseBootstrap {
    public static let currentSchemaVersion = 33

    public static func prepare(at path: URL) throws {
        let database = try SubtitleDatabase(path: path, access: .readWrite)
        try database.migrate()
    }
}
