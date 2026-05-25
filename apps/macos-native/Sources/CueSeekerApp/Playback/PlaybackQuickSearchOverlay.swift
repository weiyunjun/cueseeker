import AppKit
import SwiftUI

struct PlaybackQuickSearchOverlay: View {
    @Binding var draft: String
    @Binding var isFocused: Bool
    let forcedTextUpdateID: Int
    let focusRequestID: Int
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onRequestFocus: () -> Void

    var body: some View {
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
                onSubmit: onSubmit
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
