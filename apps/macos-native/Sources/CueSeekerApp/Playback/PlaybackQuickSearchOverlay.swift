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
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onRequestFocus: () -> Void
    let onMoveUp: () -> Bool
    let onMoveDown: () -> Bool
    let onOpenResult: (SubtitleSearchResult) -> Void
    let onResultAppear: (SubtitleSearchResult) -> Void

    var body: some View {
        VStack(spacing: 8) {
            searchField

            if submittedQuery != nil {
                resultList
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
                onSubmit: onSubmit,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown
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
                onRequestFocus()
            }
        }
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
