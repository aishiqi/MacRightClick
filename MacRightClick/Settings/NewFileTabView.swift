import SwiftUI

struct NewFileTabView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Table(store.config.fileTypes) {
                TableColumn("Enabled") { item in
                    EnabledCell(enabled: $store.config.fileTypes[item: item].enabled)
                }
                .width(ConfigTableWidth.enabled)
                TableColumn("Name") { item in
                    ConfigNameCell(
                        icon: IconProvider.fileIcon(fileName: item.fileName, size: IconProvider.rowSize),
                        title: item.name
                    )
                }
                TableColumn("File name") { item in
                    Text(item.fileName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TableColumn("Main Menu") { item in
                    MainMenuCell(placement: $store.config.fileTypes[item: item].placement)
                }
                .width(ConfigTableWidth.mainMenu)
                TableColumn("Delete") { item in
                    RemoveCell(isCustom: !item.isPreset) { store.removeFileType(id: item.id) }
                }
                .width(ConfigTableWidth.remove)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .padding(.horizontal, 16)

            HStack {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add file type", systemImage: "plus")
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showingAdd) {
            AddFileTypeSheet { name, fileName in
                store.addFileType(name: name, fileName: fileName)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("New File")
                .font(.title2.weight(.semibold))
            Text("Enabled types appear in Finder. Check Main Menu to pin an item to the top-level menu; otherwise it stays under New File.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct AddFileTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var extensionOrName = ""
    var onAdd: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add file type")
                .font(.headline)

            TextField("Display name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Extension or filename", text: $extensionOrName)
                .textFieldStyle(.roundedBorder)
            Text("Use an extension like swift, or an exact name like Dockerfile or .gitignore.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onAdd(name.trimmingCharacters(in: .whitespacesAndNewlines), resolvedFileName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !extensionOrName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedFileName: String {
        let raw = extensionOrName.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix(".") { return raw }
        if raw.contains(".") { return raw }
        if raw.first?.isUppercase == true { return raw }
        return "untitled.\(raw)"
    }
}
