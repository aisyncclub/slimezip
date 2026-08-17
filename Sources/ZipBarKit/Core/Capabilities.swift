import Foundation

/// Which low-level mechanism is currently driving the menu bar.
///
/// macOS has broken the underlying techniques twice in two releases (Tahoe
/// poisoned `CGWindowListCopyWindowInfo` ownership, Golden Gate collapsed the
/// per-item windows into one). ZipBar therefore never assumes a mechanism
/// works — it probes at runtime and reports what it actually got.
public enum BackendID: String, Codable, Sendable, CaseIterable {
    /// Inflating our own `NSStatusItem` to push neighbours off screen.
    /// Needs no permissions. Known to stop working in macOS 27.
    case spacer

    /// The private `MenuServiceBridge` framework, resolved via `dlopen`.
    /// Can enumerate, click and move items. Needs Accessibility.
    case menuServiceBridge

    /// Nothing usable was found on this OS.
    case degraded
}

/// What ZipBar can actually do right now, on this machine, on this OS.
///
/// Every feature in the UI is gated on one of these flags. When a macOS
/// update takes a capability away the app degrades to a banner instead of
/// misbehaving — which is precisely the failure mode that sank the previous
/// generation of menu bar managers.
public struct Capabilities: Equatable, Sendable {
    /// Can we make items disappear from the visible bar at all?
    public var canHide: Bool
    /// Can we read the list of status items and who owns them?
    public var canEnumerate: Bool
    /// Can we change an item's position in the bar?
    public var canMove: Bool
    /// Can we activate an item while it is hidden or off screen?
    public var canClickRemotely: Bool
    /// Can we capture item artwork to redraw it in our own panel?
    public var canCapture: Bool
    /// Which mechanism produced these answers.
    public var backend: BackendID
    /// Human-readable findings, surfaced in the diagnostics report.
    public var notes: [String]

    public init(
        canHide: Bool = false,
        canEnumerate: Bool = false,
        canMove: Bool = false,
        canClickRemotely: Bool = false,
        canCapture: Bool = false,
        backend: BackendID = .degraded,
        notes: [String] = []
    ) {
        self.canHide = canHide
        self.canEnumerate = canEnumerate
        self.canMove = canMove
        self.canClickRemotely = canClickRemotely
        self.canCapture = canCapture
        self.backend = backend
        self.notes = notes
    }

    /// Nothing works. The UI shows "not yet supported on this macOS version"
    /// rather than pretending and failing.
    public static let degraded = Capabilities(backend: .degraded)

    /// True when the only thing we can do is collapse groups the user has
    /// arranged by hand — no enumeration, no moving, no panel.
    public var isManualOnly: Bool {
        canHide && !canEnumerate
    }
}
