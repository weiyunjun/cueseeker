import SwiftUI
import CueSeekerCore

/// One open rename dialog: what is being renamed, the name typed so far, and
/// what the dialog has said about it. Presented like the other dialog
/// sessions: the page writes it, the window presents it.
@MainActor
final class LibraryRenameSession: ObservableObject, Identifiable {
    enum Target {
        case folder(IndexedContentFolder)
        case rootFolder(URL)
        case files(IndexedContentObject, baseName: String)
    }

    let id = UUID()
    let target: Target
    @Published var newName: String
    @Published var validationMessage: String?
    @Published private(set) var hasAttemptedValidation = false

    init(folder: IndexedContentFolder) {
        target = .folder(folder)
        newName = LibraryRenamer.lastPathComponent(of: folder.folderPath)
    }

    init(rootFolder: URL) {
        target = .rootFolder(rootFolder)
        newName = IndexingStore.displayName(for: rootFolder)
    }

    /// Nil when the video and its subtitles share no base name, which the
    /// index rules do not produce; the menu item then does nothing.
    init?(object: IndexedContentObject) {
        guard let baseName = LibraryFileGroupNaming.commonBaseName(
            videoName: object.videoName,
            subtitleNames: object.subtitles.map(\.name)
        ) else {
            return nil
        }
        target = .files(object, baseName: baseName)
        newName = baseName
    }

    var title: String {
        switch target {
        case .folder, .rootFolder:
            L("rename.folder")
        case .files:
            L("rename.files")
        }
    }

    /// The static Current Name value above the field: the folder's name, or the
    /// base name the video and its subtitles share.
    var currentName: String {
        switch target {
        case .folder(let folder):
            LibraryRenamer.lastPathComponent(of: folder.folderPath)
        case .rootFolder(let url):
            IndexingStore.displayName(for: url)
        case .files(_, let baseName):
            baseName
        }
    }

    var request: LibraryRenameRequest {
        switch target {
        case .folder(let folder):
            .folder(path: folder.folderPath, newName: newName)
        case .rootFolder(let url):
            .folder(path: url.mediaPath, newName: newName)
        case .files(let object, _):
            .fileGroup(videoPath: object.videoPath, newBaseName: newName)
        }
    }

    var oldPaths: [String] {
        switch target {
        case .folder(let folder):
            [folder.folderPath]
        case .rootFolder(let url):
            [url.mediaPath]
        case .files(let object, _):
            [object.videoPath] + object.subtitles.map(\.path)
        }
    }

    var newPaths: [String] {
        switch target {
        case .folder(let folder):
            [LibraryRenamer.replacingLastPathComponent(of: folder.folderPath, with: newName)]
        case .rootFolder(let url):
            [LibraryRenamer.replacingLastPathComponent(of: url.mediaPath, with: newName)]
        case .files(_, let baseName):
            oldPaths.map { path in
                let fileName = LibraryRenamer.lastPathComponent(of: path)
                guard let renamed = LibraryFileGroupNaming.renamedFileName(
                    fileName,
                    baseName: baseName,
                    newBaseName: newName
                ) else {
                    return path
                }
                return LibraryRenamer.replacingLastPathComponent(of: path, with: renamed)
            }
        }
    }

    /// Applies the name rules and shows the first one broken. From the first
    /// attempt on, every keystroke is checked again.
    @discardableResult
    func validate() -> Bool {
        hasAttemptedValidation = true
        switch LibraryRenameNameValidator.validate(newName, currentName: currentName) {
        case nil:
            validationMessage = nil
            return true
        case .empty:
            validationMessage = L("rename.validation.empty")
        case .unchanged:
            validationMessage = L("rename.validation.unchanged")
        case .invalid:
            validationMessage = L("rename.validation.invalid")
        }
        return false
    }
}

/// The rename dialog: a form column and footer, with the current name under its
/// own label above the field.
struct LibraryRenameDialog: View {
    @ObservedObject var session: LibraryRenameSession
    let onConfirm: () -> Void
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: session.title)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                HStack(alignment: .firstTextBaseline, spacing: WorkbenchControlMetrics.redesignSpacing3) {
                    WorkbenchFormLabel(text: L("rename.current_name"))
                        .frame(width: WorkbenchControlMetrics.redesignFormLabelWidth, alignment: .leading)

                    Text(session.currentName)
                        .font(.system(
                            size: WorkbenchControlMetrics.redesignFontSizeControl,
                            weight: .regular
                        ))
                        .foregroundStyle(WorkbenchRedesignColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("rename-current-name")
                }

                WorkbenchDialogFormTextField(
                    label: L("rename.new_name"),
                    placeholder: "",
                    text: $session.newName,
                    validationMessage: session.validationMessage,
                    reservesValidationLine: true,
                    focus: $isNameFocused
                )
                .accessibilityIdentifier("rename-new-name")
            }

            actions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        // One column across the content width, so the field's right edge is
        // the last button's right edge.
        .workbenchDialogWidth(WorkbenchControlMetrics.redesignDialogWidthMedium)
        .background(WorkbenchRedesignColors.bgDialog)
        .workbenchDialogCloseButton(onClose: onClose)
        .onAppear {
            isNameFocused = true
        }
        .onChange(of: session.newName) { _ in
            if session.hasAttemptedValidation {
                session.validate()
            }
        }
        .subtitleTableTextSelectionNonInteractiveRegion()
    }

    private var actions: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Spacer(minLength: 0)

            WorkbenchButton(
                title: L("common.cancel"),
                isRedesign: true,
                action: onClose
            )
            .keyboardShortcut(.cancelAction)

            WorkbenchPrimaryButton(
                title: L("rename.confirm"),
                action: confirm
            )
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("rename-confirm")
        }
    }

    private func confirm() {
        guard session.validate() else {
            isNameFocused = true
            return
        }
        onConfirm()
    }
}
