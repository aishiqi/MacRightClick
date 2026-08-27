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
    static let remove: CGFloat = 56
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

/// Installs a window-local double-click monitor that maps onto the nearest
/// `NSTableView`, so a SwiftUI `Table` row can open an editor.
struct TableRowDoubleClick: NSViewRepresentable {
    let onDoubleClick: (Int) -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onDoubleClick = onDoubleClick
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDoubleClick: onDoubleClick)
    }

    final class Coordinator {
        var onDoubleClick: (Int) -> Void
        let view = NSView()
        private var monitor: Any?

        init(onDoubleClick: @escaping (Int) -> Void) {
            self.onDoubleClick = onDoubleClick
            view.setAccessibilityHidden(true)
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        private func handle(_ event: NSEvent) {
            guard event.clickCount == 2, event.window === view.window else { return }
            guard let tableView = nearestTableView() else { return }
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            guard row >= 0 else { return }
            if let hit = tableView.hitTest(point), hit is NSControl { return }
            onDoubleClick(row)
        }

        private func nearestTableView() -> NSTableView? {
            var current: NSView? = view.superview
            while let node = current {
                if let table = findTableView(in: node) { return table }
                current = node.superview
            }
            return nil
        }

        private func findTableView(in view: NSView) -> NSTableView? {
            if let table = view as? NSTableView { return table }
            for child in view.subviews {
                if let table = findTableView(in: child) { return table }
            }
            return nil
        }
    }
}
