import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
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
