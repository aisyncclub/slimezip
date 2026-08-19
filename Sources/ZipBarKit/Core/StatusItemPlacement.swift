import AppKit

/// Keeps our own status items inside the screen, and to the right of the
/// separator that displaces things.
///
/// macOS persists each status item's position under
/// `NSStatusItem Preferred Position <autosaveName>` in the owning app's
/// defaults. The value is the distance in points from the right edge of the
/// screen to the item's left edge, so a larger number sits further left.
///
/// That persistence turned a transient glitch into a permanent one. Collapsing
/// a group inflates the separator to roughly twice the screen width, which
/// shoves everything to its left off the display — and when our own chevron
/// and control item happened to sit there, macOS recorded their displaced
/// coordinates. ZipBar then restored those positions on every subsequent
/// launch and its entire UI stayed off-screen: the app looked like it was not
/// running at all, and quitting and relaunching could never recover it.
///
/// Two guards, because either alone is insufficient:
///
/// - `sanitize` discards stored positions that lie beyond any display. Such a
///   value cannot come from a user drag, only from our own inflation, so it is
///   always safe to drop — and it repairs profiles already poisoned.
/// - `enforceOrder` keeps the chevron and control item to the right of the
///   separator, so inflation never displaces them in the first place. It only
///   rewrites positions that actually violate that order, leaving the user's
///   own arrangement alone.
public enum StatusItemPlacement {

    public static func key(for autosaveName: String) -> String {
        "NSStatusItem Preferred Position \(autosaveName)"
    }

    /// Points between our items when we have to lay them out ourselves.
    /// Comfortably wider than a status item so they never overlap.
    static let spacing: Double = 40

    /// Drops any stored position that lies beyond the widest display.
    ///
    /// - Returns: the autosave names whose positions were discarded.
    @discardableResult
    public static func sanitize(
        autosaveNames: [String],
        widestScreenWidth: Double,
        defaults: UserDefaults = .standard
    ) -> [String] {
        var repaired: [String] = []
        for name in autosaveNames {
            let k = key(for: name)
            guard let stored = defaults.object(forKey: k) as? Double else { continue }
            if stored < 0 || stored > widestScreenWidth {
                defaults.removeObject(forKey: k)
                repaired.append(name)
            }
        }
        return repaired
    }

    /// Ensures the given names sit left to right in the order supplied.
    ///
    /// Positions already in the right order are left untouched, so a user who
    /// has arranged their bar by hand keeps that arrangement.
    ///
    /// - Returns: the autosave names that had to be repositioned.
    @discardableResult
    public static func enforceOrder(
        leftToRight names: [String],
        widestScreenWidth: Double,
        defaults: UserDefaults = .standard
    ) -> [String] {
        guard names.count > 1 else { return [] }

        var positions = names.map { defaults.object(forKey: key(for: $0)) as? Double }

        // Left to right means strictly decreasing distance from the right edge.
        let ordered = zip(positions, positions.dropFirst()).allSatisfy { left, right in
            guard let left, let right else { return false }
            return left > right
        }
        if ordered { return [] }

        // Anchor on the leftmost known position so we disturb the bar as
        // little as possible, falling back to a spot clear of the system
        // items when nothing usable is stored.
        let anchor = positions.compactMap { $0 }.max()
            ?? min(Double(names.count) * spacing + spacing, widestScreenWidth)

        var moved: [String] = []
        for (index, name) in names.enumerated() {
            let target = anchor - Double(index) * spacing
            guard target >= 0 else { continue }
            if positions[index] != target {
                defaults.set(target, forKey: key(for: name))
                moved.append(name)
            }
            positions[index] = target
        }
        return moved
    }

    /// Widest display, used as the bound for a plausible stored position.
    @MainActor
    public static func widestScreenWidth() -> Double {
        NSScreen.screens.map { Double($0.frame.width) }.max() ?? 1920
    }
}
