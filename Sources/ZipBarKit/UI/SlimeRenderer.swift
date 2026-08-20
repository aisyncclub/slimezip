import AppKit

/// ZipBar's menu bar glyph: a row of slimes, one per hidden icon.
///
/// A count you can read at a glance was the goal, and the shape of the menu
/// bar decided how to get there. The bar constrains height — about 18pt of
/// usable glyph — but not width, so a square container filling with slimes
/// was measured and rejected: five slimes stacked inside 18pt leaves each one
/// about six pixels, at which point one slime and three are the same smudge
/// and the eyes are gone. Laid out in a row each slime keeps its full height,
/// so both the count and the faces survive.
///
/// Width is the price, and it is capped. Past `maxVisibleSlimes` the row
/// stops growing and the slimes fatten instead: an app whose purpose is to
/// reclaim menu bar space must not eat it a slime at a time.
public enum SlimeRenderer {

    /// Drawn fullness stages, thinnest through fattest.
    public static let stageCount = 5

    /// Most slimes ever drawn side by side.
    public static let maxVisibleSlimes = 4

    /// Hidden icons at which the row is considered completely stuffed.
    public static let fullAt = 8

    /// Gap between slimes, in points.
    static let spacing: CGFloat = 1.5

    /// How many slimes to draw for a given load.
    ///
    /// Zero hidden icons still draws one: an empty bar should show a slime
    /// waiting to be fed, not an empty space the user cannot click.
    public static func slimeCount(forHiddenCount count: Int) -> Int {
        max(1, min(count, maxVisibleSlimes))
    }

    /// Which fullness stage each slime is drawn at.
    ///
    /// Below the cap the slimes stay slim and the *number* carries the count.
    /// Above it the number is pinned, so fullness takes over as the signal.
    public static func stage(forHiddenCount count: Int) -> Int {
        guard count > 0 else { return 1 }
        guard count > maxVisibleSlimes else { return 2 }
        let overflow = Double(count - maxVisibleSlimes)
        let span = Double(max(1, fullAt - maxVisibleSlimes))
        let progress = min(1, overflow / span)
        return 2 + Int((progress * Double(stageCount - 2)).rounded())
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
        let count = slimeCount(forHiddenCount: hiddenCount)
        guard let base = stageImage(stage(forHiddenCount: hiddenCount), blinking: blinking)
        else { return nil }

        let body = row(of: base, count: count, squash: squash)
        return hasActivity ? badged(body) : body
    }

    /// Lays `count` copies out in a row inside one padded canvas.
    ///
    /// The canvas is padded whether or not anything is deforming, so the item
    /// never changes width mid-animation and shoves its neighbours sideways.
    static func row(of base: NSImage, count: Int, squash: CGFloat) -> NSImage {
        let normalised = max(-1, min(1, squash))
        let amount = normalised >= 0 ? normalised * maxSquash : normalised * maxStretch

        let cell = NSSize(
            width: base.size.width * (1 + maxSquash),
            height: base.size.height * (1 + maxSquash))
        let canvas = NSSize(
            width: cell.width * CGFloat(count) + spacing * CGFloat(count - 1),
            height: cell.height)

        let drawn = NSSize(
            width: base.size.width * (1 + amount),
            height: base.size.height * (1 - amount))
        // Sits just off the canvas floor: enough headroom that a full stretch
        // still fits, low enough that squashing reads as pressing down.
        let floor = base.size.height * maxStretch

        let result = NSImage(size: canvas)
        result.lockFocusFlipped(false)
        NSGraphicsContext.current?.imageInterpolation = .high
        for index in 0..<count {
            let originX = CGFloat(index) * (cell.width + spacing)
            base.draw(in: NSRect(
                x: originX + (cell.width - drawn.width) / 2,
                y: floor,
                width: drawn.width,
                height: drawn.height))
        }
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
