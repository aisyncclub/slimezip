import AppKit

/// ZipBar's menu bar character: a slime that fattens as it swallows icons and
/// slims down when it lets them go.
///
/// The five stages are drawn artwork rather than generated shapes, so the
/// creature keeps a hand-made look that a path would flatten. They share a
/// baseline and a scale, which is what makes the sequence read as one slime
/// changing size rather than five separate drawings.
///
/// Images ship at 2× and are stamped with their logical size, so AppKit picks
/// up the high-resolution data and the glyph stays crisp on a Retina bar.
public enum SlimeRenderer {

    /// Number of drawn stages, thinnest through fattest.
    public static let stageCount = 5

    /// Hidden icons at which the slime is completely stuffed. Past this the
    /// shape would stop reading as a creature.
    public static let fullAt = 8

    /// Which stage represents this load.
    ///
    /// Zero hidden icons must map to the thinnest stage: an empty slime that
    /// already looked plump would have nothing left to say when it filled up.
    public static func stage(forHiddenCount count: Int) -> Int {
        guard count > 0 else { return 1 }
        let clamped = min(count, fullAt)
        // Spread 1...fullAt across stages 2...stageCount.
        let span = Double(stageCount - 1)
        let position = Double(clamped) / Double(fullAt)
        return 1 + max(1, Int((position * span).rounded()))
    }

    /// Limits on the deformation, as fractions of the resting size.
    ///
    /// Asymmetric on purpose. Jelly flattens further than it draws itself
    /// out, and the canvas has to contain both: a drawing taller than its
    /// canvas gets its dome clipped flat, which is the opposite of stretching.
    /// The canvas is padded by `maxSquash` in both directions so the status
    /// item never resizes mid-motion and shoves its neighbours sideways.
    public static let maxSquash: CGFloat = 0.12
    public static let maxStretch: CGFloat = 0.06

    /// The glyph for a given state, or nil when the artwork is missing —
    /// callers fall back to a symbol rather than showing an empty item.
    ///
    /// - Parameter squash: normalised −1 through 1. Positive squashes the
    ///   slime wide and flat, negative draws it tall and thin; the two are
    ///   scaled by `maxSquash` and `maxStretch` respectively. Volume is held
    ///   roughly constant so it deforms like jelly rather than merely scaling.
    public static func image(
        hiddenCount: Int, hasActivity: Bool, squash: CGFloat = 0
    ) -> NSImage? {
        guard let base = stageImage(stage(forHiddenCount: hiddenCount)) else { return nil }
        // Always the padded canvas, including at rest. Returning the bare
        // artwork when still and a wider one while animating would make the
        // status item jump wider the instant a motion began, shoving its
        // neighbours sideways — the jitter the padding exists to prevent.
        let body = deformed(base, squash: squash)
        return hasActivity ? badged(body) : body
    }

    /// Applies squash and stretch inside a fixed canvas.
    static func deformed(_ base: NSImage, squash: CGFloat) -> NSImage {
        let normalised = max(-1, min(1, squash))
        let amount = normalised >= 0 ? normalised * maxSquash : normalised * maxStretch

        let canvas = NSSize(
            width: base.size.width * (1 + maxSquash),
            height: base.size.height * (1 + maxSquash)
        )
        let drawn = NSSize(
            width: base.size.width * (1 + amount),
            height: base.size.height * (1 - amount)
        )
        // Sits just off the canvas floor: enough headroom that a full stretch
        // still fits, low enough that squashing reads as pressing down on a
        // surface rather than shrinking in mid-air. With the padding above and
        // below matched, the resting slime lands centred in the bar.
        let floor = base.size.height * maxStretch

        let result = NSImage(size: canvas)
        result.lockFocusFlipped(false)
        NSGraphicsContext.current?.imageInterpolation = .high
        base.draw(in: NSRect(
            x: (canvas.width - drawn.width) / 2,
            y: floor,
            width: drawn.width,
            height: drawn.height
        ))
        result.unlockFocus()
        result.isTemplate = false
        return result
    }

    /// How many stages have artwork on disk.
    ///
    /// Surfaced for diagnostics: the slime is the app's only icon, so missing
    /// artwork means the user sees nothing and needs to be told why rather
    /// than left guessing whether the app launched.
    public static var availableStageCount: Int {
        (1...stageCount).filter { stageImage($0) != nil }.count
    }

    private static var cache: [Int: NSImage] = [:]

    static func stageImage(_ stage: Int) -> NSImage? {
        if let cached = cache[stage] { return cached }
        guard let url = Bundle.main.url(
            forResource: "slime-\(stage)@2x", withExtension: "png", subdirectory: "Slime")
            ?? Bundle.main.url(forResource: "slime-\(stage)@2x", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else { return nil }

        // The file is 2×; declare the logical size so AppKit downsamples from
        // the full-resolution pixels instead of drawing it double-height.
        let pixels = image.representations.first.map {
            NSSize(width: $0.pixelsWide, height: $0.pixelsHigh)
        } ?? image.size
        image.size = NSSize(width: pixels.width / 2, height: pixels.height / 2)
        image.isTemplate = false
        cache[stage] = image
        return image
    }

    /// Adds the activity dot.
    ///
    /// macOS publishes no badge or unread state for other apps' status items,
    /// so this marks "something about a hidden icon changed" — the strongest
    /// claim the data supports. It is drawn here rather than baked into the
    /// artwork so it can appear on any stage.
    private static func badged(_ base: NSImage) -> NSImage {
        let size = base.size
        let result = NSImage(size: size)
        result.lockFocusFlipped(false)
        base.draw(in: NSRect(origin: .zero, size: size))

        let radius: CGFloat = 2.6
        let center = NSPoint(x: size.width - radius - 0.4, y: size.height - radius - 0.4)
        let dot = NSRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        // Ringed so it stays legible over the body it overlaps.
        NSColor.white.setFill()
        NSBezierPath(ovalIn: dot.insetBy(dx: -1.1, dy: -1.1)).fill()
        NSColor(calibratedRed: 0.98, green: 0.42, blue: 0.18, alpha: 1).setFill()
        NSBezierPath(ovalIn: dot).fill()

        result.unlockFocus()
        result.isTemplate = false
        return result
    }
}
