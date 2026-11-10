import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum LibraryCoverEditingCopy {
    static var dialogTitle: String { L("cover.edit_title") }
    static var chooseImageActionTitle: String { L("cover.choose_image") }
    static let editIcon = AppIcon.pencilSimple
    static var hint: String { L("cover.support_note") }
    static var cancelButtonTitle: String { L("common.cancel") }
    static var saveButtonTitle: String { L("cover.save") }
}

@MainActor
final class LibraryCoverEditingSession: ObservableObject, Identifiable {
    let id = UUID()
    let target: LibraryUserCoverTarget
    let currentCoverPath: String?
    let currentCoverRevision: String?
    @Published private(set) var selectedSource: LibraryUserCoverSource?
    @Published var cropRect = CGRect.zero
    @Published var isSaving = false

    init(
        target: LibraryUserCoverTarget,
        currentCoverPath: String?,
        currentCoverRevision: String?
    ) {
        self.target = target
        self.currentCoverPath = currentCoverPath
        self.currentCoverRevision = currentCoverRevision
    }

    var canSave: Bool {
        selectedSource != nil && !isSaving
    }

    func selectSource(_ source: LibraryUserCoverSource) {
        selectedSource = source
        cropRect = LibraryCoverCropGeometry.initialCropRect(imageSize: source.pixelSize)
    }
}

enum LibraryCoverOpenPanelPolicy {
    static let allowedContentTypes: [UTType] = [.jpeg, .png, .gif]

    static func shouldEnable(_ url: URL) -> Bool {
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return true
        }
        return (try? LibraryUserCoverProcessor.validateSourceFile(at: url)) != nil
    }
}

final class LibraryCoverOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        LibraryCoverOpenPanelPolicy.shouldEnable(url)
    }
}
