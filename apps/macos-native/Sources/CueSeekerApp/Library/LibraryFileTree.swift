import SwiftUI
import CueSeekerCore

/// What the Edit tree's context menus do. The tree shows the menus only when
/// it is given these.
struct LibraryFileTreeRenameActions {
    /// Off while an Index, a root removal or a compaction runs.
    let isEnabled: Bool
    let renameFolder: (IndexedContentFolder) -> Void
    let renameFiles: (IndexedContentObject) -> Void
}

/// The Library File tree. The overview shows every root path, a folder detail
/// shows only its own folder, the File page's Edit tab shows every folder at
/// its full path, and all three use this one implementation.
struct LibraryFileTree: View {
    enum Scope: Equatable {
        case roots([IndexedContentRoot])
        case folder(IndexedContentFolder)
        /// Every indexed folder, labelled with its complete path and without
        /// the root level above it.
        case editFolders([IndexedContentFolder])
    }

    let scope: Scope
    var renameActions: LibraryFileTreeRenameActions? = nil
    @Environment(\.libraryCardContextMenuOpen) private var openContextMenu
    /// The rows the reader flipped away from their default disclosure. Rows
    /// keep their default until then, so no state has to be seeded when the
    /// tree arrives.
    @State private var toggledRows: Set<RowID> = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            switch scope {
            case .roots(let roots):
                ForEach(roots) { root in
                    rootRows(root)
                }
            case .folder(let folder):
                folderRows(folder, level: 0, isExpandedByDefault: true)
            case .editFolders(let folders):
                ForEach(folders) { folder in
                    editFolderRows(folder)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func rootRows(_ root: IndexedContentRoot) -> some View {
        let isRootExpanded = isExpanded(.root(root.id), byDefault: true)

        LibraryFileTreeRow(
            level: 0,
            title: root.displayPath,
            systemImage: "folder",
            isExpanded: isRootExpanded,
            isFile: false,
            isHoverEnabled: false,
            onToggle: { toggle(.root(root.id)) }
        )

        if isRootExpanded {
            ForEach(root.folders) { folder in
                folderRows(folder, level: 1, isExpandedByDefault: false)
            }
        }
    }

    @ViewBuilder
    private func folderRows(
        _ folder: IndexedContentFolder,
        level: Int,
        isExpandedByDefault: Bool
    ) -> some View {
        let isFolderExpanded = isExpanded(
            .folder(folder.id),
            byDefault: isExpandedByDefault
        )

        LibraryFileTreeRow(
            level: level,
            title: folder.displayPath,
            systemImage: "folder",
            isExpanded: isFolderExpanded,
            isFile: false,
            isHoverEnabled: false,
            onToggle: { toggle(.folder(folder.id)) }
        )

        if isFolderExpanded {
            ForEach(folder.objects) { object in
                LibraryFileTreeObjectGroup(
                    object: object,
                    level: level + 1,
                    isExpanded: isExpanded(.object(object.id), byDefault: false),
                    showsDivider: object.id != folder.objects.last?.id,
                    onToggle: { toggle(.object(object.id)) }
                )
            }
        }
    }

    @ViewBuilder
    private func editFolderRows(_ folder: IndexedContentFolder) -> some View {
        let isFolderExpanded = isExpanded(.folder(folder.id), byDefault: false)

        LibraryFileTreeRow(
            level: 0,
            title: folder.folderPath,
            systemImage: "folder",
            isExpanded: isFolderExpanded,
            isFile: false,
            isHoverEnabled: true,
            onToggle: { toggle(.folder(folder.id)) }
        )
        .libraryFileTreeContextMenu(
            items: folderMenuItems(folder),
            ownerID: "edit-folder-\(folder.id)",
            open: openContextMenu
        )

        if isFolderExpanded {
            ForEach(folder.objects) { object in
                LibraryFileTreeObjectGroup(
                    object: object,
                    level: 1,
                    isExpanded: isExpanded(.object(object.id), byDefault: false),
                    showsDivider: object.id != folder.objects.last?.id,
                    onToggle: { toggle(.object(object.id)) },
                    contextMenuItems: objectMenuItems(object)
                )
            }
        }
    }

    private func folderMenuItems(_ folder: IndexedContentFolder) -> [LibraryCardContextMenuItem]? {
        renameActions.map { actions in
            [
                LibraryCardContextMenuItem(
                    title: L("rename.folder"),
                    systemImage: "pencil",
                    isEnabled: actions.isEnabled
                ) {
                    actions.renameFolder(folder)
                }
            ]
        }
    }

    private func objectMenuItems(_ object: IndexedContentObject) -> [LibraryCardContextMenuItem]? {
        renameActions.map { actions in
            [
                LibraryCardContextMenuItem(
                    title: L("rename.files"),
                    systemImage: "pencil",
                    isEnabled: actions.isEnabled
                ) {
                    actions.renameFiles(object)
                }
            ]
        }
    }

    private func isExpanded(_ row: RowID, byDefault defaultValue: Bool) -> Bool {
        defaultValue != toggledRows.contains(row)
    }

    private func toggle(_ row: RowID) {
        if toggledRows.contains(row) {
            toggledRows.remove(row)
        } else {
            toggledRows.insert(row)
        }
    }

    /// Roots, folders and objects come from different tables, so their ids may
    /// collide and the kind has to be part of the key.
    private enum RowID: Hashable {
        case root(Int64)
        case folder(Int64)
        case object(Int64)
    }
}

private struct LibraryFileTreeObjectGroup: View {
    let object: IndexedContentObject
    let level: Int
    let isExpanded: Bool
    let showsDivider: Bool
    let onToggle: () -> Void
    /// The Edit tree's menu; the object row and its file rows all open it.
    var contextMenuItems: [LibraryCardContextMenuItem]? = nil
    @Environment(\.libraryCardContextMenuOpen) private var openContextMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryFileTreeRow(
                level: level,
                title: object.displayTitle,
                systemImage: "rectangle.stack",
                isExpanded: isExpanded,
                isFile: false,
                isHoverEnabled: true,
                onToggle: onToggle
            )
            .libraryFileTreeContextMenu(
                items: contextMenuItems,
                ownerID: "edit-object-\(object.id)",
                open: openContextMenu
            )

            if isExpanded {
                LibraryFileTreeRow(
                    level: level + 1,
                    title: object.videoName,
                    systemImage: "film",
                    isExpanded: nil,
                    isFile: true,
                    isHoverEnabled: true,
                    onToggle: nil
                )
                .libraryFileTreeContextMenu(
                    items: contextMenuItems,
                    ownerID: "edit-video-\(object.id)",
                    open: openContextMenu
                )

                ForEach(object.subtitles) { subtitle in
                    LibraryFileTreeRow(
                        level: level + 1,
                        title: subtitle.name,
                        systemImage: "captions.bubble",
                        isExpanded: nil,
                        isFile: true,
                        isHoverEnabled: true,
                        onToggle: nil
                    )
                    .libraryFileTreeContextMenu(
                        items: contextMenuItems,
                        ownerID: "edit-subtitle-\(subtitle.id)",
                        open: openContextMenu
                    )
                }
            }

            if showsDivider {
                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(height: WorkbenchControlMetrics.hairlineWidth)
                    .padding(
                        .leading,
                        LibraryFileTreeLayout.iconLeading(forLevel: level + 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private extension View {
    /// The card context menu on a tree row, when the tree has one to offer and
    /// sits inside a host that can open it.
    @ViewBuilder
    func libraryFileTreeContextMenu(
        items: [LibraryCardContextMenuItem]?,
        ownerID: String,
        open: (([LibraryCardContextMenuItem], CGPoint, String) -> Void)?
    ) -> some View {
        if let items, let open {
            libraryCardContextMenuTrigger(
                isEnabled: true,
                ownerID: ownerID,
                items: items,
                openContextMenu: open
            )
        } else {
            self
        }
    }
}

private struct LibraryFileTreeRow: View {
    let level: Int
    let title: String
    let systemImage: String
    let isExpanded: Bool?
    let isFile: Bool
    let isHoverEnabled: Bool
    let onToggle: (() -> Void)?

    @State private var isHovered = false

    @ViewBuilder
    var body: some View {
        if let onToggle {
            rowContent
                .onTapGesture(perform: onToggle)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: Text(L("library.file.toggle")), onToggle)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear
                .frame(width: LibraryFileTreeLayout.indent(forLevel: level))

            disclosureIndicator
                .frame(
                    width: LibraryFileTreeLayout.iconSize,
                    height: LibraryFileTreeLayout.iconSize
                )

            Color.clear
                .frame(width: LibraryFileTreeLayout.itemSpacing)

            Image(systemName: systemImage)
                .font(.system(
                    size: LibraryFileTreeLayout.iconSize,
                    weight: WorkbenchControlMetrics.redesignControlIconWeight
                ))
                .foregroundStyle(WorkbenchRedesignColors.textSecondary)
                .frame(
                    width: LibraryFileTreeLayout.iconSize,
                    height: LibraryFileTreeLayout.iconSize,
                    alignment: .top
                )
                .accessibilityHidden(true)

            Color.clear
                .frame(width: LibraryFileTreeLayout.itemSpacing)

            Text(title)
                .font(.system(
                    size: WorkbenchControlMetrics.redesignFontSizeBody,
                    weight: isFile
                        ? .regular
                        : WorkbenchControlMetrics.redesignFontWeightControl
                ))
                .foregroundStyle(
                    isFile
                        ? WorkbenchRedesignColors.textSecondary
                        : WorkbenchRedesignColors.textPrimary
                )
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.vertical, LibraryFileTreeLayout.rowVerticalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkbenchControlMetrics.redesignHeight,
            alignment: .topLeading
        )
        .background(
            isHovered && isHoverEnabled
                ? WorkbenchRedesignColors.rowHover
                : Color.clear
        )
        .contentShape(Rectangle())
        .onPointerHover { hovering in
            isHovered = isHoverEnabled && hovering
        }
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var disclosureIndicator: some View {
        if let isExpanded {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignSelectIndicatorSymbolFontSizeMacOS,
                    weight: WorkbenchControlMetrics.redesignSelectIndicatorWeightMacOS
                ))
                .foregroundStyle(WorkbenchRedesignColors.textMuted)
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private var accessibilityValue: String {
        guard let isExpanded else {
            return ""
        }
        return isExpanded
            ? L("library.file.expanded")
            : L("library.file.collapsed")
    }
}

private enum LibraryFileTreeLayout {
    static let iconSize = WorkbenchControlMetrics.redesignControlIconSize
    static let itemSpacing = WorkbenchControlMetrics.redesignSpacing2
    static let levelIndent = WorkbenchControlMetrics.redesignSpacing6
    static let rowVerticalPadding = WorkbenchControlMetrics.redesignSpacing2

    static func indent(forLevel level: Int) -> CGFloat {
        CGFloat(level) * levelIndent
    }

    static func iconLeading(forLevel level: Int) -> CGFloat {
        indent(forLevel: level) + iconSize + itemSpacing
    }
}
