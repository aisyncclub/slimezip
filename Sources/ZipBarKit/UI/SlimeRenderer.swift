import AppKit

/// ZipBar's menu bar glyph: slimes squeezed into one fixed slot.
///
/// The count is carried by how *crushed* the slimes look, not by how much
/// room they take. One slime sits round and relaxed; five are wedged flat
/// against each other in exactly the same footprint. An app whose whole
/// purpose is reclaiming menu bar space cannot spend that space one slime at
/// a time, so the glyph never grows — an earlier version laid the slimes out
/// in a row and reached 80pt at eight hidden icons, which is wider than most
/// of the icons it was hiding.
///
/// Each count is its own drawing rather than copies of one slime tiled
/// together: jelly under pressure deforms where it touches its neighbours,
/// and that contact is the whole reason the picture reads as "packed".
public enum SlimeRenderer {

    /// Drawn stages: one relaxed slime through five crushed together.
    public static let stageCount = 5

    /// Hidden icons at which the slot is considered completely packed.
    ///
    /// Past this the picture cannot say any more — the slimes are already
    /// flat against every wall — so the glyph stops changing rather than
    /// pretending to distinguish nine from ninety.
    public static let fullAt = 6

    /// Which drawing represents this load.
    ///
    /// Zero hidden icons still draws the single slime: an empty bar should
    /// show one waiting to be fed, not a blank the user cannot find or click.
    public static func stage(forHiddenCount count: Int) -> Int {
        guard count > 0 else { return 1 }
        return min(count, stageCount)
    }

    /// Limits on the deformation, as fractions of the resting size.
    ///
    /// Asymmetric on purpose: jelly flattens further than it draws itself out,
    /// and the canvas has to contain both — a drawing taller than its canvas
    /// gets its dome clipped flat, which is the opposite of stretching.
    public static let maxSquash: CGFloat = 0.12
    public static let maxStretch: CGFloat = 0.06

    /// The glyph for a state, or nil when the artwork is missing — callers
    /// fall back to a symbol rather than showing an empty status item.
    ///
    /// - Parameters:
    ///   - squash: normalised −1…1. Positive squashes wide and flat.
    ///   - blinking: draws the closed-eye artwork.
    public static func image(
        hiddenCount: Int,
        hasActivity: Bool,
        squash: CGFloat = 0,
        blinking: Bool = false
    ) -> NSImage? {
        let index = stage(forHiddenCount: hiddenCount)
        // Fall back to open eyes rather than to nothing. Returning nil here
        // would drop the caller onto its symbol fallback for the length of a
        // blink, so a missing closed-eye file would make the whole character
        // flicker out several times a minute.
        guard let base = stageImage(index, blinking: blinking)
            ?? stageImage(index, blinking: false)
        else { return nil }

        let body = deformed(base, squash: squash)
        return hasActivity ? badged(body) : body
    }

    /// Applies squash and stretch inside a fixed canvas.
    ///
    /// The canvas is padded whether or not anything is deforming, so the item
    /// never changes width mid-animation and shoves its neighbours sideways.
    static func deformed(_ base: NSImage, squash: CGFloat) -> NSImage {
        let normalised = max(-1, min(1, squash))
        let amount = normalised >= 0 ? normalised * maxSquash : normalised * maxStretch

        let canvas = NSSize(
            width: base.size.width * (1 + maxSquash),
            height: base.size.height * (1 + maxSquash))
        let drawn = NSSize(
            width: base.size.width * (1 + amount),
            height: base.size.height * (1 - amount))
        // Sits just off the canvas floor: enough headroom that a full stretch
        // still fits, low enough that squashing reads as pressing down.
        let floor = base.size.height * maxStretch

        let result = NSImage(size: canvas)
        result.lockFocusFlipped(false)
        NSGraphicsContext.current?.imageInterpolation = .high
        base.draw(in: NSRect(
            x: (canvas.width - drawn.width) / 2,
            y: floor,
            width: drawn.width,
            height: drawn.height))
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    /// How many stages have artwork on disk, for diagnostics: the slimes are
    /// the app's only icon, so missing artwork means the user sees nothing.
    public static var availableStageCount: Int {
        (1...stageCount).filter { stageImage($0, blinking: false) != nil }.count
    }

    /// Whether the closed-eye artwork is present. Without it the app simply
    /// never blinks rather than falling back to something wrong.
    public static var hasBlinkArtwork: Bool {
        stageImage(2, blinking: true) != nil
    }

    private static var cache: [String: NSImage] = [:]

    /// One drawn slime. Public so the settings window can show the same
    /// character at a size where its face reads.
    public static func stageImage(_ stage: Int, blinking: Bool) -> NSImage? {
        let name = "slime-\(blinking ? "blink-" : "")\(stage)@2x"
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(
            forResource: name, withExtension: "png", subdirectory: "Slime")
            ?? Bundle.main.url(forResource: name, withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else { return nil }

        // The file is 2×; declare the logical size so AppKit downsamples from
        // the full-resolution pixels instead of drawing it double-height.
        let pixels = image.representations.first.map {
            NSSize(width: $0.pixelsWide, height: $0.pixelsHigh)
        } ?? image.size
        image.size = NSSize(width: pixels.width / 2, height: pixels.height / 2)
        image.isTemplate = false
        cache[name] = image
        return image
    }

    /// Adds the activity dot.
    ///
    /// macOS publishes no badge or unread state for other apps' status items,
    /// so this marks "something about a hidden icon changed" — the strongest
    /// claim the data supports.
    private static func badged(_ base: NSImage) -> NSImage {
        let size = base.size
        let result = NSImage(size: size)
        result.lockFocusFlipped(false)
        base.draw(in: NSRect(origin: .zero, size: size))

        let radius: CGFloat = 2.6
        let center = NSPoint(x: size.width - radius - 0.4, y: size.height - radius - 0.4)
        let dot = NSRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.1, dy: -1.1)).fill()
        NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(ovalIn: dot).fill()

        result.unlockFocus()
        result.isTemplate = false
        return result
    }
}
