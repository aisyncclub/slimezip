import Foundation

/// The seam that lets ZipBar survive a macOS release.
///
/// Everything above this protocol — groups, persistence, settings UI, hotkeys,
/// the overflow panel — is mechanism-agnostic. When Apple changes the menu bar
/// again, adapting means writing one more conformer, not rewriting the app.
///
/// Implementations are main-actor bound because they all end up touching
/// `NSStatusBar`.
@MainActor
public protocol HidingStrategy: AnyObject {
    /// Which backend this conformer is.
    nonisolated static var backend: BackendID { get }

    /// Whether this mechanism is expected to work on the running OS.
    /// Called before activation; a `false` here makes the engine try the next
    /// strategy rather than activating something that will silently no-op.
    ///
    /// Deliberately `nonisolated`: capability checks read only the OS version
    /// and defaults, so diagnostics tools can ask without hopping to the main
    /// actor just to find out whether a backend is viable.
    nonisolated static func isSupported() -> Bool

    /// What this strategy can do once activated.
    var capabilities: Capabilities { get }

    /// Take ownership of the menu bar for the given layout.
    func activate(layout: MenuBarLayout) throws

    /// Relinquish all status items.
    func deactivate()

    /// Reconcile with an edited layout (groups added, removed, renamed).
    func apply(layout: MenuBarLayout)

    func isCollapsed(_ groupID: MenuBarGroup.ID) -> Bool
    func setCollapsed(_ collapsed: Bool, for groupID: MenuBarGroup.ID)
    func toggle(_ groupID: MenuBarGroup.ID)

    /// Fires whenever a group's collapse state changes, from any cause
    /// (user click, auto-hide timer, hotkey).
    var collapseDidChange: ((MenuBarGroup.ID, Bool) -> Void)? { get set }
}

public extension HidingStrategy {
    func toggle(_ groupID: MenuBarGroup.ID) {
        setCollapsed(!isCollapsed(groupID), for: groupID)
    }
}

public enum HidingStrategyError: LocalizedError {
    case unsupportedOnThisOS(BackendID)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOnThisOS(let backend):
            return "\(backend.rawValue) 백엔드는 현재 macOS 버전에서 동작하지 않습니다."
        }
    }
}
