import SwiftUI
import CueSeekerCore

/// One open rename dialog: what is being renamed, the name typed so far, and
/// what the dialog has said about it. Presented like the other dialog
/// sessions: the page writes it, the window presents it.
@MainActor
final class LibraryRenameSession: ObservableObject, Identifiable {
    enum Target {
        case folder(IndexedContentFolder)
        case files(IndexedContentObject, baseName: String)
    }

    let id = UUID()
    let target: Target
    @Published var newName: String
    @Published var validationMessage: String?
    @Published private(set) var hasAttemptedValidation = false

    init(folder: IndexedContentFolder) {
        target = .folder(folder)
        newName = URL(fileURLWithPath: folder.folderPath).lastPathComponent
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
        case .folder:
            L("rename.folder")
        case .files:
            L("rename.files")
        }
    }

    /// The static line above the field: the folder's complete path, or the
    /// name the video and its subtitles share.
    var currentText: String {
        switch target {
        case .folder(let folder):
            folder.folderPath
        case .files(_, let baseName):
            baseName
        }
    }

    private var currentName: String {
        switch target {
        case .folder(let folder):
            URL(fileURLWithPath: folder.folderPath).lastPathComponent
        case .files(_, let baseName):
            baseName
        }
    }

    var request: LibraryRenameRequest {
        switch target {
        case .folder(let folder):
            .folder(path: folder.folderPath, newName: newName)
        case .files(let object, _):
            .fileGroup(videoPath: object.videoPath, newBaseName: newName)
        }
    }

    var oldPaths: [String] {
        switch target {
        case .folder(let folder):
            [folder.folderPath]
        case .files(let object, _):
            [object.videoPath] + object.subtitles.map(\.path)
        }
    }

    var newPaths: [String] {
        switch target {
        case .folder(let folder):
            [
                URL(fileURLWithPath: folder.folderPath)
                    .deletingLastPathComponent()
                    .appendingPathComponent(newName)
                    .path
            ]
        case .files(_, let baseName):
            oldPaths.map { path in
                let url = URL(fileURLWithPath: path)
                guard let renamed = LibraryFileGroupNaming.renamedFileName(
                    url.lastPathComponent,
                    baseName: baseName,
                    newBaseName: newName
                ) else {
                    return path
                }
                return url.deletingLastPathComponent().appendingPathComponent(renamed).path
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

/// The rename dialog: the Shiori List Editor's form column and footer, without
/// the cover column, with the current name under its own label above the field.
struct LibraryRenameDialog: View {
    @ObservedObject var session: LibraryRenameSession
    let onConfirm: () -> Void
    let onClose: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
            WorkbenchDialogHeader(title: session.title)

            VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing4) {
                VStack(alignment: .leading, spacing: WorkbenchControlMetrics.redesignSpacing1) {
                    WorkbenchFormLabel(text: L("rename.current_name"))

                    Text(session.currentText)
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

                WorkbenchFormTextField(
                    label: L("rename.new_name"),
                    placeholder: "",
                    text: $session.newName,
                    validationMessage: session.validationMessage,
                    focus: $isNameFocused
                )
                .accessibilityIdentifier("rename-new-name")
            }

            actions
        }
        .padding(.top, WorkbenchControlMetrics.redesignDialogTopPadding)
        .padding(.horizontal, WorkbenchControlMetrics.redesignDialogInset)
        .padding(.bottom, WorkbenchControlMetrics.redesignDialogInset)
        // One column: the form region plus the two insets is the whole width,
        // so the field's right edge is the last button's right edge.
        .frame(
            width: WorkbenchControlMetrics.redesignDialogFormRegionWidth
                + 2 * WorkbenchControlMetrics.redesignDialogInset,
            alignment: .topLeading
        )
        .background(WorkbenchRedesignColors.bgSurface)
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
