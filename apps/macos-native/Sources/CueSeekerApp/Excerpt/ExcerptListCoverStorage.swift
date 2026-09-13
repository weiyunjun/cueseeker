import CoreGraphics
import CueSeekerCore
import Foundation

actor ExcerptListCoverStorage {
    private let displayDirectory: URL
    private let imagePipeline: LibraryCoverImagePipeline
    private let fileManager: FileManager

    init(
        coverDirectory: URL,
        imagePipeline: LibraryCoverImagePipeline = .shared,
        fileManager: FileManager = .default
    ) {
        displayDirectory = Self.displayDirectory(in: coverDirectory, folder: "Excerpt")
        self.imagePipeline = imagePipeline
        self.fileManager = fileManager
    }

    /// Covers published before Shiori became Excerpt live in the old folder,
    /// where `remove(path:)` will not touch them. Each one is copied into the
    /// current folder and its list points at the copy; the old folder stays for
    /// the owner to delete. A cover already copied is not copied again.
    static func adoptPreRenameCovers(
        coverDirectory: URL,
        database: ExcerptDatabase,
        fileManager: FileManager = .default
    ) throws {
        let preRenameDirectory = displayDirectory(in: coverDirectory, folder: "Shiori")
            .standardizedFileURL
        let currentDirectory = displayDirectory(in: coverDirectory, folder: "Excerpt")
        for list in try database.excerptLists() {
            guard let coverPath = list.coverPath else {
                continue
            }
            let coverURL = URL(fileURLWithPath: coverPath).standardizedFileURL
            guard coverURL.deletingLastPathComponent() == preRenameDirectory,
                  fileManager.fileExists(atPath: coverURL.path)
            else {
                continue
            }
            let copyURL = currentDirectory.appendingPathComponent(coverURL.lastPathComponent)
            if !fileManager.fileExists(atPath: copyURL.path) {
                try fileManager.createDirectory(
                    at: currentDirectory,
                    withIntermediateDirectories: true
                )
                try fileManager.copyItem(at: coverURL, to: copyURL)
            }
            try database.updateExcerptList(
                id: list.id,
                name: list.name,
                description: list.description,
                coverPath: copyURL.path
            )
        }
    }

    private static func displayDirectory(in coverDirectory: URL, folder: String) -> URL {
        coverDirectory
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("Display", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
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
