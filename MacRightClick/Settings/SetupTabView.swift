import SwiftUI

struct SetupTabView: View {
    @State private var state: ExtensionStatus.RegistrationState = .notRegistered
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
                                Button(state == .enabled ? "Deactivate" : "Activate") {
                                    if state == .enabled {
                                        deactivate()
                                    } else {
                                        activate()
                                    }
                                }
                                Button("Open Extension Settings") {
                                    ExtensionStatus.showSystemManagementInterface()
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
            return "The extension is installed but turned off. Click Activate to turn it back on."
        case .notRegistered:
            return "Click Activate to install the app and register the Finder extension."
        }
    }

    private func refreshStatus() {
        state = ExtensionStatus.state()
    }

    private func activate() {
        do {
            try ExtensionStatus.installRegisterAndEnable()
            statusMessage = ""
        } catch {
            _ = ExtensionStatus.registerExtension()
            statusMessage = "Could not copy to /Applications (\(error.localizedDescription)). Registered the running copy instead."
        }
        refreshStatus()
    }

    private func deactivate() {
        _ = ExtensionStatus.disableExtension()
        statusMessage = ""
        refreshStatus()
    }
}
