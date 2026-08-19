import AppKit

/// Draws a glyph into a status item button, guaranteeing something visible.
///
/// `NSImage(systemSymbolName:)` returns nil for a name that does not exist on
/// the running OS, and a status item with a nil image and no title renders as
/// nothing at all. That is indistinguishable from the app failing to launch —
/// which is exactly how a typo'd symbol name (`line.3.vertical`, which is not
/// a real symbol) made ZipBar's separator invisible.
///
/// Symbol availability also shifts between macOS releases, so this is not a
/// one-off guard: it is the only safe way to set a status item glyph.
public enum StatusItemGlyph {
    @MainActor
    public static func apply(
        to button: NSStatusBarButton?,
        symbolName: String,
        fallbackText: String,
        accessibilityDescription: String
    ) {
        guard let button else { return }
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = fallbackText
        }
    }

    /// Whether a symbol resolves on this OS. Used by the diagnostics report so
    /// a missing glyph shows up as a finding rather than as a blank menu bar.
    public static func resolves(_ symbolName: String) -> Bool {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
    }
}
