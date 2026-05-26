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
            EmptyView()
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
        chunks: [String],
        selectedChunkIndex: Int?,
        selectedOption: PlaybackQuickSearchAIOption?
    ) -> some View {
        aiPanelContainer {
            VStack(spacing: 0) {
                if !chunks.isEmpty {
                    aiChunksOptionRow(
                        chunks: chunks,
                        selectedChunkIndex: selectedChunkIndex,
                        isSelected: focusTarget == .aiOption && selectedOption == .chunks
                    )
                }
                aiRefreshOptionRow(isSelected: focusTarget == .aiOption && selectedOption == .refresh)
            }
        }
    }

    private func aiChunksOptionRow(
        chunks: [String],
        selectedChunkIndex: Int?,
        isSelected: Bool
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                    Text(chunk)
                        .font(.system(size: 13.5, weight: index == selectedChunkIndex ? .semibold : .medium))
                        .foregroundStyle(index == selectedChunkIndex ? Color.white : Color.white.opacity(0.88))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(index == selectedChunkIndex ? PlaybackTheme.menuItemHighlight : Color.clear)
                        )
                }
            }
            .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
        }
        .background(optionRowBackground(isSelected: isSelected))
    }

    private func aiRefreshOptionRow(isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(currentSentence.isEmpty ? "Current sentence" : currentSentence)
                .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(Color.white.opacity(isSelected ? 0.96 : 0.86))
                .lineLimit(1)
            Text("/chunks")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(isSelected ? 0.78 : 0.46))
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 11, leading: 18, bottom: 11, trailing: 18))
        .background(optionRowBackground(isSelected: isSelected))
    }

    private func optionRowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? PlaybackTheme.menuItemHighlight.opacity(0.78) : Color.clear)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
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
