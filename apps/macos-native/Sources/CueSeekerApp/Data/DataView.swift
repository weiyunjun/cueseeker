import SwiftUI
import CueSeekerCore

struct DataView: View {
    @EnvironmentObject private var appState: AppCoordinator
    @State private var loadState: DataLoadState = .loading
    @State private var roots: [IndexedContentRoot] = []
    @State private var expandedRootIDs: Set<Int64> = []
    @State private var expandedFolderIDs: Set<Int64> = []
    @State private var expandedObjectIDs: Set<Int64> = []

    var body: some View {
        DataPageLayout {
            dataContent
        }
        .task {
            await loadContent()
        }
    }

    @ViewBuilder
    private var dataContent: some View {
        switch loadState {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .frame(
                    maxWidth: .infinity,
                    minHeight: DataTreeLayout.stateMinimumHeight
                )
        case .failed(let message):
            WorkbenchEmptyHint(message: message)
                .frame(minHeight: DataTreeLayout.stateMinimumHeight)
        case .loaded where roots.isEmpty:
            WorkbenchEmptyHint(message: "No indexed content.")
                .frame(minHeight: DataTreeLayout.stateMinimumHeight)
        case .loaded:
            DataTreeView(
                roots: roots,
                expandedRootIDs: $expandedRootIDs,
                expandedFolderIDs: $expandedFolderIDs,
                expandedObjectIDs: $expandedObjectIDs
            )
        }
    }

    private func loadContent() async {
        loadState = .loading
        roots = []
        expandedRootIDs = []
        expandedFolderIDs = []
        expandedObjectIDs = []

        do {
            let loadedRoots = try await appState.indexedContentTree()
            try Task.checkCancellation()
            roots = loadedRoots
            expandedRootIDs = Set(loadedRoots.map(\.id))
            loadState = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadState = .failed(AppCoordinator.errorMessage(for: error))
        }
    }
}

private enum DataLoadState: Equatable {
    case loading
    case loaded
    case failed(String)
}

private struct DataPageLayout<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            WorkbenchScrollView([.vertical, .horizontal]) {
                VStack(
                    alignment: .leading,
                    spacing: WorkbenchControlMetrics.redesignSpacing4
                ) {
                    WorkbenchPageTitle("Data")
                    content
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(
                    .horizontal,
                    WorkbenchControlMetrics.redesignWorkbenchPageHorizontalPadding
                )
                .padding(
                    .top,
                    WorkbenchControlMetrics.redesignWorkbenchPageTopPadding
                )
                .padding(
                    .bottom,
                    WorkbenchControlMetrics.redesignWorkbenchPageBottomPadding
                )
                .frame(
                    width: max(
                        geometry.size.width,
                        AppShellLayout.pageContentMinimumWidth
                    ),
                    alignment: .topLeading
                )
                .frame(
                    minHeight: geometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        .background(WorkbenchRedesignColors.bgSurface)
    }
}

private struct DataTreeView: View {
    let roots: [IndexedContentRoot]
    @Binding var expandedRootIDs: Set<Int64>
    @Binding var expandedFolderIDs: Set<Int64>
    @Binding var expandedObjectIDs: Set<Int64>

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(roots) { root in
                DataTreeRow(
                    level: 0,
                    title: root.displayPath,
                    systemImage: "folder",
                    isExpanded: expandedRootIDs.contains(root.id),
                    isFile: false,
                    isHoverEnabled: false,
                    onToggle: {
                        toggle(root.id, in: $expandedRootIDs)
                    }
                )

                if expandedRootIDs.contains(root.id) {
                    ForEach(root.folders) { folder in
                        DataTreeRow(
                            level: 1,
                            title: folder.displayPath,
                            systemImage: "folder",
                            isExpanded: expandedFolderIDs.contains(folder.id),
                            isFile: false,
                            isHoverEnabled: false,
                            onToggle: {
                                toggle(folder.id, in: $expandedFolderIDs)
                            }
                        )

                        if expandedFolderIDs.contains(folder.id) {
                            ForEach(folder.objects) { object in
                                DataObjectGroup(
                                    object: object,
                                    isExpanded: expandedObjectIDs.contains(object.id),
                                    showsDivider: object.id != folder.objects.last?.id,
                                    onToggle: {
                                        toggle(object.id, in: $expandedObjectIDs)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func toggle(_ id: Int64, in values: Binding<Set<Int64>>) {
        if values.wrappedValue.contains(id) {
            values.wrappedValue.remove(id)
        } else {
            values.wrappedValue.insert(id)
        }
    }
}

private struct DataObjectGroup: View {
    let object: IndexedContentObject
    let isExpanded: Bool
    let showsDivider: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DataTreeRow(
                level: 2,
                title: object.displayTitle,
                systemImage: "rectangle.stack",
                isExpanded: isExpanded,
                isFile: false,
                isHoverEnabled: true,
                onToggle: onToggle
            )

            if isExpanded {
                DataTreeRow(
                    level: 3,
                    title: object.videoName,
                    systemImage: "film",
                    isExpanded: nil,
                    isFile: true,
                    isHoverEnabled: true,
                    onToggle: nil
                )

                ForEach(object.subtitles) { subtitle in
                    DataTreeRow(
                        level: 3,
                        title: subtitle.name,
                        systemImage: "captions.bubble",
                        isExpanded: nil,
                        isFile: true,
                        isHoverEnabled: true,
                        onToggle: nil
                    )
                }
            }

            if showsDivider {
                Rectangle()
                    .fill(WorkbenchRedesignColors.borderDivider)
                    .frame(height: WorkbenchControlMetrics.hairlineWidth)
                    .padding(
                        .leading,
                        DataTreeLayout.iconLeading(forLevel: 3)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct DataTreeRow: View {
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
                .accessibilityAction(named: Text("Toggle"), onToggle)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear
                .frame(width: DataTreeLayout.indent(forLevel: level))

            disclosureIndicator
                .frame(
                    width: DataTreeLayout.iconSize,
                    height: DataTreeLayout.iconSize
                )

            Color.clear
                .frame(width: DataTreeLayout.itemSpacing)

            Image(systemName: systemImage)
                .font(.system(
                    size: DataTreeLayout.iconSize,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                .frame(
                    width: DataTreeLayout.iconSize,
                    height: DataTreeLayout.iconSize,
                    alignment: .top
                )
                .accessibilityHidden(true)

            Color.clear
                .frame(width: DataTreeLayout.itemSpacing)

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
        .padding(.vertical, DataTreeLayout.rowVerticalPadding)
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
        .onHover { hovering in
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
                .foregroundStyle(WorkbenchRedesignColors.iconMuted)
                .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private var accessibilityValue: String {
        guard let isExpanded else {
            return ""
        }
        return isExpanded ? "Expanded" : "Collapsed"
    }
}

private enum DataTreeLayout {
    static let iconSize = WorkbenchControlMetrics.redesignControlIconSize
    static let itemSpacing = WorkbenchControlMetrics.redesignSpacing2
    static let levelIndent = WorkbenchControlMetrics.redesignSpacing6
    static let rowVerticalPadding = WorkbenchControlMetrics.redesignSpacing2
    static let stateMinimumHeight = WorkbenchControlMetrics.redesignHeight * 4

    static func indent(forLevel level: Int) -> CGFloat {
        CGFloat(level) * levelIndent
    }

    static func iconLeading(forLevel level: Int) -> CGFloat {
        indent(forLevel: level) + iconSize + itemSpacing
    }
}
