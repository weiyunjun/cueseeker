import SwiftUI

struct SettingsExperimentalCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var deepSeekAPIKeyInput = ""
    @State private var deepSeekAPIKeyMessage: String?
    @State private var deepSeekAPIKeyMessageIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Experimental Features")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Try unstable features that may change or be removed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                aiChunkingToggleRow
                deepSeekAPIKeyPanel
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .onAppear {
            settingsStore.refreshDeepSeekAPIKeyStatus()
        }
    }

    private var aiChunkingToggleRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Chunking")
                    .font(.headline)
                Text("Show an AI chunking option in Playback Quick Search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $settingsStore.aiChunkingEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var deepSeekAPIKeyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeepSeek API Key")
                        .font(.headline)
                    Text("Stored in macOS Keychain and hidden after saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(settingsStore.deepSeekAPIKeyConfigured ? "Configured" : "Not configured")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(settingsStore.deepSeekAPIKeyConfigured ? .green : .secondary)
                    .background(
                        Capsule()
                            .fill(
                                settingsStore.deepSeekAPIKeyConfigured
                                    ? Color.green.opacity(0.12)
                                    : Color.black.opacity(0.055)
                            )
                    )
            }

            SecureField("Paste DeepSeek API key", text: $deepSeekAPIKeyInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)

            HStack(spacing: 10) {
                Button {
                    saveDeepSeekAPIKey()
                } label: {
                    Label("Save Key", systemImage: "key.fill")
                }
                .disabled(deepSeekAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    clearDeepSeekAPIKey()
                } label: {
                    Label("Clear Key", systemImage: "trash")
                }
                .disabled(!settingsStore.deepSeekAPIKeyConfigured)

                Spacer()
            }

            if let deepSeekAPIKeyMessage {
                Text(deepSeekAPIKeyMessage)
                    .font(.caption)
                    .foregroundStyle(deepSeekAPIKeyMessageIsError ? .red : .secondary)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func saveDeepSeekAPIKey() {
        do {
            try settingsStore.saveDeepSeekAPIKey(deepSeekAPIKeyInput)
            deepSeekAPIKeyInput = ""
            deepSeekAPIKeyMessage = "DeepSeek API key saved."
            deepSeekAPIKeyMessageIsError = false
        } catch {
            deepSeekAPIKeyMessage = error.localizedDescription
            deepSeekAPIKeyMessageIsError = true
        }
    }

    private func clearDeepSeekAPIKey() {
        do {
            try settingsStore.clearDeepSeekAPIKey()
            deepSeekAPIKeyInput = ""
            deepSeekAPIKeyMessage = "DeepSeek API key cleared."
            deepSeekAPIKeyMessageIsError = false
        } catch {
            deepSeekAPIKeyMessage = error.localizedDescription
            deepSeekAPIKeyMessageIsError = true
        }
    }
}
