import Foundation

/// Remembers moves that have been written but have not taken effect yet.
///
/// A move rewrites where macOS remembers an icon, and that value is only read
/// when the owning app starts — so between the click and the restart there is
/// a gap, sometimes hours long, that has to survive the settings window
/// closing and ZipBar itself relaunching. Holding it in view state made the
/// wait list vanish the moment the window closed, which read as the click
/// having done nothing.
///
/// Each record also keeps the value that was overwritten, so undo still works
/// after any amount of time — including "there was no value", which must be
/// restored by *removing* the key, not by writing a zero.
public struct PendingMoveStore {

    public struct Record: Codable, Equatable, Sendable {
        public let bundleIdentifier: String
        /// The defaults key that was rewritten in the target app's domain.
        public let positionKey: String
        /// What was there before. nil means the app had never stored one.
        public let previousValue: Double?
        /// Where the icon should end up.
        ///
        /// Kept rather than recomputed because the write has to happen twice:
        /// once when the user asks, and again after the owning app has quit.
        /// Some apps save their live position on the way out and clobber ours,
        /// so the value written before the quit is not the one that survives.
        public let targetValue: Double
        /// Which side of the boundary the move points the icon at.
        public let side: Side

        public enum Side: String, Codable, Sendable {
            case hidden
            case visible
        }
    }

    static let defaultsKey = "com.zipbar.pendingMoves"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// All outstanding moves, keyed by the icon's stable preference key.
    public func all() -> [String: Record] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Record].self, from: data)
        else { return [:] }
        return decoded
    }

    public func record(for key: String) -> Record? {
        all()[key]
    }

    public func set(_ record: Record, for key: String) {
        var current = all()
        // First write wins for the undo value: applying a second move on top
        // of a pending one must not make "undo" restore our own intermediate
        // write instead of what the app originally had.
        if let existing = current[key] {
            current[key] = Record(
                bundleIdentifier: record.bundleIdentifier,
                positionKey: record.positionKey,
                previousValue: existing.previousValue,
                targetValue: record.targetValue,
                side: record.side
            )
        } else {
            current[key] = record
        }
        save(current)
    }

    public func remove(for key: String) {
        var current = all()
        current.removeValue(forKey: key)
        save(current)
    }

    private func save(_ records: [String: Record]) {
        if records.isEmpty {
            defaults.removeObject(forKey: Self.defaultsKey)
        } else if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
