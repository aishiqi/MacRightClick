import SwiftUI

struct ScriptsTabView: View {
    @EnvironmentObject private var store: ConfigStore
    @State private var selection: ScriptItem.ID?
    @State private var editor: ScriptEditorSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Table(store.config.scripts, selection: $selection) {
                TableColumn("Enabled") { item in
                    EnabledCell(enabled: $store.config.scripts[item: item].enabled)
                }
                .width(ConfigTableWidth.enabled)
                TableColumn("Name") { item in
                    ConfigNameCell(systemImage: "terminal", title: item.name)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { editor = .edit(item) }
                }
                TableColumn("Main Menu") { item in
                    MainMenuCell(placement: $store.config.scripts[item: item].placement)
                }
                .width(ConfigTableWidth.mainMenu)
                TableColumn("Delete") { item in
                    RemoveCell(isCustom: true) { store.removeScript(id: item.id) }
                }
                .width(ConfigTableWidth.remove)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .padding(.horizontal, 16)
            .background(TableRowDoubleClick { row in
                guard store.config.scripts.indices.contains(row) else { return }
                editor = .edit(store.config.scripts[row])
            })

            HStack {
                Button {
                    editor = .add
                } label: {
                    Label("Add script", systemImage: "plus")
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .sheet(item: $editor) { session in
            ScriptEditorSheet(session: session) { name, source in
                switch session {
                case .add:
                    store.addScript(name: name, source: source)
                case .edit(let item):
                    store.updateScript(id: item.id, name: name, source: source)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scripts")
                .font(.title2.weight(.semibold))
            Text("Bash scripts that run from Finder. Double-click a row to edit. Use macros such as $FOLDER for the containing folder. Check Main Menu to pin an item to the top-level menu; otherwise it stays under Scripts.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

enum ScriptEditorSession: Identifiable {
    case add
    case edit(ScriptItem)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let item): return item.id
        }
    }
}

struct ScriptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: ScriptEditorSession
    var onSave: (String, String) -> Void

    @State private var name: String
    @State private var source: String
    @StateObject private var sourceEditor = ScriptSourceController()

    init(session: ScriptEditorSession, onSave: @escaping (String, String) -> Void) {
        self.session = session
        self.onSave = onSave
        switch session {
        case .add:
            _name = State(initialValue: "")
            _source = State(initialValue: ScriptItem.defaultSource)
        case .edit(let item):
            _name = State(initialValue: item.name)
            _source = State(initialValue: item.source)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sessionTitle)
                .font(.headline)

            TextField("Display name", text: $name)
                .textFieldStyle(.roundedBorder)

            ScriptSourceEditor(text: $source, controller: sourceEditor)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )
                .frame(minHeight: 240)

            Text("The Finder folder is the working directory. Selected paths are arguments. Homebrew’s bin is on PATH. Click a macro to insert it at the cursor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(ScriptMacros.catalog) { token in
                    Button {
                        sourceEditor.insert(token.name)
                    } label: {
                        Text(token.name)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(token.summary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), source)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 620, height: 520)
    }

    private var sessionTitle: String {
        switch session {
        case .add: return "Add script"
        case .edit: return "Edit script"
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class ScriptSourceController: ObservableObject {
    fileprivate var performInsert: ((String) -> Void)?

    func insert(_ token: String) {
        performInsert?(token)
    }
}

/// `TextEditor` does not expose the caret, so this AppKit view keeps the last
/// selection when a macro button steals focus and inserts there.
struct ScriptSourceEditor: NSViewRepresentable {
    @Binding var text: String
    var controller: ScriptSourceController

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = CursorPreservingTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 4)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.insertionRange = NSRange(location: (text as NSString).length, length: 0)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.bind(controller)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.bind(controller)
        guard let textView = context.coordinator.textView, textView.string != text else { return }
        textView.string = text
        let max = (text as NSString).length
        let location = min(textView.insertionRange.location, max)
        textView.insertionRange = NSRange(location: location, length: 0)
        textView.setSelectedRange(textView.insertionRange)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        weak var textView: CursorPreservingTextView?

        init(text: Binding<String>) {
            self.text = text
        }

        func bind(_ controller: ScriptSourceController) {
            controller.performInsert = { [weak self] token in
                self?.textView?.insertToken(token)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text.wrappedValue = textView.string
        }
    }
}

final class CursorPreservingTextView: NSTextView {
    var insertionRange = NSRange(location: 0, length: 0)
    private var ignoreSelectionChanges = false

    override func resignFirstResponder() -> Bool {
        insertionRange = selectedRange()
        ignoreSelectionChanges = true
        return super.resignFirstResponder()
    }

    override func becomeFirstResponder() -> Bool {
        ignoreSelectionChanges = false
        return super.becomeFirstResponder()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting flag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
        if !ignoreSelectionChanges, !flag, let range = ranges.first?.rangeValue {
            insertionRange = range
        }
    }

    func insertToken(_ token: String) {
        let ns = string as NSString
        let location = min(max(insertionRange.location, 0), ns.length)
        let length = min(max(insertionRange.length, 0), ns.length - location)
        let range = NSRange(location: location, length: length)
        if shouldChangeText(in: range, replacementString: token) {
            replaceCharacters(in: range, with: token)
            didChangeText()
        }
        let next = NSRange(location: range.location + (token as NSString).length, length: 0)
        insertionRange = next
        setSelectedRange(next)
        window?.makeFirstResponder(self)
        scrollRangeToVisible(next)
    }
}
