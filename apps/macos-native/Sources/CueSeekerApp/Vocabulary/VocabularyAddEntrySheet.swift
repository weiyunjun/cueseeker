import SwiftUI

struct VocabularyAddEntrySheet: View {
    let onCancel: () -> Void
    let onSave: (String, String) throws -> Void

    @State private var term = ""
    @State private var explanation = ""
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case term
        case explanation
    }

    private var trimmedTerm: String {
        term.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedExplanation: String {
        explanation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTerm.isEmpty && !trimmedExplanation.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Add Vocabulary", systemImage: "character.book.closed")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text("Word")
                    .font(.system(size: 13, weight: .semibold))

                TextField("Word", text: $term)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .term)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Explanation")
                    .font(.system(size: 13, weight: .semibold))

                TextEditor(text: $explanation)
                    .font(.system(size: 14))
                    .frame(minHeight: 150)
                    .focused($focusedField, equals: .explanation)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.black.opacity(0.16), lineWidth: 1)
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.red)
            }

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    save()
                } label: {
                    Label("Add", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            focusedField = .term
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        do {
            try onSave(trimmedTerm, trimmedExplanation)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
