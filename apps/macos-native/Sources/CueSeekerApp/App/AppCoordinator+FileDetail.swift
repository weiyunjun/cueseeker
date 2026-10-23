import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    func requestRootFolderDetail(for folder: URL) {
        let folderPath = folder.isRemoteMediaURL
            ? folder.mediaPath
            : MediaFolderPathMatching.normalizedFolderPath(folder.path)
        let name = IndexingStore.displayName(for: folder)
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailFolderInfo(
               for: folderPath,
               name: name,
               isRootFolder: true
           ) {
            library.fileDetailSession = FileDetailDialogSession(kind: .folder(info))
        } else {
            library.fileDetailSession = FileDetailDialogSession(
                kind: .folder(
                    FileDetailFolderInfo(
                        path: folderPath,
                        name: name,
                        isRootFolder: true,
                        folderCount: 0,
                        videoCount: 0,
                        subtitleCount: 0,
                        addedAt: nil,
                        updatedAt: nil
                    )
                )
            )
        }
    }

    func requestSubfolderDetail(for folderPath: String) {
        let standardizedPath = folderPath.isRemoteMediaPath
            ? URL.fromMediaPath(folderPath).standardizedMediaURL.mediaPath
            : MediaFolderPathMatching.normalizedFolderPath(folderPath)
        let name = folderPath.isRemoteMediaPath
            ? URL.fromMediaPath(standardizedPath).lastPathComponent
            : (standardizedPath as NSString).lastPathComponent
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailFolderInfo(
               for: standardizedPath,
               name: name,
               isRootFolder: false
           ) {
            library.fileDetailSession = FileDetailDialogSession(kind: .folder(info))
        } else {
            library.fileDetailSession = FileDetailDialogSession(
                kind: .folder(
                    FileDetailFolderInfo(
                        path: standardizedPath,
                        name: name,
                        isRootFolder: false,
                        folderCount: 1,
                        videoCount: 0,
                        subtitleCount: 0,
                        addedAt: nil,
                        updatedAt: nil
                    )
                )
            )
        }
    }

    func requestVideoDetail(for videoPath: String) {
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailVideoInfo(for: videoPath) {
            library.fileDetailSession = FileDetailDialogSession(kind: .video(info))
        } else {
            let url = URL.fromMediaPath(videoPath)
            let attrs = videoPath.isRemoteMediaPath ? nil : (try? FileManager.default.attributesOfItem(atPath: videoPath))
            let info = FileDetailVideoInfo(
                path: videoPath,
                name: url.lastPathComponent,
                fileSize: (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                duration: nil,
                videoWidth: nil,
                videoHeight: nil,
                frameRate: nil,
                videoCodec: nil,
                videoBitDepth: nil,
                videoPixelFormat: nil,
                audioTracks: [],
                subtitles: [],
                createdAt: attrs?[.creationDate] as? Date,
                modifiedAt: attrs?[.modificationDate] as? Date
            )
            library.fileDetailSession = FileDetailDialogSession(kind: .video(info))
        }
    }

    func requestSubtitleDetail(for subtitlePath: String) {
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailSubtitleInfo(for: subtitlePath) {
            library.fileDetailSession = FileDetailDialogSession(kind: .subtitle(info))
        } else {
            let url = URL.fromMediaPath(subtitlePath)
            let attrs = subtitlePath.isRemoteMediaPath ? nil : (try? FileManager.default.attributesOfItem(atPath: subtitlePath))
            let info = FileDetailSubtitleInfo(
                path: subtitlePath,
                name: url.lastPathComponent,
                fileSize: (attrs?[.size] as? NSNumber)?.int64Value ?? 0,
                format: SubtitleFormat(fileExtension: url.pathExtension) ?? .srt,
                encoding: "UTF-8",
                cueCount: 0,
                rawCueCount: 0,
                associatedVideoPath: nil,
                createdAt: attrs?[.creationDate] as? Date,
                modifiedAt: attrs?[.modificationDate] as? Date
            )
            library.fileDetailSession = FileDetailDialogSession(kind: .subtitle(info))
        }
    }

    func closeFileDetailDialog() {
        library.fileDetailSession = nil
    }
}
