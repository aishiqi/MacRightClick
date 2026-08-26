import SwiftUI

struct ActionsTabView: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Actions")
                    .font(.title2.weight(.semibold))
                Text("Built-in Finder actions. Uncheck Main Menu to keep an item in the Actions submenu.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Table(store.config.actions) {
                TableColumn("Enabled") { item in
                    EnabledCell(enabled: $store.config.actions[item: item].enabled)
                }
                .width(ConfigTableWidth.enabled)
                TableColumn("Name") { item in
                    ConfigNameCell(systemImage: item.kind.symbolName, title: item.kind.title)
                }
                TableColumn("Main Menu") { item in
                    MainMenuCell(placement: $store.config.actions[item: item].placement)
                }
                .width(ConfigTableWidth.mainMenu)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}
