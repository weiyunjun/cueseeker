import CueSeekerCore
import Foundation

@MainActor
extension AppCoordinator {
    func requestRootFolderDetail(for folder: URL) {
        let startedAt = DebugInteractionLatencyProbe.now()
        let folderPath = folder.isRemoteMediaURL
            ? folder.mediaPath
            : MediaFolderPathMatching.normalizedFolderPath(folder.path)
        let name = IndexingStore.displayName(for: folder)
        AppLogger.shared.info(
            .library,
            "File detail opened",
            fields: [("kind", "root_folder"), ("name", name)]
        )
        let session: FileDetailDialogSession
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailFolderInfo(
               for: folderPath,
               name: name,
               isRootFolder: true
           ) {
            session = FileDetailDialogSession(kind: .folder(info))
        } else {
            session = FileDetailDialogSession(
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
        presentFileDetailDialog(
            session,
            dialogID: "file_detail_root_folder",
            startedAt: startedAt
        )
    }

    func requestSubfolderDetail(for folderPath: String) {
        let startedAt = DebugInteractionLatencyProbe.now()
        let standardizedPath = folderPath.isRemoteMediaPath
            ? URL.fromMediaPath(folderPath).standardizedMediaURL.mediaPath
            : MediaFolderPathMatching.normalizedFolderPath(folderPath)
        let name = folderPath.isRemoteMediaPath
            ? URL.fromMediaPath(standardizedPath).lastPathComponent
            : (standardizedPath as NSString).lastPathComponent
        AppLogger.shared.info(
            .library,
            "File detail opened",
            fields: [("kind", "subfolder"), ("name", name)]
        )
        let session: FileDetailDialogSession
        if let libraryDatabase,
           let info = try? libraryDatabase.fileDetailFolderInfo(
               for: standardizedPath,
               name: name,
               isRootFolder: false
           ) {
            session = FileDetailDialogSession(kind: .folder(info))
        } else {
            session = FileDetailDialogSession(
                kind: .folder(
                    FileDetailFolderInfo(
                        path: standardizedPath,
                        name: name,
                        isRootFolder: false,
                        folderCount: 0,
                        videoCount: 0,
                        subtitleCount: 0,
                        addedAt: nil,
                        updatedAt: nil
                    )
                )
            )
        }
        presentFileDetailDialog(
            session,
            dialogID: "file_detail_subfolder",
            startedAt: startedAt
        )
    }

    func requestVideoDetail(for videoPath: String) {
        let startedAt = DebugInteractionLatencyProbe.now()
        AppLogger.shared.info(
            .library,
            "File detail opened",
            fields: [("kind", "video"), ("file", URL.fromMediaPath(videoPath).lastPathComponent)]
        )
        let session: FileDetailDialogSession
        if let libraryDatabase,
           let items = try? libraryDatabase.fileDetailPairedItems(forVideoPath: videoPath),
           !items.isEmpty {
            let initialIndex = items.firstIndex(where: { $0.isVideo && $0.path == videoPath }) ?? 0
            session = FileDetailDialogSession(
                pairedItems: items,
                initialSelectedIndex: initialIndex
            )
        } else {
            let url = URL.fromMediaPath(videoPath)
            let info = FileDetailVideoInfo(
                path: videoPath,
                name: url.lastPathComponent,
                fileSize: 0,
                duration: nil,
                videoWidth: nil,
                videoHeight: nil,
                frameRate: nil,
                videoCodec: nil,
                videoBitDepth: nil,
                videoPixelFormat: nil,
                audioTracks: [],
                subtitles: [],
                createdAt: nil,
                modifiedAt: nil
            )
            session = FileDetailDialogSession(kind: .video(info))
        }
        presentFileDetailDialog(
            session,
            dialogID: "file_detail_video",
            startedAt: startedAt
        )
    }

    func requestSubtitleDetail(for subtitlePath: String) {
        let startedAt = DebugInteractionLatencyProbe.now()
        AppLogger.shared.info(
            .library,
            "File detail opened",
            fields: [("kind", "subtitle"), ("file", URL.fromMediaPath(subtitlePath).lastPathComponent)]
        )
        let session: FileDetailDialogSession
        if let libraryDatabase,
           let items = try? libraryDatabase.fileDetailPairedItems(forSubtitlePath: subtitlePath),
           !items.isEmpty {
            let initialIndex = items.firstIndex(where: { !$0.isVideo && $0.path == subtitlePath }) ?? 0
            session = FileDetailDialogSession(
                pairedItems: items,
                initialSelectedIndex: initialIndex
            )
        } else {
            let url = URL.fromMediaPath(subtitlePath)
            let info = FileDetailSubtitleInfo(
                path: subtitlePath,
                name: url.lastPathComponent,
                fileSize: 0,
                format: SubtitleFormat(fileExtension: url.pathExtension) ?? .srt,
                encoding: "-",
                cueCount: 0,
                rawCueCount: 0,
                associatedVideoPath: nil,
                createdAt: nil,
                modifiedAt: nil
            )
            session = FileDetailDialogSession(kind: .subtitle(info))
        }
        presentFileDetailDialog(
            session,
            dialogID: "file_detail_subtitle",
            startedAt: startedAt
        )
    }

    private func presentFileDetailDialog(
        _ session: FileDetailDialogSession,
        dialogID: String,
        startedAt: UInt64
    ) {
        interfaceLayers.setOpen(.dialog, true)
        library.fileDetailSession = session
        reconcileWorkbenchAccessibilityFocus()
        reconcileDialogAccessibilityFocus()
        DebugInteractionLatencyProbe.beginDialogOpen(
            dialogID: dialogID,
            trigger: "get_info",
            startedAt: startedAt,
            syncPrepFinishedAt: DebugInteractionLatencyProbe.now()
        )
    }

    func closeFileDetailDialog() {
        library.fileDetailSession = nil
        reconcileDialogAccessibilityFocus()
        reconcileWorkbenchAccessibilityFocus()
    }
}
