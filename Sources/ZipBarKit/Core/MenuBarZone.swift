import Foundation

/// Which region of the menu bar an icon sits in.
///
/// Separators nest: each one hides everything to its left, so the bar reads as
/// a series of zones from left to right, ending in the part that is always on
/// screen. With two groups arranged the usual way that is:
///
///     [ always hidden ] │A│ [ collapsible ] │B│ [ visible ] 🟢
///
/// Collapsing B hides the collapsible icons *and* everything beyond A, because
/// B's inflation sweeps past them. Collapsing A hides only the leftmost zone.
/// That containment is the feature, not an accident of the mechanism.
public enum MenuBarZone: Equatable, Sendable {
    /// Left of the boundary at this index in a leftmost-first list.
    case group(Int)
    /// Right of every boundary: on screen no matter what is collapsed.
    case visible

    public var groupIndex: Int? {
        if case .group(let index) = self { return index }
        return nil
    }
}

public enum MenuBarZoning {

    /// Places a position among boundaries given leftmost-first.
    ///
    /// Positions are distances from the right edge of the screen, so a larger
    /// number is further left. An icon belongs to the first zone whose
    /// boundary it is left of; if it is left of none, it is visible.
    ///
    /// - Parameter position: nil for an icon macOS is not drawing, which
    ///   cannot be placed and is reported as such.
    public static func zone(
        for position: Double?, boundaries: [Double]
    ) -> MenuBarZone? {
        guard let position else { return nil }
        for (index, boundary) in boundaries.enumerated() where position > boundary {
            return .group(index)
        }
        return .visible
    }

    /// Where to put an icon so it lands in the requested zone.
    ///
    /// Aims for the middle of the zone rather than just past its edge: macOS
    /// treats a stored position as a hint and packs items together, so a
    /// target sitting exactly on a boundary can settle on either side of it.
    /// The midpoint leaves room for that to be wrong and still land right.
    ///
    /// - Parameter clearance: how far past the outermost boundary to go when
    ///   the target zone has no far edge.
    public static func targetPosition(
        for zone: MenuBarZone, boundaries: [Double], clearance: Double
    ) -> Double? {
        guard !boundaries.isEmpty else { return nil }

        switch zone {
        case .visible:
            // Right of the last boundary, and never past the screen edge.
            return max(0, boundaries[boundaries.count - 1] - clearance)

        case .group(let index):
            guard boundaries.indices.contains(index) else { return nil }
            let near = boundaries[index]
            if index == 0 {
                // Leftmost zone is open-ended; step past its boundary.
                return near + clearance
            }
            // Between this boundary and the one to its right: aim for the
            // middle so a hint that drifts still stays inside the zone.
            let far = boundaries[index - 1]
            return (near + far) / 2
        }
    }
}
