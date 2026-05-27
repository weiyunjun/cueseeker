import SwiftUI

struct SettingsExperimentalCategory: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var deepSeekAPIKeyInput = ""
    @State private var deepSeekAPIKeyMessage: String?
    @State private var deepSeekAPIKeyMessageIsError = false
    @State private var aiChunkingPromptDraft = AIChunkingPromptConfiguration.defaultTemplate
    @State private var aiChunkingPromptMessage: String?
    @State private var aiChunkingPromptMessageIsError = false
    @State private var isEditingAIChunkingPrompt = false
    @FocusState private var aiChunkingPromptFocused: Bool

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
                aiChunkingSettingsPanel
                deepSeekAPIKeyPanel
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .onAppear {
            settingsStore.refreshDeepSeekAPIKeyStatus()
            aiChunkingPromptDraft = settingsStore.aiChunkingPromptTemplate
        }
        .onChange(of: settingsStore.aiChunkingEnabled) { isEnabled in
            if !isEnabled {
                cancelAIChunkingPromptEditing()
            }
        }
        .onChange(of: settingsStore.aiChunkingPromptTemplate) { promptTemplate in
            if !isEditingAIChunkingPrompt {
                aiChunkingPromptDraft = promptTemplate
            }
        }
        .onChange(of: aiChunkingPromptFocused) { isFocused in
            if isFocused {
                beginAIChunkingPromptEditing()
            }
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

    private var aiChunkingSettingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            aiChunkingTranslationLanguageRow

            Divider()

            aiChunkingPromptEditor
        }
        .padding(12)
        .background(Color.black.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(!settingsStore.aiChunkingEnabled)
        .opacity(settingsStore.aiChunkingEnabled ? 1 : 0.45)
    }

    private var aiChunkingTranslationLanguageRow: some View {
        HStack(spacing: 16) {
            Text("Translation Language")
                .font(.headline)

            Spacer()

            Picker("Translation Language", selection: $settingsStore.aiChunkingTranslationLanguage) {
                ForEach(AIChunkingTranslationLanguage.allCases) { language in
                    Text(language.rawValue)
                        .tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 180)
        }
    }

    private var aiChunkingPromptEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prompt")
                .font(.headline)

            TextEditor(text: $aiChunkingPromptDraft)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 240)
                .focused($aiChunkingPromptFocused)
                .onTapGesture {
                    beginAIChunkingPromptEditing()
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.black.opacity(0.16), lineWidth: 1)
                )

            if isEditingAIChunkingPrompt {
                HStack(spacing: 10) {
                    Button {
                        restoreDefaultAIChunkingPromptDraft()
                    } label: {
                        Label("Default", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        cancelAIChunkingPromptEditing()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }

                    Button {
                        saveAIChunkingPrompt()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }

                    Spacer()
                }
            }

            if let aiChunkingPromptMessage {
                Text(aiChunkingPromptMessage)
                    .font(.caption)
                    .foregroundStyle(aiChunkingPromptMessageIsError ? .red : .secondary)
            }
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

    private func beginAIChunkingPromptEditing() {
        guard settingsStore.aiChunkingEnabled else {
            return
        }

        if !isEditingAIChunkingPrompt {
            aiChunkingPromptDraft = settingsStore.aiChunkingPromptTemplate
            aiChunkingPromptMessage = nil
            aiChunkingPromptMessageIsError = false
        }
        isEditingAIChunkingPrompt = true
    }

    private func restoreDefaultAIChunkingPromptDraft() {
        aiChunkingPromptDraft = AIChunkingPromptConfiguration.defaultTemplate
        aiChunkingPromptMessage = nil
        aiChunkingPromptMessageIsError = false
    }

    private func cancelAIChunkingPromptEditing() {
        aiChunkingPromptDraft = settingsStore.aiChunkingPromptTemplate
        aiChunkingPromptMessage = nil
        aiChunkingPromptMessageIsError = false
        isEditingAIChunkingPrompt = false
        aiChunkingPromptFocused = false
    }

    private func saveAIChunkingPrompt() {
        do {
            try settingsStore.saveAIChunkingPromptTemplate(aiChunkingPromptDraft)
            aiChunkingPromptMessage = "AI chunking prompt saved."
            aiChunkingPromptMessageIsError = false
            isEditingAIChunkingPrompt = false
            aiChunkingPromptFocused = false
        } catch {
            aiChunkingPromptMessage = error.localizedDescription
            aiChunkingPromptMessageIsError = true
        }
    }
}
