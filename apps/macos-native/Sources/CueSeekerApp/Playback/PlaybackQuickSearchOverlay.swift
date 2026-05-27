import AppKit
import CueSeekerCore
import SwiftUI

struct PlaybackQuickSearchOverlay: View {
    @Binding var draft: String
    @Binding var isFocused: Bool
    let forcedTextUpdateID: Int
    let focusRequestID: Int
    let submittedQuery: String?
    let results: [SubtitleSearchResult]
    let selectedResultIndex: Int?
    let isSearching: Bool
    let currentSentence: String
    let aiState: PlaybackQuickSearchAIState
    let selectedChunkCountState: PlaybackQuickSearchChunkCountState
    let navigationState: PlaybackQuickSearchNavigationState
    let focusTarget: PlaybackQuickSearchFocusTarget
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onRequestFocus: () -> Void
    let onMoveUp: () -> Bool
    let onMoveDown: () -> Bool
    let onMoveLeft: () -> Bool
    let onMoveRight: (_ isAtEnd: Bool) -> Bool
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(spacing: 8) {
            searchField

            if submittedQuery != nil {
                resultList
            } else {
                aiPanel
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(PlaybackTheme.textSecondary)
                .frame(width: 32, height: 32)

            SearchTextView(
                text: $draft,
                placeholder: "Search subtitles",
                isFocused: $isFocused,
                forcedTextUpdateID: forcedTextUpdateID,
                focusRequestID: focusRequestID,
                font: .systemFont(ofSize: 30, weight: .semibold),
                textColor: NSColor.white.withAlphaComponent(0.94),
                placeholderColor: NSColor.white.withAlphaComponent(0.34),
                placesCursorAtEndOnFocusRequest: true,
                onSubmit: onSubmit,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onMoveLeft: onMoveLeft,
                onMoveRight: onMoveRight
            )
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)

            if !draft.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PlaybackTheme.textTertiary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 74)
        .background(quickSearchBackground)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            onRequestFocus()
        }
        .onAppear {
            DispatchQueue.main.async {
                if focusTarget == .input {
                    onRequestFocus()
                }
            }
        }
    }

    @ViewBuilder
    private var aiPanel: some View {
        switch aiState {
        case .hidden:
            if case .visible(let commands, let selectedIndex) = navigationState {
                aiPanelContainer {
                    aiNavigationOptionRow(
                        commands: commands,
                        selectedCommandIndex: selectedIndex,
                        isSelected: focusTarget == .navigation
                    )
                }
            } else {
                EmptyView()
            }
        case .loading:
            aiPanelContainer {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Chunking...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PlaybackTheme.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 13, leading: 18, bottom: 13, trailing: 18))
            }
        case .failed(let message):
            aiPanelContainer {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(PlaybackTheme.textSecondary)
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 13, leading: 18, bottom: 13, trailing: 18))
            }
        case .options(let chunks, let selectedChunkIndex, let selectedOption):
            aiOptionsPanel(
                chunks: chunks,
                selectedChunkIndex: selectedChunkIndex,
                selectedOption: selectedOption
            )
        }
    }

    private func aiOptionsPanel(
        chunks: [AIChunkItem],
        selectedChunkIndex: Int?,
        selectedOption: PlaybackQuickSearchAIOption?
    ) -> some View {
        aiPanelContainer {
            VStack(spacing: 0) {
                if !chunks.isEmpty {
                    selectedChunkDetailRow(chunks: chunks, selectedChunkIndex: selectedChunkIndex)
                    aiChunksOptionRow(
                        chunks: chunks,
                        selectedChunkIndex: selectedChunkIndex,
                        isSelected: focusTarget == .aiOption && selectedOption == .chunks
                    )
                }
                aiRefreshOptionRow(
                    hasChunks: !chunks.isEmpty,
                    selectedOption: focusTarget == .aiOption ? selectedOption : nil
                )
                if case .visible(let commands, let selectedIndex) = navigationState {
                    aiNavigationOptionRow(
                        commands: commands,
                        selectedCommandIndex: selectedIndex,
                        isSelected: focusTarget == .navigation
                    )
                }
            }
        }
    }

    private func aiNavigationOptionRow(
        commands: [PlaybackQuickSearchNavigationCommand],
        selectedCommandIndex: Int,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                quickSearchActionLabel(
                    navigationCommandLabel(for: command),
                    isSelected: isSelected && index == selectedCommandIndex
                )
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
        .background(optionRowBackground(isSelected: isSelected))
    }

    private func navigationCommandLabel(for command: PlaybackQuickSearchNavigationCommand) -> String {
        switch command {
        case .back: return "/back"
        case .forward: return "/forward"
        }
    }

    private func aiChunksOptionRow(
        chunks: [AIChunkItem],
        selectedChunkIndex: Int?,
        isSelected: Bool
    ) -> some View {
        QuickSearchChunkFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                Text(chunk.item)
                    .font(.system(size: 13.5, weight: index == selectedChunkIndex ? .semibold : .medium))
                    .foregroundStyle(index == selectedChunkIndex ? Color.white : Color.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == selectedChunkIndex ? PlaybackTheme.menuItemHighlight : Color.clear)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 18))
        .background(optionRowBackground(isSelected: isSelected))
    }

    private func aiRefreshOptionRow(
        hasChunks: Bool,
        selectedOption: PlaybackQuickSearchAIOption?
    ) -> some View {
        let isRowSelected = selectedOption == .refresh || selectedOption == .copy

        return VStack(alignment: .leading, spacing: 8) {
            Text(currentSentence.isEmpty ? "Current sentence" : currentSentence)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                quickSearchActionLabel(hasChunks ? "/rechunk" : "/chunk", isSelected: selectedOption == .refresh)
                quickSearchActionLabel("/copy", isSelected: selectedOption == .copy)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18))
        .background(optionRowBackground(isSelected: isRowSelected))
    }

    private func quickSearchActionLabel(_ label: String, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? PlaybackTheme.menuItemHighlight : Color.clear)
            )
    }

    private func optionRowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? PlaybackTheme.menuItemHighlight.opacity(0.78) : Color.clear)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
    }

    @ViewBuilder
    private func selectedChunkDetailRow(
        chunks: [AIChunkItem],
        selectedChunkIndex: Int?
    ) -> some View {
        HStack(spacing: 12) {
            if let selectedChunkIndex, chunks.indices.contains(selectedChunkIndex) {
                let selectedChunk = chunks[selectedChunkIndex]
                
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(PlaybackTheme.textSecondary)
                
                Text(selectedChunk.translation)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(PlaybackTheme.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 16)
                
                if let count = selectedChunkCount(for: selectedChunk) {
                    selectedChunkCountBadge(count: count)
                } else if isSelectedChunkCountLoading(for: selectedChunk) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
            } else {
                Text("Select a chunk to see details")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(PlaybackTheme.textTertiary)
                Spacer()
            }
        }
        .frame(height: 38)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .overlay(
            VStack {
                Spacer()
                Rectangle()
                    .fill(PlaybackTheme.textTertiary.opacity(0.18))
                    .frame(height: 0.5)
                    .padding(.horizontal, 18)
            }
        )
    }

    private func selectedChunkCountBadge(count: Int) -> some View {
        Text("\(count) results")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PlaybackTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(PlaybackTheme.capsuleFill)
            )
    }

    private func selectedChunkCount(for chunk: AIChunkItem) -> Int? {
        let query = normalizedCountQuery(for: chunk)
        guard case .exact(let countQuery, let count) = selectedChunkCountState,
              countQuery == query
        else {
            return nil
        }

        return count
    }

    private func isSelectedChunkCountLoading(for chunk: AIChunkItem) -> Bool {
        let query = normalizedCountQuery(for: chunk)
        guard case .loading(let countQuery) = selectedChunkCountState else {
            return false
        }

        return countQuery == query
    }

    private func normalizedCountQuery(for chunk: AIChunkItem) -> String {
        chunk.item.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func aiPanelContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(quickSearchBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var resultList: some View {
        VStack(spacing: 0) {
            if results.isEmpty {
                overlayStatus
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.element.entryID) { index, result in
                                PlaybackSidebarResultRow(
                                    rank: index + 1,
                                    result: result,
                                    query: submittedQuery ?? "",
                                    isSelected: index == selectedResultIndex,
                                    allowsHoverHighlight: false,
                                    onOpen: {
                                        onOpenResult(result)
                                    }
                                )
                                .id(result.entryID)
                                .onAppear {
                                    onResultAppear(result)
                                }
                            }
                        }
                        .padding(EdgeInsets(top: 6, leading: 8, bottom: 8, trailing: 8))
                    }
                    .frame(maxHeight: 380)
                    .onAppear {
                        scrollSelectedResultIntoView(proxy)
                    }
                    .onChange(of: selectedResultIndex) { _ in
                        scrollSelectedResultIntoView(proxy)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(quickSearchBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var overlayStatus: some View {
        if isSearching {
            ProgressView()
                .controlSize(.small)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
        } else {
            Text("No results")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PlaybackTheme.textSecondary)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity)
        }
    }

    private func scrollSelectedResultIntoView(_ proxy: ScrollViewProxy) {
        guard let selectedResultIndex,
              results.indices.contains(selectedResultIndex)
        else {
            return
        }

        let selectedResult = results[selectedResultIndex]
        withAnimation(.easeInOut(duration: 0.14)) {
            proxy.scrollTo(selectedResult.entryID, anchor: .center)
        }
    }

    private var quickSearchBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(PlaybackTheme.cinematicBacking)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(PlaybackTheme.textTertiary.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.42), radius: 24, y: 12)
    }
}

private struct QuickSearchChunkFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let childProposal = maxWidth.isFinite
            ? ProposedViewSize(width: maxWidth, height: nil)
            : ProposedViewSize.unspecified
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(childProposal)
            if rowWidth > 0, rowWidth + horizontalSpacing + size.width > maxWidth {
                totalHeight += rowHeight + verticalSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += (rowWidth > 0 ? horizontalSpacing : 0) + size.width
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(
            width: maxWidth.isFinite ? maxWidth : widestRow,
            height: totalHeight
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let childProposal = ProposedViewSize(width: bounds.width, height: nil)
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(childProposal)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
