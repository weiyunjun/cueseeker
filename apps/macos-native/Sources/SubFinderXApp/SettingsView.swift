import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Subtitle Folders")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    chooseFolder()
                } label: {
                    Label("Add Folder", systemImage: "folder.badge.plus")
                }
            }

            if appState.selectedFolders.isEmpty {
                EmptyStateView(
                    title: "No Subtitle Folders",
                    systemImage: "folder",
                    message: "Choose a local folder containing .srt files."
                )
            } else {
                List {
                    ForEach(appState.selectedFolders, id: \.self) { folder in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(folder.lastPathComponent)
                                .font(.headline)
                            Text(folder.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: appState.removeFolders)
                }
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Settings")
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Subtitle Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let folder = panel.url else {
            return
        }

        appState.addFolder(folder)
    }
}
