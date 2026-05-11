import Foundation

enum AppLogDirectory {
    private static let appLogFolderName = "CueSeeker"

    static var baseURL: URL {
        FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(appLogFolderName, isDirectory: true)
    }

    static func directory(named name: String) -> URL {
        baseURL.appendingPathComponent(name, isDirectory: true)
    }

    static func fileURL(in directoryName: String, filename: String) -> URL {
        directory(named: directoryName).appendingPathComponent(filename)
    }
}
