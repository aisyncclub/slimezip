import Foundation

/// Remembers which icons the user wants in the slime and which they want left
/// out in the open.
///
/// The app cannot act on these preferences directly — macOS reports every
/// status item's position as read-only and ignores a synthesised ⌘-drag, so
/// only the user can move an icon. What a stored preference buys is the
/// comparison: knowing where each icon *should* be lets the app name the
/// handful that are in the wrong place instead of leaving the user to work it
/// out against a bar of thirty.
public struct IconPreferenceStore {

    public enum Desired: String, Sendable {
        /// Should end up inside the slime.
        case hidden
        /// Should stay out where it can be seen.
        case visible
    }

    /// Identifies an icon across launches.
    ///
    /// Not the AX item id, which embeds a process id and so changes every
    /// time the owning app restarts. The bundle identifier plus the item's
    /// index within its own app survives that, which is what a preference
    /// needs to be worth storing.
    public static func key(bundleIdentifier: String?, ownerName: String, indexInApp: Int) -> String {
        let owner = bundleIdentifier ?? "name:\(ownerName)"
        return "\(owner)#\(indexInApp)"
    }

    static let defaultsKey = "com.zipbar.iconPreferences"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func all() -> [String: Desired] {
        guard let raw = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] else {
            return [:]
        }
        return raw.compactMapValues(Desired.init(rawValue:))
    }

    public func desired(for key: String) -> Desired? {
        all()[key]
    }

    public func set(_ desired: Desired?, for key: String) {
        var current = all().mapValues(\.rawValue)
        if let desired {
            current[key] = desired.rawValue
        } else {
            // No preference is a real state, distinct from "wants it visible":
            // an icon the user has not ruled on should never appear as work
            // to be done.
            current.removeValue(forKey: key)
        }
        defaults.set(current, forKey: Self.defaultsKey)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
