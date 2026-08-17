import AppKit

/// Entry point.
///
/// Declared as `@main` rather than as top-level code in `main.swift` because
/// the delegate is main-actor isolated and top-level statements are not.
///
/// ZipBar lives in the menu bar only — no Dock icon, no window on launch.
/// `.accessory` mirrors the bundle's `LSUIElement` so behaviour matches when
/// the binary is run directly during development (`swift run ZipBar`).
@main
enum ZipBarMain {
    /// Held statically because `NSApplication.delegate` does not retain.
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
