import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ConfigStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NewFileTabView()
                .tabItem { Label("New File", systemImage: "doc.badge.plus") }
                .tag(SettingsTab.newFile)
            OpenAppsTabView()
                .tabItem { Label("Open Apps", systemImage: "app.badge") }
                .tag(SettingsTab.openApps)
            ActionsTabView()
                .tabItem { Label("Actions", systemImage: "bolt") }
                .tag(SettingsTab.actions)
            SetupTabView()
                .tabItem { Label("Setup", systemImage: "gear") }
                .tag(SettingsTab.setup)
        }
        .padding(.top, 8)
        .onOpenURL { url in
            ActionRunner.run(url)
        }
    }
}
