import SwiftUI

struct SetupTabView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var state: ExtensionStatus.RegistrationState = .notRegistered
    @State private var lastChecked = Date()
    @State private var statusMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Setup")
                        .font(.title2.weight(.semibold))
                    Text("macOS only lists a Finder extension after the app is installed in /Applications and PluginKit has registered it.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: statusSymbol)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(statusTitle)
                                .font(.headline)
                            Text(statusDetail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            HStack {
                                Button("Install to /Applications and Register") {
                                    installAndRegister()
                                }
                                Button("Open Extension Settings") {
                                    ExtensionStatus.showSystemManagementInterface()
                                }
                                Button("Login Items & Extensions") {
                                    ExtensionStatus.openLoginItemsSettings()
                                }
                                Button("Refresh") {
                                    refreshStatus()
                                }
                            }
                            .padding(.top, 4)
                        }
                        Spacer()
                    }
                    .padding(8)
                }

                GroupBox("How to use") {
                    VStack(alignment: .leading, spacing: 8) {
                        labeledStep(1, "Click Install to /Applications and Register. PluginKit ignores apps that only live in Xcode’s build folder.")
                        labeledStep(2, "In the Extensions sheet, turn on MacRightClick Finder Extension. On macOS 15+: System Settings → General → Login Items & Extensions.")
                        labeledStep(3, "Right-click a file, folder, or empty space in Finder. If the folder is iCloud Drive, use View → Customize Toolbar… and add the MacRightClick button.")
                    }
                    .padding(8)
                }

                GroupBox("Notes") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A Development Team must sign the app. Ad-hoc builds from DerivedData will not appear in System Settings.")
                        Text("Open Terminal uses macOS Launch Services, so it does not ask to control Terminal.")
                        Text("Missing apps stay in the Open Apps tab and are hidden from Finder until they are installed.")
                        Text("Scripts run in the MacRightClick app so they have a normal user environment. Selected paths are arguments; the Finder folder is the working directory.")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                }

                HStack {
                    Button("Reset menus to defaults") {
                        store.resetToDefaults()
                    }
                    Spacer()
                    Text("Last checked \(lastChecked.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
        .onAppear(perform: refreshStatus)
    }

    private var statusSymbol: String {
        switch state {
        case .enabled: return "checkmark.circle.fill"
        case .registeredDisabled: return "pause.circle.fill"
        case .notRegistered: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch state {
        case .enabled: return .green
        case .registeredDisabled: return .orange
        case .notRegistered: return .orange
        }
    }

    private var statusTitle: String {
        switch state {
        case .enabled: return "Finder extension is enabled"
        case .registeredDisabled: return "Extension is registered but turned off"
        case .notRegistered: return "Extension is not registered"
        }
    }

    private var statusDetail: String {
        switch state {
        case .enabled:
            return "Right-click in Finder to use MacRightClick."
        case .registeredDisabled:
            return "Open Extension Settings and enable MacRightClick Finder Extension."
        case .notRegistered:
            return "Install the app to /Applications, then register it. It will not show in System Settings until PluginKit sees the .appex."
        }
    }

    private func labeledStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
                .frame(width: 20, alignment: .leading)
            Text(text)
        }
        .font(.callout)
    }

    private func refreshStatus() {
        state = ExtensionStatus.state()
        lastChecked = Date()
    }

    private func installAndRegister() {
        do {
            try ExtensionStatus.installRegisterAndEnable()
            statusMessage = "Installed to /Applications and asked PluginKit to register the extension."
        } catch {
            _ = ExtensionStatus.registerExtension()
            statusMessage = "Could not copy to /Applications (\(error.localizedDescription)). Registered the running copy instead."
        }
        refreshStatus()
    }
}
