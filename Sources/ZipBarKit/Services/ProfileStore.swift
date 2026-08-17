import Foundation

/// Persists the user's layout.
///
/// Stored as JSON under a single defaults key rather than as scattered
/// primitives, so the whole configuration versions and migrates as one unit.
public final class ProfileStore {
    public static let defaultsKey = "com.zipbar.layout"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func load() -> MenuBarLayout {
        guard let data = defaults.data(forKey: Self.defaultsKey) else {
            return persistedStarter()
        }
        guard let layout = try? decoder.decode(MenuBarLayout.self, from: data) else {
            // A layout we cannot read is a layout we would otherwise destroy
            // on the next save. Keep the raw data under a salvage key so a
            // future migration — or a support request — can recover it.
            defaults.set(data, forKey: Self.defaultsKey + ".unreadable")
            return persistedStarter()
        }
        return layout
    }

    /// Write the starter layout out immediately rather than handing back a
    /// fresh in-memory one each launch.
    ///
    /// Group IDs become `NSStatusItem.autosaveName`s, and that is how macOS
    /// remembers where the user ⌘-dragged each separator. A starter layout
    /// that is regenerated on every launch mints new UUIDs, new autosave
    /// names, and silently loses the arrangement the user just made.
    private func persistedStarter() -> MenuBarLayout {
        let starter = MenuBarLayout.starter
        save(starter)
        return starter
    }

    public func save(_ layout: MenuBarLayout) {
        guard let data = try? encoder.encode(layout) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
