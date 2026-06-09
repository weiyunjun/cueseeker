import SwiftUI

struct SettingsPlayCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var gapDraft = ""
    @FocusState private var isGapFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Play")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                Text("Auto Switch to Next Search Result or Shiori Cues")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $settingsStore.autoPlayCueSequenceEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            HStack(spacing: 16) {
                Text("Auto Switch Gap")
                    .font(.headline)

                Spacer()

                HStack(spacing: 6) {
                    TextField(
                        "\(SettingsStore.autoPlayCueSequenceGapDefaultMilliseconds)",
                        text: $gapDraft
                    )
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 86)
                    .focused($isGapFieldFocused)

                    Text("ms")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Text("Show Speaker in Subtitles")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $settingsStore.playbackSpeakerDisplayEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .onAppear {
            syncGapDraftFromStore()
        }
        .onChange(of: gapDraft) { draft in
            applyGapDraftChange(draft)
        }
        .onChange(of: isGapFieldFocused) { isFocused in
            if !isFocused {
                commitGapDraft()
            }
        }
        .onChange(of: settingsStore.autoPlayCueSequenceGapMilliseconds) { _ in
            if !isGapFieldFocused {
                syncGapDraftFromStore()
            }
        }
    }

    private func applyGapDraftChange(_ draft: String) {
        let numericDraft = draft.filter(\.isNumber)
        guard numericDraft == draft else {
            gapDraft = numericDraft
            return
        }

        guard let milliseconds = Int(numericDraft) else {
            return
        }

        let clampedMilliseconds = SettingsStore.clampedAutoPlayCueSequenceGapMilliseconds(milliseconds)
        settingsStore.setAutoPlayCueSequenceGapMilliseconds(clampedMilliseconds)
        if milliseconds != clampedMilliseconds {
            gapDraft = String(clampedMilliseconds)
        }
    }

    private func commitGapDraft() {
        guard let milliseconds = Int(gapDraft) else {
            syncGapDraftFromStore()
            return
        }

        let clampedMilliseconds = SettingsStore.clampedAutoPlayCueSequenceGapMilliseconds(milliseconds)
        settingsStore.setAutoPlayCueSequenceGapMilliseconds(clampedMilliseconds)
        gapDraft = String(clampedMilliseconds)
    }

    private func syncGapDraftFromStore() {
        gapDraft = String(settingsStore.autoPlayCueSequenceGapMilliseconds)
    }
}
