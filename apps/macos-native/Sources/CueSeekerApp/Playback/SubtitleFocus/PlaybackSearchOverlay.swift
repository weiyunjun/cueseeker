import SwiftUI

struct PlaybackSearchOverlay: View {
    @ObservedObject var session: PlaybackSubtitleFocusSessionStore
    @ObservedObject var searchStore: SearchStore
    let uiProbeScope: String?
    let onActivateSearch: () -> Void
    let onUpdateSearchQuery: (String) -> Void
    let onExecuteAction: (PlaybackSubtitleFocusActionExecution) -> Bool

    var body: some View {
        VStack(spacing: WorkbenchControlMetrics.redesignSpacing3) {
            PlaybackSearchBox(
                text: Binding(
                    get: { searchStore.searchQuery },
                    set: { onUpdateSearchQuery($0) }
                )
            )
            .padding(.horizontal, PlaybackSubtitleFocusMetrics.contentInset)

            if let window = session.searchWindow {
                PlaybackCueResultOverlay(
                    session: session,
                    windowStore: window,
                    module: .search,
                    showsSequenceNumber: false,
                    contentTopInset: 0,
                    contentBottomInset: PlaybackSubtitleFocusMetrics.contentInset,
                    uiProbeScope: uiProbeScope,
                    onExecuteAction: onExecuteAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PlaybackTheme.subtitleFocusOverlayBackground
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, PlaybackSubtitleFocusMetrics.contentInset)
        .background(PlaybackTheme.subtitleFocusOverlayBackground)
        .onAppear(perform: onActivateSearch)
    }
}

private struct PlaybackSearchBox: View {
    @Binding var text: String

    @FocusState private var isFocused: Bool
    @State private var isClearHovered = false
    @State private var focusRequest = 0

    var body: some View {
        HStack(spacing: WorkbenchControlMetrics.redesignSpacing2) {
            Image(systemName: "magnifyingglass")
                .font(.system(
                    size: WorkbenchControlMetrics.redesignControlIconSize,
                    weight: .regular
                ))
                .foregroundStyle(WorkbenchRedesignColors.iconDefault)

            TextField(
                "",
                text: $text,
                prompt: Text("Search")
                    .foregroundColor(WorkbenchRedesignColors.textPlaceholder)
            )
            .textFieldStyle(.plain)
            .font(.system(
                size: WorkbenchControlMetrics.redesignFontSizeControl,
                weight: .regular
            ))
            .foregroundStyle(WorkbenchRedesignColors.textPrimary)
            .focused($isFocused)
            .accessibilityIdentifier("playback-search-input")

            if !text.isEmpty {
                Button {
                    text = ""
                    focusRequest += 1
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(
                            size: WorkbenchControlMetrics.inlineClearSymbolFontSizeMacOS,
                            weight: .bold
                        ))
                        .frame(
                            width: WorkbenchControlMetrics.inlineClearIconSize,
                            height: WorkbenchControlMetrics.inlineClearIconSize
                        )
                        .foregroundStyle(WorkbenchRedesignColors.iconDefault)
                        .frame(
                            width: WorkbenchControlMetrics.redesignInlineClearButtonSize,
                            height: WorkbenchControlMetrics.redesignInlineClearButtonSize
                        )
                        .background {
                            if isClearHovered {
                                RoundedRectangle(
                                    cornerRadius: WorkbenchControlMetrics
                                        .redesignInlineClearButtonRadius,
                                    style: .continuous
                                )
                                .fill(WorkbenchRedesignColors.bgHover)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .onHover { isClearHovered = $0 }
                .pointerOnHover(isEnabled: true)
                .accessibilityLabel("Clear Search")
                .accessibilityIdentifier("playback-search-clear")
            }
        }
        .padding(
            .horizontal,
            WorkbenchControlMetrics.redesignControlPaddingX
        )
        .frame(height: WorkbenchControlMetrics.redesignSearchHeight)
        .background {
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignSearchRadius,
                style: .continuous
            )
            .fill(WorkbenchRedesignColors.bgSurface)
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: WorkbenchControlMetrics.redesignSearchRadius,
                style: .continuous
            )
            .strokeBorder(WorkbenchRedesignColors.borderControl, lineWidth: 1)
        }
        .subtitleTableTextSelectionInteractiveRegion(isActive: true)
        .task(id: focusRequest) {
            await Task.yield()
            guard !Task.isCancelled else {
                return
            }
            isFocused = true
        }
    }
}
