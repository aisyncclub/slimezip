import CoreGraphics
import Foundation

/// One status item as observed by whichever probe found it.
///
/// Deliberately a value type with no live handle: probes disagree about what
/// they can see, so the engine compares snapshots rather than trusting any
/// single backend's notion of identity.
public struct MenuBarItemSnapshot: Identifiable, Hashable, Sendable {
    /// Stable within a probe run. Composed from owner + title when the
    /// backend gives us no real identifier.
    public var id: String
    /// Bundle identifier of the owning app, when known.
    public var bundleIdentifier: String?
    /// Localised app name, when known.
    public var ownerName: String?
    public var processIdentifier: pid_t?
    /// Accessibility title or description — often empty for icon-only items.
    public var title: String?
    /// Screen rect, when the backend can report one.
    public var frame: CGRect?
    /// Left-to-right index within the bar, when the backend orders items.
    public var index: Int?

    public init(
        id: String,
        bundleIdentifier: String? = nil,
        ownerName: String? = nil,
        processIdentifier: pid_t? = nil,
        title: String? = nil,
        frame: CGRect? = nil,
        index: Int? = nil
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.ownerName = ownerName
        self.processIdentifier = processIdentifier
        self.title = title
        self.frame = frame
        self.index = index
    }

    /// What to show a human: the title if there is one, else the owning app.
    public var displayName: String {
        if let title, !title.isEmpty { return title }
        if let ownerName, !ownerName.isEmpty { return ownerName }
        return id
    }
}

/// Result of asking a backend to enumerate the bar.
public struct ProbeResult: Sendable {
    public var backend: String
    public var items: [MenuBarItemSnapshot]
    /// Why the result looks the way it does — including the reasons a
    /// backend returned nothing. The diagnostics report is only useful if
    /// failures explain themselves.
    public var notes: [String]
    public var succeeded: Bool { !items.isEmpty }

    public init(backend: String, items: [MenuBarItemSnapshot], notes: [String] = []) {
        self.backend = backend
        self.items = items
        self.notes = notes
    }
}

/// A way of discovering status items. Conformers must never trap: an
/// unavailable mechanism returns an empty result with an explanatory note.
public protocol ItemProbe {
    static var name: String { get }
    func probe() -> ProbeResult
}
