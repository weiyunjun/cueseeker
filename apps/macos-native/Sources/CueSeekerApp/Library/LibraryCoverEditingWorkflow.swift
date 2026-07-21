import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

enum LibraryCoverEditingCopy {
    static let dialogTitle = "Edit Cover"
    static let hint = "Support: JPG, JPEG, PNG, and GIF no more than 20 MB."
    static let cancelButtonTitle = "Cancel"
    static let saveButtonTitle = "Save"
}

@MainActor
final class LibraryCoverEditingSession: ObservableObject, Identifiable {
    let id = UUID()
    let target: LibraryUserCoverTarget
    let source: LibraryUserCoverSource
    @Published var cropRect: CGRect
    @Published var isSaving = false

    init(target: LibraryUserCoverTarget, source: LibraryUserCoverSource) {
        self.target = target
        self.source = source
        self.cropRect = LibraryCoverCropGeometry.initialCropRect(imageSize: source.pixelSize)
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
