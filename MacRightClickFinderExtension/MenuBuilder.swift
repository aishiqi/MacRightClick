import AppKit

enum MenuBuilder {
    static func makeMenu() -> NSMenu {
        MenuCache.shared.menu()
    }
}
