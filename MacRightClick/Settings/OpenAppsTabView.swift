import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct OpenAppsTabView: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Table(store.config.apps) {
                TableColumn("Enabled") { item in
                    EnabledCell(enabled: $store.config.apps[item: item].enabled)
                }
                .width(ConfigTableWidth.enabled)
                TableColumn("Name") { item in
                    ConfigNameCell(
                        icon: IconProvider.appIcon(for: item, size: IconProvider.rowSize),
                        title: item.name
                    )
                    .opacity(AppLocator.isInstalled(item) ? 1 : 0.7)
                }
                TableColumn("Identifier") { item in
                    Text(item.bundleIdentifiers.first ?? item.customPath ?? "")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TableColumn("Status") { item in
                    if AppLocator.isInstalled(item) {
                        Text("Installed")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not installed")
                            .foregroundStyle(.orange)
                    }
                }
                .width(min: 80, ideal: 90, max: 120)
                TableColumn("Main Menu") { item in
                    MainMenuCell(placement: $store.config.apps[item: item].placement)
                }
                .width(ConfigTableWidth.mainMenu)
                TableColumn("Delete") { item in
                    RemoveCell(isCustom: !item.isPreset) { store.removeApp(id: item.id) }
                }
                .width(ConfigTableWidth.remove)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .padding(.horizontal, 16)

            HStack {
                Button(action: addAppFromPanel) {
                    Label("Add app", systemImage: "plus")
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Open Apps")
                .font(.title2.weight(.semibold))
            Text("Apps that are not installed stay listed here but stay hidden in Finder. Add any .app to the list.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func addAppFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Do not open the chosen .app with Bundle() — that reads Info.plist and
        // triggers “想访问其他App的数据”.
        let name = url.deletingPathExtension().lastPathComponent
        store.addApp(name: name, bundleIdentifier: nil, path: url.path)
    }
}
