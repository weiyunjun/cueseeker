import CoreGraphics
import Foundation

actor ShioriListCoverStorage {
    private let displayDirectory: URL
    private let imagePipeline: LibraryCoverImagePipeline
    private let fileManager: FileManager

    init(
        coverDirectory: URL,
        imagePipeline: LibraryCoverImagePipeline = .shared,
        fileManager: FileManager = .default
    ) {
        displayDirectory = coverDirectory
            .appendingPathComponent("Shiori", isDirectory: true)
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
        self.imagePipeline = imagePipeline
        self.fileManager = fileManager
    }

    func publish(
        source: LibraryUserCoverSource,
        cropRect: CGRect
    ) throws -> String {
        let data = try LibraryUserCoverProcessor.jpegData(
            source: source,
            cropRect: cropRect
        )
        let destination = displayDirectory
            .appendingPathComponent(UUID().uuidString.lowercased())
            .appendingPathExtension("jpg")
        do {
            try fileManager.createDirectory(
                at: displayDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: destination, options: .atomic)
            return destination.path
        } catch {
            throw LibraryUserCoverError.publishFailed(String(describing: error))
        }
    }

    func remove(path: String?) async throws {
        guard let path, !path.isEmpty else {
            return
        }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.deletingLastPathComponent() == displayDirectory.standardizedFileURL else {
            throw LibraryUserCoverError.invalidStoredCoverPath(path)
        }
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw LibraryUserCoverError.oldCoverRemovalFailed(String(describing: error))
            }
        }
        await imagePipeline.remove(path: path)
    }
}
