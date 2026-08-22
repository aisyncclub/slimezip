import AppKit

/// Moves ZipBar's own items along the menu bar.
///
/// Other apps' icons can only be repositioned for their next launch —
/// macOS reads a stored position when a status item is created, and we
/// cannot make somebody else's app re-create theirs. Ours we can: shifting
/// the stored positions and rebuilding our own items applies immediately,
/// with no restart of anything.
///
/// Positions are distances from the right edge of the screen, so a larger
/// number is further left. `steps` are in the same units.
public struct SelfPlacement {

    /// How far one nudge travels.
    ///
    /// About one status item's width: small enough to land between two
    /// neighbours on purpose, large enough that a click visibly moves
    /// something. Smaller steps read as a broken button.
    public static let step: Double = 34

    /// The furthest left a nudge will go, as a distance from the right edge.
    ///
    /// Past the widest display the item is off-screen and unreachable —
    /// exactly the state `StatusItemPlacement.sanitize` exists to repair,
    /// so the mover must not create it.
    public static func maximum(widestScreenWidth: Double) -> Double {
        max(0, widestScreenWidth - 40)
    }

    /// Where a set of our items should sit after nudging.
    ///
    /// Every item moves by the same amount, so their spacing — and with it
    /// the rule that the slime stays right of the boundary it inflates — is
    /// preserved. Clamping is applied to the group rather than per item for
    /// the same reason: clamping individually would squash the gaps.
    public static func shifted(
        positions: [Double], by delta: Double, widestScreenWidth: Double
    ) -> [Double] {
        guard !positions.isEmpty else { return positions }
        let limit = maximum(widestScreenWidth: widestScreenWidth)
        let proposed = positions.map { $0 + delta }

        var correction: Double = 0
        if let over = proposed.max(), over > limit { correction = limit - over }
        if let under = proposed.min(), under + correction < 0 { correction = -under }

        return proposed.map { $0 + correction }
    }

    /// Whether a nudge in this direction would change anything.
    ///
    /// Drives the disabled state of the buttons: a control that looks
    /// available and does nothing is worse than one that is plainly off.
    public static func canShift(
        positions: [Double], by delta: Double, widestScreenWidth: Double
    ) -> Bool {
        let after = shifted(positions: positions, by: delta,
                            widestScreenWidth: widestScreenWidth)
        return zip(positions, after).contains { abs($0 - $1) > 0.5 }
    }
}
