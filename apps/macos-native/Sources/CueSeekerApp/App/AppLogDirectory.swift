import Foundation

enum AppLogDirectory {
    static var baseURL: URL {
        projectRootURL.appendingPathComponent("logs", isDirectory: true)
    }

    static func directory(named name: String) -> URL {
        baseURL.appendingPathComponent(name, isDirectory: true)
    }

    static func fileURL(in directoryName: String, filename: String) -> URL {
        directory(named: directoryName).appendingPathComponent(filename)
    }

    private static var projectRootURL: URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while directory.path != "/" {
            let macOSPackageURL = directory
                .appendingPathComponent("apps", isDirectory: true)
                .appendingPathComponent("macos-native", isDirectory: true)
            if FileManager.default.fileExists(atPath: macOSPackageURL.path) {
                return directory
            }

            directory.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }
}
