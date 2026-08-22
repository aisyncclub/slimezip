import AppKit

/// Moves another app's status item by rewriting where macOS remembers it.
///
/// This is the one route that works. Accessibility reports every status item's
/// position as read-only, and a synthesised ⌘-drag is ignored — both measured,
/// both recorded in `docs/RESEARCH.md`. But every app stores its own item's
/// place under `NSStatusItem Preferred Position` in its own preferences, and
/// that value is read when the item is created. Write it, and the icon lands
/// there the next time that app starts.
///
/// Three honest limits, each surfaced in the UI rather than hidden:
///
/// - **The target app must restart.** A running app has already read its
///   position and will not look again.
/// - **The value is a hint, not a coordinate.** macOS packs items together, so
///   an icon lands as near the request as the neighbours allow. Asking for a
///   spot behind three other icons put Magnet at the next free slot instead.
/// - **It edits another app's preferences.** Reversible — the previous value
///   comes back from `apply` so a caller can put it back — but not ours to do
///   quietly, so every move is something the user asks for by name.
public struct MenuBarArranger {

    /// Which side of the boundary an icon should end up on.
    public enum Side: Sendable {
        case hidden
        case visible
    }

    /// What a move would do, computed before anything is written.
    public struct Plan: Sendable {
        public let bundleIdentifier: String
        public let ownerName: String
        public let key: String
        /// nil when the app has never stored a position.
        public let currentPosition: Double?
        public let targetPosition: Double
        public let side: Side
    }

    /// Points to clear the boundary by. About one status item's width, so the
    /// moved icon settles beside the boundary rather than on top of it.
    static let clearance: Double = 40

    private let defaultsFor: @Sendable (String) -> UserDefaults?

    public init(
        defaultsFor: @escaping @Sendable (String) -> UserDefaults? = { bundleIdentifier in
            // Our own domain is already `standard`; asking for it as a suite
            // returns nothing useful and makes macOS log a complaint on every
            // sweep. ZipBar's own items are never moved through here anyway.
            guard bundleIdentifier != Bundle.main.bundleIdentifier
            else { return .standard }
            return UserDefaults(suiteName: bundleIdentifier)
        }
    ) {
        self.defaultsFor = defaultsFor
    }

    // MARK: - Reading

    /// Position keys an app has stored, in order.
    ///
    /// Apps that publish several status items store one key each, so an item's
    /// index within its own app picks the right one.
    public func positionKeys(for bundleIdentifier: String) -> [String] {
        guard let defaults = defaultsFor(bundleIdentifier) else { return [] }
        return defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("NSStatusItem Preferred Position") }
            .sorted()
    }

    public func storedPosition(for bundleIdentifier: String, key: String) -> Double? {
        defaultsFor(bundleIdentifier)?.object(forKey: key) as? Double
    }

    // MARK: - Planning

    /// Where an icon has to go to land on the requested side.
    ///
    /// Positions are distances from the right edge of the screen, so a larger
    /// number is further left — and further left is the hidden side, because
    /// that is the direction the separator grows when it inflates.
    public static func targetPosition(boundaryPosition: Double, side: Side) -> Double {
        switch side {
        case .hidden: return boundaryPosition + clearance
        case .visible: return max(0, boundaryPosition - clearance)
        }
    }

    /// Builds a plan, or nil when there is no app to address.
    public func plan(
        bundleIdentifier: String?,
        ownerName: String,
        indexInApp: Int,
        side: Side,
        boundaryPosition: Double
    ) -> Plan? {
        guard let bundleIdentifier else { return nil }
        let keys = positionKeys(for: bundleIdentifier)
        // Fall back to the conventional first-item key so an app that has
        // never been moved can still be placed.
        let key = keys.indices.contains(indexInApp)
            ? keys[indexInApp]
            : (keys.first ?? "NSStatusItem Preferred Position Item-0")

        return Plan(
            bundleIdentifier: bundleIdentifier,
            ownerName: ownerName,
            key: key,
            currentPosition: storedPosition(for: bundleIdentifier, key: key),
            targetPosition: Self.targetPosition(boundaryPosition: boundaryPosition, side: side),
            side: side
        )
    }

    // MARK: - Writing

    /// Applies a plan.
    ///
    /// - Returns: the value that was there before, wrapped so that "there was
    ///   no value" and "the write could not be made" stay distinguishable —
    ///   the caller needs both to undo correctly.
    @discardableResult
    public func apply(_ plan: Plan) -> Double?? {
        guard let defaults = defaultsFor(plan.bundleIdentifier) else { return .none }
        let previous = defaults.object(forKey: plan.key) as? Double
        defaults.set(plan.targetPosition, forKey: plan.key)
        return .some(previous)
    }

    /// Writes a position directly, for re-applying a plan at a later moment.
    public func write(_ position: Double, to key: String, in bundleIdentifier: String) {
        defaultsFor(bundleIdentifier)?.set(position, forKey: key)
    }

    /// Puts a previous value back, or removes the key when there was none.
    public func revert(_ plan: Plan, to previous: Double?) {
        guard let defaults = defaultsFor(plan.bundleIdentifier) else { return }
        if let previous {
            defaults.set(previous, forKey: plan.key)
        } else {
            defaults.removeObject(forKey: plan.key)
        }
    }
}
