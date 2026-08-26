import SwiftUI
import AppKit

extension Binding {
    /// Looks the element up by id on every access so a cell keeps working when rows
    /// are added or removed while the table is on screen.
    subscript<Item: Identifiable>(item item: Item) -> Binding<Item> where Value == [Item] {
        Binding<Item>(
            get: { wrappedValue.first { $0.id == item.id } ?? item },
            set: { newValue in
                guard let index = wrappedValue.firstIndex(where: { $0.id == item.id }) else { return }
                wrappedValue[index] = newValue
            }
        )
    }
}

enum ConfigTableWidth {
    static let enabled: CGFloat = 62
    static let mainMenu: CGFloat = 80
    static let remove: CGFloat = 28
}

struct ConfigNameCell: View {
    var icon: NSImage? = nil
    var systemImage: String? = nil
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            iconView
                .frame(width: 20, height: 20)
            Text(title)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        } else if let icon {
            Image(nsImage: icon)
                .renderingMode(icon.isTemplate ? .template : .original)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        }
    }
}

struct EnabledCell: View {
    @Binding var enabled: Bool

    var body: some View {
        Toggle("Enabled", isOn: $enabled)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .help("Show this item in the Finder menu")
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct MainMenuCell: View {
    @Binding var placement: Placement

    var body: some View {
        Toggle("Main menu", isOn: mainMenuBinding)
            .toggleStyle(.checkbox)
            .labelsHidden()
            .controlSize(.small)
            .help("Show as a top-level Finder item instead of in a submenu")
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var mainMenuBinding: Binding<Bool> {
        Binding(
            get: { placement == .mainMenu },
            set: { placement = $0 ? .mainMenu : .submenu }
        )
    }
}

struct RemoveCell: View {
    let isCustom: Bool
    let onDelete: () -> Void

    var body: some View {
        if isCustom {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove custom item")
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
